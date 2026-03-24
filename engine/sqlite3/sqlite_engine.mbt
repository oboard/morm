///|
struct SQLiteEngine {
  conn : Connection
}

///|
pub fn SQLiteEngine::open(filename : String) -> SQLiteEngine {
  { conn: try! Connection::open(filename) }
}

///|
fn placeholders(count : Int) -> String {
  let parts : Array[String] = []
  let mut i = 0
  while i < count {
    parts.push("?")
    i = i + 1
  }
  parts.join(", ")
}

///|
fn format_where_sql(where_ : FixedArray[@engine.Where]) -> String {
  where_
  .map(w => {
    match (w.ty, w.value) {
      (Eq, Null | Json(Null)) => "\{w.col} IS NULL"
      (Ne, Null | Json(Null)) => "\{w.col} IS NOT NULL"
      _ => {
        let op = match w.ty {
          Eq => "="
          Ne => "!="
          Gt => ">"
          Lt => "<"
          Gte => ">="
          Lte => "<="
          Like => "LIKE"
        }
        [w.col, op, "?"].join(" ")
      }
    }
  })
  .join(" AND ")
}

///|
fn where_params(
  where_ : FixedArray[@engine.Where],
) -> FixedArray[@engine.Param] {
  let out : Array[@engine.Param] = []
  for w in where_ {
    if w.ty is (Eq | Ne) && w.value is (Null | Json(Null)) {
      continue
    }
    out.push(w.value)
  }
  FixedArray::from_array(out)
}

///|
fn format_set_sql(sets : FixedArray[@engine.Set]) -> String {
  sets.map(s => [s.col, "=", "?"].join(" ")).join(", ")
}

///|
fn sqlite_table_engine_option(
  table_schema : @table.Table,
  key : String,
  default : String,
) -> String {
  for option in table_schema.engine_options {
    if option.key == key {
      return option.value
    }
  }
  default
}

///|
fn sqlite_column_engine_option(
  column : @table.Column,
  key : String,
  default : String,
) -> String {
  for option in column.engine_options {
    if option.key == key {
      return option.value
    }
  }
  default
}

///|
fn sqlite_table_name(table_schema : @table.Table) -> String {
  let schema = table_schema.schema.unwrap_or("")
  let catalog = table_schema.catalog.unwrap_or("")
  let table_ns = if schema != "" { schema } else { catalog }
  if table_ns != "" {
    "\{table_ns}.\{table_schema.name}"
  } else {
    table_schema.name
  }
}

///|
fn sqlite_col_type(column_type : @table.ColumnType) -> String {
  match column_type {
    @table.TinyInt
    | @table.SmallInt
    | @table.MediumInt
    | @table.Int
    | @table.BigInt
    | @table.Year => "INTEGER"
    @table.Float | @table.Double | @table.Decimal(_, _) => "REAL"
    @table.Boolean => "INTEGER"
    @table.Blob
    | @table.MediumBlob
    | @table.LongBlob
    | @table.Binary(_)
    | @table.VarBinary(_) => "BLOB"
    @table.Date | @table.Time | @table.DateTime | @table.Timestamp => "TEXT"
    @table.Json | @table.JsonB => "TEXT"
    @table.Char(_)
    | @table.VarChar(_)
    | @table.Text
    | @table.MediumText
    | @table.LongText => "TEXT"
  }
}

///|
fn sqlite_json_storage_type(column : @table.Column) -> String {
  match sqlite_column_engine_option(column, "json.storage", "") {
    "blob" | "bson" => "BLOB"
    "text" | "string" | "json" | "jsonb" => "TEXT"
    _ => "TEXT"
  }
}

///|
fn sqlite_pk_strategy_default(column : @table.Column) -> String? {
  if !column.primary_key || column.auto_increment {
    return None
  }
  match sqlite_column_engine_option(column, "pk.strategy", "") {
    "uuid" => Some("lower(hex(randomblob(16)))")
    _ => None
  }
}

///|
fn sqlite_column_default_expr(column : @table.Column) -> String? {
  if column.default_value is Some(v) {
    return Some(v)
  }
  sqlite_pk_strategy_default(column)
}

///|
fn render_column_def(column : @table.Column) -> String {
  if column.name == "" {
    return ""
  }
  let default_value = sqlite_column_default_expr(column).unwrap_or("")
  let col_type = match column.column_type {
    @table.Json | @table.JsonB => sqlite_json_storage_type(column)
    _ => sqlite_col_type(column.column_type)
  }
  let buf = @buffer.new()
  buf.write_string(column.name)
  if column.primary_key && column.auto_increment {
    buf.write_string(" INTEGER PRIMARY KEY AUTOINCREMENT")
  } else {
    buf.write_string(" ")
    buf.write_string(col_type)
    if column.primary_key {
      buf.write_string(" PRIMARY KEY")
    }
    if !column.nullable {
      buf.write_string(" NOT NULL")
    }
    if column.unique {
      buf.write_string(" UNIQUE")
    }
    if default_value != "" {
      buf.write_string(" DEFAULT ")
      buf.write_string(default_value)
    }
  }
  buf.to_string()
}

///|
fn render_fk_def(fk : @table.ForeignKey) -> String {
  if fk.column == "" || fk.referenced_table == "" || fk.referenced_column == "" {
    return ""
  }
  let mut s = "FOREIGN KEY (\{fk.column}) REFERENCES \{fk.referenced_table}(\{fk.referenced_column})"
  if fk.on_delete != "" {
    s = s + " ON DELETE " + fk.on_delete
  }
  if fk.on_update != "" {
    s = s + " ON UPDATE " + fk.on_update
  }
  s
}

///|
fn render_create_table_sql(table_schema : @table.Table) -> String {
  if table_schema.name == "" {
    return ""
  }
  let table_name = sqlite_table_name(table_schema)
  let defs : Array[String] = []
  for column in table_schema.columns {
    let def = render_column_def(column)
    if def != "" {
      defs.push(def)
    }
  }
  for fk in table_schema.foreign_keys {
    let fk_def = render_fk_def(fk)
    if fk_def != "" {
      defs.push(fk_def)
    }
  }
  let defs_sql = defs.join(", ")
  let create_prefix = if table_schema.temporary {
    "CREATE TEMPORARY TABLE"
  } else {
    "CREATE TABLE"
  }
  let mut sql = if table_schema.if_not_exists {
    "\{create_prefix} IF NOT EXISTS \{table_name} (\{defs_sql})"
  } else {
    "\{create_prefix} \{table_name} (\{defs_sql})"
  }
  if sqlite_table_engine_option(table_schema, "sqlite.without_rowid", "") ==
    "true" {
    sql = sql + " WITHOUT ROWID"
  }
  if sqlite_table_engine_option(table_schema, "sqlite.strict", "") == "true" {
    sql = sql + " STRICT"
  }
  let create_suffix = sqlite_table_engine_option(
    table_schema, "create_suffix", "",
  )
  if create_suffix != "" {
    sql = sql + " " + create_suffix
  }
  sql
}

///|
fn render_index_sqls(table_schema : @table.Table) -> Array[String] {
  if table_schema.name == "" {
    return []
  }
  let table_name = sqlite_table_name(table_schema)
  let sqls : Array[String] = []
  for idx in table_schema.indexes {
    if idx.name is ("" | "PRIMARY") || idx.columns.length() == 0 {
      continue
    }
    let unique = if idx.index_type == @table.Unique { "UNIQUE " } else { "" }
    let cols_sql = idx.columns.join(", ")
    sqls.push(
      "CREATE \{unique}INDEX IF NOT EXISTS \{idx.name} ON \{table_name} (\{cols_sql})",
    )
  }
  sqls
}

///|
fn render_sqlite(
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  match stmt {
    Select(select_stmt) => {
      let { select, from, joins, where_, order_by, limit, offset } = select_stmt
      let buf = @buffer.new()
      buf.write_string("SELECT ")
      if select.is_empty() {
        buf.write_string("*")
      } else {
        buf.write_string(select)
      }
      buf.write_string(" FROM ")
      buf.write_string(from)
      if !joins.is_empty() {
        buf.write_string(" ")
        buf.write_string(joins.join(" "))
      }
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      if !order_by.is_empty() {
        buf.write_string(" ORDER BY ")
        buf.write_string(
          order_by
          .map(ob => {
            match ob {
              Asc(col) => "\{col} ASC"
              Desc(col) => "\{col} DESC"
            }
          })
          .join(", "),
        )
      }
      if limit is Some(v) {
        buf.write_string(" LIMIT ")
        buf.write_string(v.to_string())
      }
      if offset is Some(v) {
        buf.write_string(" OFFSET ")
        buf.write_string(v.to_string())
      }
      (buf.to_string(), where_params(where_))
    }
    Insert(insert_stmt) => {
      let { into, columns, values, rows } = insert_stmt
      let buf = @buffer.new()
      buf.write_string("INSERT INTO ")
      buf.write_string(into)
      if !columns.is_empty() {
        buf.write_string(" (")
        buf.write_string(columns.join(", "))
        buf.write_string(")")
      }
      let effective_rows = if !rows.is_empty() { rows } else { [values] }
      let row_sql = effective_rows.map(row => {
        "(" + placeholders(row.length()) + ")"
      })
      buf.write_string(" VALUES ")
      buf.write_string(row_sql.join(", "))
      let out_params : Array[@engine.Param] = []
      for row in effective_rows {
        for value in row {
          out_params.push(value)
        }
      }
      (buf.to_string(), FixedArray::from_array(out_params))
    }
    Upsert(upsert_stmt) => {
      let { table, sets, conflict_target, update_sets } = upsert_stmt
      let buf = @buffer.new()
      buf.write_string("INSERT INTO ")
      buf.write_string(table)
      buf.write_string(" (")
      buf.write_string(sets.map(s => s.col).join(", "))
      buf.write_string(") VALUES (")
      buf.write_string(placeholders(sets.length()))
      buf.write_string(")")
      if !conflict_target.is_empty() {
        buf.write_string(" ON CONFLICT (")
        buf.write_string(conflict_target.join(", "))
        buf.write_string(")")
      }
      if !update_sets.is_empty() {
        buf.write_string(" DO UPDATE SET ")
        buf.write_string(format_set_sql(update_sets))
      } else {
        buf.write_string(" DO NOTHING")
      }
      buf.write_string(" RETURNING *")
      let mut args = sets.map(s => s.value)
      if !update_sets.is_empty() {
        args = args + update_sets.map(s => s.value)
      }
      (buf.to_string(), args)
    }
    Update(update_stmt) => {
      let { table, sets, where_ } = update_stmt
      let buf = @buffer.new()
      buf.write_string("UPDATE ")
      buf.write_string(table)
      buf.write_string(" SET ")
      buf.write_string(format_set_sql(sets))
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      (buf.to_string(), sets.map(s => s.value) + where_params(where_))
    }
    Delete(delete_stmt) => {
      let { from, where_ } = delete_stmt
      let buf = @buffer.new()
      buf.write_string("DELETE FROM ")
      buf.write_string(from)
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      (buf.to_string(), where_params(where_))
    }
  }
}

///|
fn sqlite_tx_sql(op : @engine.TxOp) -> String {
  match op {
    @engine.Begin => "BEGIN"
    @engine.Commit => "COMMIT"
    @engine.Rollback => "ROLLBACK"
    @engine.Savepoint(name) => "SAVEPOINT " + name
    @engine.RollbackToSavepoint(name) => "ROLLBACK TO SAVEPOINT " + name
  }
}

///|
pub impl @engine.Engine for SQLiteEngine with migrate_table(
  self,
  table_schema : @table.Table,
) -> @engine.QueryResult {
  let create_sql = render_create_table_sql(table_schema)
  if create_sql == "" {
    return {
      ok: false,
      rows_affected: 0,
      rows: [],
      error: Some("invalid table schema"),
    }
  }
  let create_res = self.exec(@engine.Raw(create_sql, []))
  if !create_res.ok {
    return create_res
  }
  for sql in render_index_sqls(table_schema) {
    let res = self.exec(@engine.Raw(sql, []))
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
fn SQLiteEngine::exec_sql(
  self : SQLiteEngine,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let mut error = None
  let rows : Array[Map[String, @engine.Param]] = []
  println(sql + ";")
  println(params.to_json().stringify())
  try {
    let stmt = self.conn.prepare(sql + ";")
    params.eachi((index, val) => {
      match val {
        @engine.Double(v) => stmt.bind(index~, val=v)
        @engine.Float(v) => stmt.bind(index~, val=v.to_double())
        @engine.Byte(v) => stmt.bind(index~, val=v.to_int())
        @engine.Int(v) => stmt.bind(index~, val=v)
        @engine.Int16(v) => stmt.bind(index~, val=v.to_int())
        @engine.UInt16(v) => stmt.bind(index~, val=v.to_int())
        @engine.UInt(v) => stmt.bind(index~, val=v.to_string())
        @engine.UInt64(v) => stmt.bind(index~, val=v.to_string())
        @engine.Int64(v) => stmt.bind(index~, val=v)
        @engine.BigInt(v) => stmt.bind(index~, val=v.to_string())
        @engine.Decimal(v) => stmt.bind(index~, val=v)
        @engine.Date(v, format) =>
          stmt.bind(index~, val=@engine.format_plain_date(v, format))
        @engine.Time(v, format) =>
          stmt.bind(index~, val=@engine.format_plain_time(v, format))
        @engine.DateTime(v, format) =>
          stmt.bind(index~, val=@engine.format_plain_date_time(v, format))
        @engine.Timestamp(v, format) =>
          stmt.bind(index~, val=@engine.format_zoned_date_time(v, format))
        @engine.Uuid(v) => stmt.bind(index~, val=v)
        @engine.Json(v) => stmt.bind(index~, val=v.stringify())
        @engine.String(v) => stmt.bind(index~, val=v)
        @engine.Bytes(v) => stmt.bind(index~, val=v)
        @engine.Bool(v) => stmt.bind(index~, val=if v { 1 } else { 0 })
        @engine.Null => stmt.bind_null(index~)
      }
    })
    // 构造第一行的 Json（按列名 -> 值）

    while stmt.step() == true {
      let obj : Map[String, @engine.Param] = {}
      let col_cnt = stmt.column_count()
      let mut index = 0
      while index < col_cnt {
        let name = stmt.column_name(index~)
        match stmt.column_type(index~) {
          SQLITE_NULL => obj[name] = @engine.Null
          SQLITE_INTEGER => {
            let v : Int = stmt.column(index~)
            obj[name] = @engine.Int(v)
          }
          SQLITE_FLOAT => {
            let v = stmt.column(index~)
            obj[name] = @engine.Double(v)
          }
          SQLITE_TEXT => {
            let s = stmt.column(index~)
            obj[name] = @engine.String(s)
          }
          SQLITE_BLOB => {
            let b : Bytes = stmt.column(index~)
            obj[name] = @engine.Bytes(b)
          }
          _ => {
            let s = stmt.column_blob_as_string(index~)
            obj[name] = @engine.String(s)
          }
        }
        index = index + 1
      }
      rows.push(obj)
    }
    stmt.finalize()
  } catch {
    SqliteError(err) => {
      println(err)
      error = Some(err.to_string())
    }
  }
  {
    ok: error is None,
    rows_affected: 0,
    rows: FixedArray::from_array(rows),
    error,
  }
}

///|
pub impl @engine.Engine for SQLiteEngine with exec(
  self,
  query : &@engine.QueryBuilder,
) -> @engine.QueryResult {
  let (sql, params) = match query.to_query() {
    @engine.Statement(stmt) => render_sqlite(stmt)
    @engine.Raw(sql, params) => (sql, params)
    @engine.Tx(op) => (sqlite_tx_sql(op), [])
  }
  self.exec_sql(sql, params)
}

///|
pub impl @engine.Engine for SQLiteEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  self.exec(@engine.Raw(sql, params))
}

///|
pub impl @engine.Engine for SQLiteEngine with close(self) -> Unit {
  try! self.conn.close()
}
