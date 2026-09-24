///|
fn duckdb_table_name(table_schema : @table.Table) -> String {
  let schema_name = table_schema.schema.unwrap_or(
    table_schema.catalog.unwrap_or(""),
  )
  if schema_name == "" {
    table_schema.name
  } else {
    "\{schema_name}.\{table_schema.name}"
  }
}

///|
fn duckdb_column_type(column : @table.Column) -> String {
  match column.column_type {
    TinyInt => "TINYINT"
    SmallInt | Year => "SMALLINT"
    MediumInt | Int => "INTEGER"
    BigInt => "BIGINT"
    Float => "FLOAT"
    Double => "DOUBLE"
    Decimal(precision, scale) => "DECIMAL(\{precision}, \{scale})"
    Char(length) => "CHAR(\{length})"
    VarChar(length) => "VARCHAR(\{length})"
    Text | MediumText | LongText | Enum(_, _) => "VARCHAR"
    Binary(_) | VarBinary(_) | Blob | MediumBlob | LongBlob => "BLOB"
    Date => "DATE"
    Time => "TIME"
    DateTime => "TIMESTAMP"
    Timestamp => "TIMESTAMPTZ"
    Json | JsonB =>
      match column.engine_options.get("json.storage") {
        Some(["bson" | "blob", ..]) => "BLOB"
        _ => "JSON"
      }
    Boolean => "BOOLEAN"
  }
}

///|
fn duckdb_sequence_name(
  table_schema : @table.Table,
  column : @table.Column,
) -> String {
  "\{duckdb_table_name(table_schema)}_\{column.name}_seq"
}

///|
fn duckdb_column_default(
  table_schema : @table.Table,
  column : @table.Column,
) -> String? {
  if column.default_value is Some(value) {
    return Some(value)
  }
  if column.auto_increment {
    return Some("nextval('\{duckdb_sequence_name(table_schema, column)}')")
  }
  if column.primary_key {
    match column.engine_options.get("pk.strategy") {
      Some(["uuid", ..]) => return Some("uuid()")
      _ => ()
    }
  }
  None
}

///|
fn duckdb_column_def(
  table_schema : @table.Table,
  column : @table.Column,
) -> String {
  let mut definition = "\{column.name} \{duckdb_column_type(column)}"
  if duckdb_column_default(table_schema, column) is Some(default_value) {
    definition += " DEFAULT \{default_value}"
  }
  if column.primary_key {
    definition += " PRIMARY KEY"
  } else if !column.nullable {
    definition += " NOT NULL"
  }
  if column.unique && !column.primary_key {
    definition += " UNIQUE"
  }
  definition
}

///|
fn duckdb_fk_def(foreign_key : @table.ForeignKey) -> String {
  let mut definition = "FOREIGN KEY (\{foreign_key.column}) REFERENCES \{foreign_key.referenced_table}(\{foreign_key.referenced_column})"
  if foreign_key.on_delete != "" {
    definition += " ON DELETE \{foreign_key.on_delete}"
  }
  if foreign_key.on_update != "" {
    definition += " ON UPDATE \{foreign_key.on_update}"
  }
  definition
}

///|
fn duckdb_create_table_sql(table_schema : @table.Table) -> String {
  let definitions : Array[String] = []
  let mut has_column_primary_key = false
  for column in table_schema.columns {
    definitions.push(duckdb_column_def(table_schema, column))
    if column.primary_key {
      has_column_primary_key = true
    }
  }
  if !has_column_primary_key {
    for index in table_schema.indexes {
      if index.index_type is Primary && !index.columns.is_empty() {
        definitions.push("PRIMARY KEY (\{index.columns.join(", ")})")
      }
    }
  }
  for foreign_key in table_schema.foreign_keys {
    definitions.push(duckdb_fk_def(foreign_key))
  }
  let prefix = if table_schema.temporary {
    "CREATE TEMPORARY TABLE"
  } else {
    "CREATE TABLE"
  }
  let if_not_exists_sql = if table_schema.if_not_exists {
    " IF NOT EXISTS"
  } else {
    ""
  }
  let mut sql = "\{prefix}\{if_not_exists_sql} \{duckdb_table_name(table_schema)} (\{definitions.join(", ")})"
  if table_schema.engine_options.get("create_suffix") is Some([suffix, ..]) {
    sql += " \{suffix}"
  }
  sql
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn migrate_table(
  self,
  table_schema : @table.Table,
) -> @morm/engine.QueryResult {
  if table_schema.name == "" || table_schema.columns.is_empty() {
    return duckdb_failed("invalid table schema")
  }
  for column in table_schema.columns {
    if column.name == "" {
      return duckdb_failed("invalid column name")
    }
  }
  for index in table_schema.indexes {
    if index.index_type is (FullText | Spatial) {
      return duckdb_failed(
        "DuckDB does not support full-text or spatial indexes",
      )
    }
  }
  for column in table_schema.columns {
    if column.auto_increment && column.default_value is None {
      let result = self.exec_sql(
        "CREATE SEQUENCE IF NOT EXISTS \{duckdb_sequence_name(table_schema, column)}",
        [],
      )
      if !result.ok {
        return result
      }
    }
  }
  let created = self.exec_sql(duckdb_create_table_sql(table_schema), [])
  if !created.ok {
    return created
  }
  for index in table_schema.indexes {
    if index.index_type is Primary ||
      index.name == "" ||
      index.columns.is_empty() {
      continue
    }
    let unique = if index.index_type is Unique { "UNIQUE " } else { "" }
    let result = self.exec_sql(
      "CREATE \{unique}INDEX IF NOT EXISTS \{index.name} ON \{duckdb_table_name(table_schema)} (\{index.columns.join(", ")})",
      [],
    )
    if !result.ok {
      return result
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None, }
}
