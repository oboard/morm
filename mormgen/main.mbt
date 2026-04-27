///|
const PKG_NAME = "@oboard/morm"

///|
/// 变换阶段：从 EntitySpec 构建 @morm.Table，不接触解析细节
fn transform_entity_to_table(
  spec : EntitySpec,
  source : String,
  enum_specs : Array[EnumSpec],
) -> @morm.Table {
  let columns : Array[@morm.Column] = []
  let foreign_keys : Array[@morm.ForeignKey] = []
  for f in spec.fields {
    if field_is_one_to_many(f.attrs, source) ||
      field_is_transient(f.attrs, source) {
      continue
    }
    let fk_col_opt = field_many_to_one_fk_column(f.label, f.attrs, source)
    let db_type = match fk_col_opt {
      Some(_) => @morm.ColumnType::Int
      None => map_type_to_db_by_name(f.field_type, f.attrs, enum_specs)
    }
    let (is_primary_key, is_auto_increment, _, primary_key_strategy) = collect_field_flags(
      f.attrs,
      source,
    )
    let is_nullable = f.nullable && !is_primary_key
    let col_name = match fk_col_opt {
      Some(n) => n
      None => f.label
    }
    let mut col : @morm.Column = {
      name: col_name,
      column_type: db_type,
      size: 0,
      nullable: is_nullable,
      default_value: None,
      auto_increment: is_auto_increment,
      primary_key: is_primary_key,
      unique: false,
      comment: "",
      charset: None,
      collation: None,
      engine_options: [],
    }
    let parsed_attrs = collect_orm_attributes_from_source(f.attrs, source)
    for attr in parsed_attrs {
      if attr.name is ("#morm.primary_key" | "#morm.id") &&
        attr.value.get("strategy") is Some(strategy) {
        col = @morm.add_column_engine_option(col, "pk.strategy", strategy)
      }
      if attr.name == "#morm.default" &&
        attr.value.get("value") is Some(default_expr) {
        if normalize_default_expr(default_expr) is Some(normalized) {
          col = { ..col, default_value: Some(normalized) }
        }
      }
      if attr.name is ("#morm.json" | "#morm.jsonb") &&
        attr.value.get("storage") is Some(storage) {
        col = @morm.add_column_engine_option(col, "json.storage", storage)
      }
      if attr.name
        is ("#morm.date" | "#morm.time" | "#morm.datetime" | "#morm.timestamp") &&
        attr.value.get("format") is Some(format) {
        col = @morm.add_column_engine_option(col, "temporal.format", format)
      }
    }
    if primary_key_strategy is Some(strategy) {
      let mut has_pk_strategy_opt = false
      for opt in col.engine_options {
        if opt.key == "pk.strategy" {
          has_pk_strategy_opt = true
        }
      }
      if !has_pk_strategy_opt {
        col = @morm.add_column_engine_option(col, "pk.strategy", strategy)
      }
    }
    columns.push(col)
    if parse_foreign_key_for_field(
        spec.name,
        f.label,
        f.field_type,
        f.attrs,
        source,
      )
      is Some(fk) {
      foreign_keys.push(fk)
    }
  }
  let mut table = @morm.new_table(
    spec.table_name,
    columns=FixedArray::from_array(columns),
  )
  for fk in foreign_keys {
    table = @morm.add_foreign_key(table, fk)
  }
  apply_entity_table_attributes(spec, table)
}

///|
fn entity_table_attr_value(spec : EntitySpec, key : String) -> String? {
  let mut result : String? = None
  for attr in spec.attrs {
    if attr.name is ("#morm.model" | "#morm.entity" | "#morm.table") &&
      attr.value.get(key) is Some(value) {
      result = Some(value)
    }
  }
  result
}

///|
fn attr_bool(value : String) -> Bool {
  let text = value.to_lower()
  text is ("true" | "1" | "yes" | "on")
}

///|
fn attr_int(value : String) -> Int? {
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
fn entity_table_attr_int(spec : EntitySpec, key : String) -> Int? {
  match entity_table_attr_value(spec, key) {
    Some(raw) => attr_int(raw)
    None => None
  }
}

///|
fn entity_table_attr_enabled(spec : EntitySpec, key : String) -> Bool {
  match entity_table_attr_value(spec, key) {
    Some(raw) => attr_bool(raw)
    None => false
  }
}

///|
fn orm_attr_bool(attr : ORMAttribute, key : String) -> Bool {
  match attr.value.get(key) {
    Some(raw) => attr_bool(raw)
    None => false
  }
}

///|
fn orm_attr_string(attr : ORMAttribute, key : String) -> String? {
  match attr.value.get(key) {
    Some(value) => Some(value)
    None => None
  }
}

///|
fn orm_attr_name_or_value(attr : ORMAttribute) -> String? {
  match orm_attr_string(attr, "name") {
    Some(value) => Some(value)
    None => orm_attr_string(attr, "value")
  }
}

///|
fn trim_space_text(s : String) -> String {
  let mut t = s
  while t.has_prefix(" ") || t.has_prefix("\t") {
    t = t[1:].to_string()
  }
  while t.has_suffix(" ") || t.has_suffix("\t") {
    let n = t.length()
    if n == 0 {
      break
    }
    t = t[0:n - 1].to_string()
  }
  t
}

///|
fn unquote_string_literal(text : String) -> String {
  if text.length() >= 2 && text.has_prefix("\"") && text.has_suffix("\"") {
    text[1:text.length() - 1].to_string()
  } else {
    text
  }
}

///|
fn single_quote_sql_string(text : String) -> String {
  "'" + text.replace(old="'", new="''") + "'"
}

///|
fn normalize_default_expr(raw_expr : String) -> String? {
  let expr = trim_space_text(raw_expr)
  if expr == "" {
    return None
  }
  let tokens = @lexer.tokens_from_string(expr, comment=true).tokens
  let (_, reports) = @handrolled_parser.parse_expr(tokens)
  if !reports.is_empty() {
    return None
  }
  let compact_lower = expr.replace_all(old=" ", new="").to_lower()
  if compact_lower is ("autoincrement()" | "autoincrement") {
    return None
  }
  if compact_lower == "true" {
    return Some("true")
  }
  if compact_lower == "false" {
    return Some("false")
  }
  if attr_int(expr) is Some(_) {
    return Some(expr)
  }
  if expr.has_prefix("[") || expr.has_prefix("{") {
    return Some(single_quote_sql_string(expr))
  }
  if expr.has_prefix("\"") && expr.has_suffix("\"") {
    return Some(single_quote_sql_string(unquote_string_literal(expr)))
  }
  Some(expr)
}

///|
fn apply_entity_table_attributes(
  spec : EntitySpec,
  table : @morm.Table,
) -> @morm.Table {
  let mut table = table
  for attr in spec.attrs {
    if attr.name == "#morm.postgres.schema" {
      if orm_attr_name_or_value(attr) is Some(schema_name) {
        table = @morm.table_schema(table, schema_name)
      }
      if orm_attr_string(attr, "authorization") is Some(role) {
        table = @morm.pg_schema_authorization(table, role)
      }
    }
    if attr.name == "#morm.postgres.table" {
      if orm_attr_name_or_value(attr) is Some(table_name) {
        table = { ..table, name: table_name }
      }
      if orm_attr_string(attr, "owner") is Some(role) {
        table = @morm.pg_table_owner(table, role)
      }
      if orm_attr_bool(attr, "unlogged") {
        table = @morm.pg_table_unlogged(table)
      }
      if orm_attr_string(attr, "with") is Some(with_clause) {
        table = @morm.pg_table_with(table, with_clause)
      }
      if orm_attr_string(attr, "on_commit") is Some(on_commit) {
        table = @morm.pg_table_on_commit(table, on_commit)
      }
      if orm_attr_string(attr, "tablespace") is Some(tablespace) {
        table = @morm.table_tablespace(table, tablespace)
      }
    }
    if attr.name == "#morm.postgres.grant" {
      let with_grant_option = orm_attr_bool(attr, "with_grant_option")
      if orm_attr_string(attr, "role") is Some(role) {
        if orm_attr_string(attr, "schema") is Some(privileges) {
          table = @morm.pg_schema_grant(
            table, role, privileges, with_grant_option,
          )
        }
        if orm_attr_string(attr, "table") is Some(privileges) {
          table = @morm.pg_table_grant(
            table, role, privileges, with_grant_option,
          )
        }
        if orm_attr_string(attr, "sequence") is Some(privileges) {
          table = @morm.pg_sequence_grant(
            table, role, privileges, with_grant_option,
          )
        }
        if orm_attr_string(attr, "schema_sequence") is Some(privileges) {
          table = @morm.pg_schema_sequence_grant(
            table, role, privileges, with_grant_option,
          )
        }
        if orm_attr_string(attr, "default_table") is Some(privileges) {
          table = @morm.pg_default_table_grant(
            table,
            role,
            privileges,
            with_grant_option,
            orm_attr_string(attr, "for_role"),
          )
        }
        if orm_attr_string(attr, "default_sequence") is Some(privileges) {
          table = @morm.pg_default_sequence_grant(
            table,
            role,
            privileges,
            with_grant_option,
            orm_attr_string(attr, "for_role"),
          )
        }
      }
    }
  }
  if entity_table_attr_value(spec, "name") is Some(name) {
    table = { ..table, name, }
  }
  if entity_table_attr_value(spec, "schema") is Some(schema) {
    table = @morm.table_schema(table, schema)
  }
  if entity_table_attr_value(spec, "catalog") is Some(catalog) {
    table = @morm.table_catalog(table, catalog)
  }
  if entity_table_attr_value(spec, "temporary") is Some(temporary) {
    table = @morm.table_temporary(table, attr_bool(temporary))
  }
  if entity_table_attr_value(spec, "if_not_exists") is Some(if_not_exists) {
    table = @morm.table_if_not_exists(table, attr_bool(if_not_exists))
  }
  if entity_table_attr_value(spec, "engine") is Some(engine) {
    table = @morm.table_engine(table, engine)
  }
  if entity_table_attr_value(spec, "charset") is Some(charset) {
    table = { ..table, charset: Some(charset) }
  }
  if entity_table_attr_value(spec, "collation") is Some(collation) {
    table = { ..table, collation: Some(collation) }
  }
  if entity_table_attr_value(spec, "tablespace") is Some(tablespace) {
    table = @morm.table_tablespace(table, tablespace)
  }
  if entity_table_attr_value(spec, "comment") is Some(comment) {
    table = @morm.table_comment(table, comment)
  }
  if entity_table_attr_int(spec, "auto_increment") is Some(value) {
    table = { ..table, auto_increment: Some(value) }
  }
  if entity_table_attr_value(spec, "create_suffix") is Some(create_suffix) {
    table = @morm.table_create_suffix(table, create_suffix)
  }
  if entity_table_attr_value(spec, "mysql_row_format") is Some(row_format) {
    table = @morm.mysql_table_row_format(table, row_format)
  }
  if entity_table_attr_int(spec, "mysql_key_block_size") is Some(value) {
    table = @morm.mysql_table_key_block_size(table, value)
  }
  if entity_table_attr_value(spec, "mysql_compression") is Some(compression) {
    table = @morm.mysql_table_compression(table, compression)
  }
  if entity_table_attr_enabled(spec, "pg_unlogged") {
    table = @morm.pg_table_unlogged(table)
  }
  if entity_table_attr_value(spec, "pg_with") is Some(with_clause) {
    table = @morm.pg_table_with(table, with_clause)
  }
  if entity_table_attr_value(spec, "pg_on_commit") is Some(on_commit) {
    table = @morm.pg_table_on_commit(table, on_commit)
  }
  if entity_table_attr_value(spec, "oracle_organization") is Some(organization) {
    table = @morm.oracle_table_organization(table, organization)
  }
  if entity_table_attr_value(spec, "oracle_on_commit") is Some(on_commit) {
    table = @morm.oracle_table_on_commit(table, on_commit)
  }
  if entity_table_attr_enabled(spec, "sqlserver_memory_optimized") {
    table = @morm.sqlserver_table_memory_optimized(table)
  }
  if entity_table_attr_value(spec, "sqlserver_durability") is Some(durability) {
    table = @morm.sqlserver_table_durability(table, durability)
  }
  if entity_table_attr_value(spec, "sqlserver_filegroup") is Some(filegroup) {
    table = @morm.sqlserver_table_filegroup(table, filegroup)
  }
  if entity_table_attr_value(spec, "sqlserver_textimage_on") is Some(filegroup) {
    table = @morm.sqlserver_table_textimage_on(table, filegroup)
  }
  if entity_table_attr_enabled(spec, "sqlite_without_rowid") {
    table = @morm.sqlite_table_without_rowid(table)
  }
  if entity_table_attr_enabled(spec, "sqlite_strict") {
    table = @morm.sqlite_table_strict(table)
  }
  table
}

///|
fn escape_mbt_string(s : String) -> String {
  s
  .replace(old="\\", new="\\\\")
  .replace(old="\"", new="\\\"")
  .replace(old="\n", new="\\n")
  .replace(old="\r", new="\\r")
  .replace(old="\t", new="\\t")
}

///|
fn mbt_string(s : String) -> String {
  "\"" + escape_mbt_string(s) + "\""
}

///|
fn mbt_opt_string(v : String?) -> String {
  match v {
    Some(text) => "Some(" + mbt_string(text) + ")"
    None => "None"
  }
}

///|
fn mbt_opt_int(v : Int?) -> String {
  match v {
    Some(value) => "Some(" + value.to_string() + ")"
    None => "None"
  }
}

///|
fn render_column_type(ty : @morm.ColumnType) -> String {
  match ty {
    TinyInt => "TinyInt"
    SmallInt => "SmallInt"
    MediumInt => "MediumInt"
    Int => "Int"
    BigInt => "BigInt"
    Float => "Float"
    Double => "Double"
    Decimal(p, s) => "Decimal(\{p}, \{s})"
    Char(len) => "Char(\{len})"
    VarChar(len) => "VarChar(\{len})"
    Text => "Text"
    MediumText => "MediumText"
    LongText => "LongText"
    Binary(len) => "Binary(\{len})"
    VarBinary(len) => "VarBinary(\{len})"
    Blob => "Blob"
    MediumBlob => "MediumBlob"
    LongBlob => "LongBlob"
    Date => "Date"
    Time => "Time"
    DateTime => "DateTime"
    Timestamp => "Timestamp"
    Year => "Year"
    Json => "Json"
    JsonB => "JsonB"
    Enum(name, values) => {
      let rendered_values = values.map(mbt_string).join(", ")
      "Enum(\{mbt_string(name)}, [\{rendered_values}])"
    }
    Boolean => "Boolean"
  }
}

///|
fn render_index_type(ty : @morm.IndexType) -> String {
  match ty {
    Primary => "\{PKG_NAME}.Primary"
    Unique => "\{PKG_NAME}.Unique"
    Index => "\{PKG_NAME}.Index"
    FullText => "\{PKG_NAME}.FullText"
    Spatial => "\{PKG_NAME}.Spatial"
  }
}

///|
fn render_column(col : @morm.Column) -> String {
  let engine_options = col.engine_options
    .map(option => {
      (
        $|          {
        $|            key: \{mbt_string(option.key)},
        $|            value: \{mbt_string(option.value)},
        $|          }
      )
    })
    .join(",\n")
  (
    $|      {
    $|        name: \{mbt_string(col.name)},
    $|        column_type: \{render_column_type(col.column_type)},
    $|        size: \{col.size},
    $|        nullable: \{col.nullable},
    $|        auto_increment: \{col.auto_increment},
    $|        primary_key: \{col.primary_key},
    $|        unique: \{col.unique},
    $|        comment: \{mbt_string(col.comment)},
    $|        charset: \{mbt_opt_string(col.charset)},
    $|        collation: \{mbt_opt_string(col.collation)},
    $|        default_value: \{mbt_opt_string(col.default_value)},
    $|        engine_options: [
    $|\{engine_options}
    $|        ],
    $|      }
  )
}

///|
fn render_index(idx : @morm.Index) -> String {
  let cols = idx.columns.map(c => mbt_string(c)).join(", ")
  (
    $|      {
    $|        name: \{mbt_string(idx.name)},
    $|        index_type: \{render_index_type(idx.index_type)},
    $|        columns: [\{cols}],
    $|        comment: \{mbt_string(idx.comment)},
    $|      }
  )
}

///|
fn render_foreign_key(fk : @morm.ForeignKey) -> String {
  (
    $|      {
    $|        name: \{mbt_string(fk.name)},
    $|        column: \{mbt_string(fk.column)},
    $|        referenced_table: \{mbt_string(fk.referenced_table)},
    $|        referenced_column: \{mbt_string(fk.referenced_column)},
    $|        on_delete: \{mbt_string(fk.on_delete)},
    $|        on_update: \{mbt_string(fk.on_update)},
    $|      }
  )
}

///|
fn render_table_engine_option(option : @morm.TableEngineOption) -> String {
  (
    $|      {
    $|        key: \{mbt_string(option.key)},
    $|        value: \{mbt_string(option.value)},
    $|      }
  )
}

///|
fn render_table_literal(table : @morm.Table) -> String {
  let columns = table.columns.map(render_column).join(",\n")
  let indexes = table.indexes.map(render_index).join(",\n")
  let foreign_keys = table.foreign_keys.map(render_foreign_key).join(",\n")
  let engine_options = table.engine_options
    .map(render_table_engine_option)
    .join(",\n")
  (
    $| \{PKG_NAME}.Table::{
    $|   name: \{mbt_string(table.name)},
    $|   schema: \{mbt_opt_string(table.schema)},
    $|   catalog: \{mbt_opt_string(table.catalog)},
    $|   columns: [
    $|\{columns}
    $|   ],
    $|   indexes: [
    $|\{indexes}
    $|   ],
    $|   foreign_keys: [
    $|\{foreign_keys}
    $|   ],
    $|   temporary: \{table.temporary},
    $|   if_not_exists: \{table.if_not_exists},
    $|   engine: \{mbt_opt_string(table.engine)},
    $|   charset: \{mbt_opt_string(table.charset)},
    $|   collation: \{mbt_opt_string(table.collation)},
    $|   tablespace: \{mbt_opt_string(table.tablespace)},
    $|   comment: \{mbt_string(table.comment)},
    $|   auto_increment: \{mbt_opt_int(table.auto_increment)},
    $|   engine_options: [
    $|\{engine_options}
    $|   ],
    $| }
  )
}

///|
/// 代码生成阶段：从表结构生成实现代码
fn is_param_decodable_type(
  type_name : String,
  enum_specs : Array[EnumSpec],
) -> Bool {
  if find_enum_spec(enum_specs, type_name) is Some(_) {
    return true
  }
  match type_name {
    "Unit"
    | "Bool"
    | "Byte"
    | "Int"
    | "Int16"
    | "UInt16"
    | "UInt"
    | "UInt64"
    | "Int64"
    | "BigInt"
    | "Float"
    | "Double"
    | "String"
    | "Bytes"
    | "Json"
    | "PlainDate"
    | "PlainTime"
    | "PlainDateTime"
    | "ZonedDateTime" => true
    _ => false
  }
}

///|
fn entity_supports_row_decoder(
  spec : EntitySpec,
  enum_specs : Array[EnumSpec],
) -> Bool {
  for field in spec.fields {
    let attrs = collect_orm_attributes(field.attrs)
    for attr in attrs {
      if attr.name is ("#morm.one_to_many" | "#morm.many_to_one") {
        return false
      }
    }
    if !is_param_decodable_type(field.field_type, enum_specs) {
      return false
    }
  }
  true
}

///|
fn render_from_param_expr(
  type_name : String,
  value_expr : String,
  nullable : Bool,
) -> String {
  if nullable {
    return "match " +
      value_expr +
      " { Null => None; _ => Some((try! @engine.from_param(" +
      value_expr +
      ") : " +
      type_name +
      ")) }"
  }
  "(try! @engine.from_param(\{value_expr}) : \{type_name})"
}

///|
fn field_json_storage(field : FieldSpec) -> String? {
  for attr in collect_orm_attributes(field.attrs) {
    if attr.name is ("#morm.json" | "#morm.jsonb") &&
      attr.value.get("storage") is Some(storage) {
      return Some(storage)
    }
  }
  None
}

///|
fn render_field__from_expr(field : FieldSpec, value_expr : String) -> String {
  if field.field_type == "Json" {
    if field_json_storage(field) is Some(storage) {
      if field.nullable {
        return "match \{value_expr} { Null => None; _ => Some(try! @engine.decode_json_column(\{value_expr}, \{mbt_string(storage)})) }"
      }
      return "(try! @engine.decode_json_column(\{value_expr}, \{mbt_string(storage)}))"
    }
  }
  render_from_param_expr(field.field_type, value_expr, field.nullable)
}

///|
fn render_entity__from(spec : EntitySpec) -> String {
  let field_lines : Array[String] = []
  let ctor_lines : Array[String] = []
  for field in spec.fields {
    let param_name = field.label + "_param"
    field_lines.push(
      "    let " +
      param_name +
      " = match row.get(\"" +
      field.label +
      "\") { Some(value) => value; None => panic() }",
    )
    let field_ty = if field.nullable {
      field.field_type + "?"
    } else {
      field.field_type
    }
    field_lines.push(
      "    let " +
      field.label +
      " : " +
      field_ty +
      " = " +
      render_field__from_expr(field, param_name),
    )
    ctor_lines.push("      " + field.label + ",")
  }
  let fields_code = field_lines.join("\n")
  let ctor_code = ctor_lines.join("\n")
  (
    $| pub fn \{spec.name}::_from(row : Map[String, @engine.Param]) -> \{spec.name} {
    $|\{fields_code}
    $|     return \{spec.name}::{
    $|\{ctor_code}
    $|     }
    $| }
  )
}

///|
fn generate_entity_impl(
  spec : EntitySpec,
  table : @morm.Table,
  enum_specs : Array[EnumSpec],
) -> String {
  let name = spec.name
  let table_literal = render_table_literal(table)
  let row_decoder = if entity_supports_row_decoder(spec, enum_specs) {
    "\n" +
    render_entity__from(spec) +
    "\n" +
    (
      $| pub impl @engine.FromParam for \{name} with from_param(value) {
      $|   match value {
      $|     @engine.Object(obj) => {
      $|       let row : Map[String, @engine.Param] = Map::new()
      $|       for key in obj.keys() {
      $|         if obj.get(key) is Some(value) {
      $|           row.set(key, value)
      $|         }
      $|       }
      $|       \{name}::_from(row)
      $|     }
      $|     _ => raise @engine.ParamDecodeError("\{name}::from_param: expected Json object row")
      $|   }
      $| }
    )
  } else {
    ""
  }
  (
    $| pub impl \{PKG_NAME}.Entity for \{name} with table(_self) -> \{PKG_NAME}.Table { \{name}::table() }
    $| pub fn \{name}::table() -> \{PKG_NAME}.Table {
    $|\{table_literal}
    $| }
    $|\{row_decoder}
  )
}

///|
fn find_entity_spec(specs : Array[EntitySpec], name : String) -> EntitySpec? {
  for spec in specs {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
fn find_entity_spec_by_table(
  specs : Array[EntitySpec],
  table_name : String,
) -> EntitySpec? {
  for spec in specs {
    if spec.table_name == table_name {
      return Some(spec)
    }
  }
  None
}

///|
fn field_has_orm_attr_name(field : FieldSpec, attr_name : String) -> Bool {
  for attr in collect_orm_attributes(field.attrs) {
    if attr.name == attr_name {
      return true
    }
  }
  false
}

///|
fn field_is_primary_key_for_codegen(field : FieldSpec) -> Bool {
  field.label == "id" ||
  field_has_orm_attr_name(field, "#morm.id") ||
  field_has_orm_attr_name(field, "#morm.primary_key")
}

///|
fn field_is_relation_or_virtual_for_codegen(field : FieldSpec) -> Bool {
  field_has_orm_attr_name(field, "#morm.one_to_many") ||
  field_has_orm_attr_name(field, "#morm.many_to_one") ||
  field_has_orm_attr_name(field, "#morm.transient")
}

///|
fn entity_primary_key_field_for_codegen(spec : EntitySpec) -> FieldSpec? {
  for field in spec.fields {
    if field_is_primary_key_for_codegen(field) {
      return Some(field)
    }
  }
  None
}

///|
fn render_partial_update_expr(
  table_expr : String,
  entity_spec : EntitySpec,
  param_name : String,
) -> String? {
  let set_fields : Array[String] = []
  let where_fields : Array[String] = []
  for field in entity_spec.fields {
    if field_is_relation_or_virtual_for_codegen(field) {
      continue
    }
    if field_is_primary_key_for_codegen(field) {
      where_fields.push(field.label)
    } else {
      set_fields.push(field.label)
    }
  }
  if set_fields.length() == 0 || where_fields.length() == 0 {
    return None
  }
  let parts : Array[String] = []
  parts.push("\{PKG_NAME}.update(\{table_expr})")
  for label in set_fields {
    parts.push(".set(\"\{label}\", \{param_name}.\{label})")
  }
  for label in where_fields {
    parts.push(".where_eq(\"\{label}\", \{param_name}.\{label})")
  }
  Some(parts.join(""))
}

///|
fn option_inner_type(type_name : String) -> String? {
  if type_name.has_suffix("?") {
    let n = type_name.length()
    return Some(type_name[0:n - 1].to_string())
  }
  None
}

///|
fn is_pageable_type_name(type_name : String) -> Bool {
  type_name
  is ("Pageable"
  | "@morm.Pageable"
  | "@oboard/morm.Pageable"
  | "@engine.Pageable")
}

///|
fn find_pageable_param_name(params : Array[(String, String)]) -> String? {
  for p in params {
    let (param_name, param_type) = p
    if is_pageable_type_name(param_type) || param_name == "pageable" {
      return Some(param_name)
    }
  }
  None
}

///|
fn render_collection_map_key_expr(
  key_type : String,
  value_type : String,
  row_expr : String,
  value_expr : String,
  entity_specs : Array[EntitySpec],
) -> String {
  match find_entity_spec(entity_specs, value_type) {
    Some(spec) =>
      match entity_primary_key_field_for_codegen(spec) {
        Some(field) => "\{value_expr}.\{field.label}"
        None =>
          (
            $| let key_param = match \{row_expr}.get("id") {
            $|   Some(value) => value
            $|   None => panic()
            $| }
            $| \{render_from_param_expr(key_type, "key_param", false)}
          )
      }
    None =>
      (
        $| let key_param = match \{row_expr}.get("id") {
        $|   Some(value) => value
        $|   None => panic()
        $| }
        $| \{render_from_param_expr(key_type, "key_param", false)}
      )
  }
}

///|
fn render_collection_decode_code(
  ret_type : String,
  return_kind : String,
  item_type : String?,
  map_key_type : String?,
  map_value_type : String?,
  query_expr : String,
  row_decode_expr : String,
  entity_specs : Array[EntitySpec],
) -> String {
  match return_kind {
    "FixedArray" =>
      (
        $|   \{query_expr}.rows.map(row => \{row_decode_expr})
        $| }
        $|
      )
    "Array" =>
      (
        $|   let out : \{ret_type} = []
        $|   for row in \{query_expr}.rows {
        $|     out.push(\{row_decode_expr})
        $|   }
        $|   out
        $| }
        $|
      )
    "Set" =>
      (
        $|   let out : \{ret_type} = @set.Set::new()
        $|   for row in \{query_expr}.rows {
        $|     out.add(\{row_decode_expr})
        $|   }
        $|   out
        $| }
        $|
      )
    "List" =>
      match item_type {
        Some(_) =>
          (
            $|   let out : Array[\{item_type.unwrap()}] = []
            $|   for row in \{query_expr}.rows {
            $|     out.push(\{row_decode_expr})
            $|   }
            $|   @list.List::from_array(out)
            $| }
            $|
          )
        None =>
          (
            $|   panic()
            $| }
            $|
          )
      }
    "Map" =>
      match (map_key_type, map_value_type) {
        (Some(key_type), Some(value_type)) => {
          let key_expr = render_collection_map_key_expr(
            key_type, value_type, "row", "value", entity_specs,
          )
          (
            $|   let out : \{ret_type} = Map::new()
            $|   for row in \{query_expr}.rows {
            $|     let value : \{value_type} = \{row_decode_expr}
            $|     let key : \{key_type} = \{key_expr}
            $|     out.set(key, value)
            $|   }
            $|   out
            $| }
            $|
          )
        }
        _ =>
          (
            $|   panic()
            $| }
            $|
          )
      }
    _ =>
      (
        $|   panic()
        $| }
        $|
      )
  }
}

///|
fn render_query_result_decode_expr(
  type_name : String,
  value_expr : String,
  entity_specs : Array[EntitySpec],
  enum_specs : Array[EnumSpec],
) -> String {
  match find_entity_spec(entity_specs, type_name) {
    Some(spec) =>
      if entity_supports_row_decoder(spec, enum_specs) {
        "\{type_name}::_from(\{value_expr})"
      } else {
        "(try! @engine.from_param(\{value_expr}) : \{type_name})"
      }
    None => "(try! @engine.from_param(\{value_expr}) : \{type_name})"
  }
}

///|
fn render_enum_codec_impl(enum_spec : EnumSpec) -> String {
  (
    $| pub impl @engine.ToParam for \{enum_spec.name} with to_param(self) -> @engine.Param {
    $|   try! @engine.enum_to_param(self)
    $| }
    $|
    $| pub impl @engine.FromParam for \{enum_spec.name} with from_param(value) {
    $|   try! @engine.enum_from_param(value)
    $| }
  )
}

///|
fn field_has_attr(field : FieldSpec, attr_name : String) -> Bool {
  let orm_attrs = collect_orm_attributes(field.attrs)
  let mut hit = false
  orm_attrs.each(a => if a.name == attr_name { hit = true })
  hit
}

///|
fn field_auto_create_time(field : FieldSpec) -> Bool {
  field_has_attr(field, "#morm.auto_create_time") || field.label == "created_at"
}

///|
fn field_auto_update_time(field : FieldSpec) -> Bool {
  field_has_attr(field, "#morm.auto_update_time") || field.label == "updated_at"
}

///|
fn auto_time_value_expr(field : FieldSpec) -> String? {
  let base = match field.field_type {
    "PlainDateTime" | "DateTime" =>
      Some("\{PKG_NAME}.current_plain_date_time_utc()")
    "ZonedDateTime" | "Timestamp" => Some("\{PKG_NAME}.current_timestamp_utc()")
    _ => None
  }
  match base {
    Some(expr) =>
      if field.nullable {
        Some("Some(" + expr + ")")
      } else {
        Some(expr)
      }
    None => None
  }
}

///|
fn path_dirname(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let cut = match (slash, backslash) {
    (Some(a), Some(b)) => Some(if a > b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match cut {
    Some(0) => "/"
    Some(idx) => path[0:idx].to_string()
    None => "."
  }
}

///|
fn path_join(dir : String, name : String) -> String {
  if dir is ("." | "") {
    name
  } else if dir == "/" {
    "/" + name
  } else {
    dir + "/" + name
  }
}

///|
fn is_source_mbt_file(name : String) -> Bool {
  name.has_suffix(".mbt") &&
  !name.has_suffix(".g.mbt") &&
  !name.has_suffix("_test.mbt") &&
  !name.has_suffix("_wbtest.mbt")
}

///|
fn collect_package_entity_specs(
  input_file : String,
) -> Array[EntitySpec] raise @fs.IOError {
  let dir = path_dirname(input_file)
  let merged : Array[EntitySpec] = []
  let seen : Map[String, Bool] = Map::new()
  for entry in @fs.read_dir(dir) {
    if !is_source_mbt_file(entry) {
      continue
    }
    let path = path_join(dir, entry)
    guard @fs.is_file(path) else { continue }
    let (file_ast, _) = @parser.parse_file(path)
    for spec in parse_entities_from_ast(file_ast) {
      if seen.contains(spec.name) {
        continue
      }
      seen.set(spec.name, true)
      merged.push(spec)
    }
  }
  merged
}

///|
fn collect_package_enum_specs(
  input_file : String,
) -> Array[EnumSpec] raise @fs.IOError {
  let dir = path_dirname(input_file)
  let merged : Array[EnumSpec] = []
  let seen : Map[String, Bool] = Map::new()
  for entry in @fs.read_dir(dir) {
    if !is_source_mbt_file(entry) {
      continue
    }
    let path = path_join(dir, entry)
    guard @fs.is_file(path) else { continue }
    let source = @fs.read_file_to_string(path)
    for spec in parse_enum_specs_from_source(source) {
      if seen.contains(spec.name) {
        continue
      }
      seen.set(spec.name, true)
      merged.push(spec)
    }
  }
  merged
}

///|
/// 代码生成阶段：根据 MapperSpec 生成 struct、mapper 函数与方法实现
fn generate_mapper_code(
  spec : MapperSpec,
  entity_specs : Array[EntitySpec],
  enum_specs : Array[EnumSpec],
) -> String {
  let trait_name = spec.trait_name
  let impl_name = trait_name + "Impl"
  let entity_name = spec.entity_name
  let entity_spec = match entity_name {
    Some(name) => find_entity_spec(entity_specs, name)
    None => None
  }
  let table_expr = match spec.table_name {
    Some(t) => "\"\{t}\""
    None =>
      match entity_name {
        Some(n) => "\{n}::table().name"
        None => "\"\""
      }
  }
  let struct_def =
    $| pub struct \{impl_name} {
    $|   engine : &@engine.Engine
    $| }
    $|
  let mapper_fn =
    $| pub fn \{impl_name}::new(engine : &@engine.Engine) -> \{impl_name} {
    $|   \{impl_name}::{ engine, }
    $| }
    $|
  let mut has_sync_methods = false
  for m in spec.methods {
    if !m.is_async {
      has_sync_methods = true
    }
  }
  let mapper_helpers = if has_sync_methods {
    (
      $| pub fn[Q : @engine.QueryBuilder] \{impl_name}::exec_query_sync(
      $|   self : \{impl_name},
      $|   q : Q,
      $| ) -> @engine.QueryResult {
      $|   let mut res : @engine.QueryResult = {
      $|     ok: false,
      $|     rows_affected: 0,
      $|     rows: [],
      $|     error: Some("async execution did not return"),
      $|   }
      $|   @async.run_async_main(() => {
      $|     res = self.engine.exec(q)
      $|   })
      $|   res
      $| }
      $|
      $| pub fn \{impl_name}::exec_raw_sync(
      $|   self : \{impl_name},
      $|   sql : String,
      $|   params : FixedArray[@engine.Param],
      $| ) -> @engine.QueryResult {
      $|   let mut res : @engine.QueryResult = {
      $|     ok: false,
      $|     rows_affected: 0,
      $|     rows: [],
      $|     error: Some("async execution did not return"),
      $|   }
      $|   @async.run_async_main(() => {
      $|     res = self.engine.exec_raw(sql, params)
      $|   })
      $|   res
      $| }
      $|
    )
  } else {
    ""
  }
  let mut impls = ""
  for m in spec.methods {
    let param_sig_parts : Array[String] = []
    let sql_args_parts : Array[String] = []
    let pageable_param_name = find_pageable_param_name(m.params)
    for p in m.params {
      let (pname, ptype) = p
      param_sig_parts.push("\{pname} : \{ptype}")
      if pageable_param_name != Some(pname) {
        sql_args_parts.push("@engine.to_param(\{pname})")
      }
    }
    let param_sig = if param_sig_parts.length() == 0 {
      "self"
    } else {
      "self, " + param_sig_parts.join(", ")
    }
    let query_args = "[" + sql_args_parts.join(", ") + "]"
    // 返回类型字符串
    let ret_type = m.return_type
    let return_kind = m.return_kind
    let array_item_type = match m.return_item_type {
      Some(inner) => inner
      None => "Param"
    }
    let map_key_type = m.return_map_key_type
    let map_value_type = m.return_map_value_type
    let option_value_type = match option_inner_type(ret_type) {
      Some(inner) => inner
      None => ret_type
    }
    let collection_item_type = match map_value_type {
      Some(value_type) => value_type
      None => array_item_type
    }
    let collection_decode_expr = render_query_result_decode_expr(
      collection_item_type, "row", entity_specs, enum_specs,
    )
    let option_decode_expr = render_query_result_decode_expr(
      option_value_type, "result", entity_specs, enum_specs,
    )
    let value_decode_expr = render_query_result_decode_expr(
      ret_type, "result", entity_specs, enum_specs,
    )
    let method_header =
      $| pub impl \{trait_name} for \{impl_name} with \{m.name}(
      $|   \{param_sig}
      $| ) -> \{ret_type} {
    let body = if m.name == "create" && m.params.length() == 1 {
      let entity_param_name = m.params[0].0
      let create_entity_spec = match entity_spec {
        Some(spec) => Some(spec)
        None =>
          match find_entity_spec(entity_specs, m.params[0].1) {
            Some(spec) => Some(spec)
            None =>
              match spec.table_name {
                Some(table_name) =>
                  find_entity_spec_by_table(entity_specs, table_name)
                None => None
              }
          }
      }
      let auto_assigns : Array[String] = []
      match create_entity_spec {
        Some(create_spec) =>
          for field in create_spec.fields {
            if field_auto_create_time(field) || field_auto_update_time(field) {
              match auto_time_value_expr(field) {
                Some(expr) => auto_assigns.push(field.label + ": " + expr)
                None => ()
              }
            }
          }
        None => ()
      }
      let auto_stamp_code = if auto_assigns.length() > 0 {
        let assigns = auto_assigns.join(", ")
        (
          $|   let \{entity_param_name} = {
          $|     ..\{entity_param_name},
          $|     \{assigns},
          $|   }
        )
      } else {
        ""
      }
      if ret_type == "Bool" {
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.insert_into(\{table_expr}).from(\{entity_param_name})
          $|   self.engine.exec(q).ok
          $| }
          $|
        )
      } else if m.returns_option {
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.insert_into(\{table_expr}).from(\{entity_param_name})
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return Some(\{option_decode_expr})
          $|   }
          $|   None
          $| }
          $|
        )
      } else {
        let entity_ty = m.params[0].1
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.insert_into(\{table_expr}).from(\{entity_param_name})
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return \{render_query_result_decode_expr(entity_ty, "result", entity_specs, enum_specs)}
          $|   }
          $|   panic()
          $| }
          $|
        )
      }
    } else if m.name == "save" && m.params.length() == 1 {
      let entity_param_name = m.params[0].0
      let save_entity_spec = match entity_spec {
        Some(spec) => Some(spec)
        None =>
          match find_entity_spec(entity_specs, m.params[0].1) {
            Some(spec) => Some(spec)
            None =>
              match spec.table_name {
                Some(table_name) =>
                  find_entity_spec_by_table(entity_specs, table_name)
                None => None
              }
          }
      }
      let auto_assigns : Array[String] = []
      match save_entity_spec {
        Some(save_spec) =>
          for field in save_spec.fields {
            if field_auto_create_time(field) || field_auto_update_time(field) {
              match auto_time_value_expr(field) {
                Some(expr) => auto_assigns.push(field.label + ": " + expr)
                None => ()
              }
            }
          }
        None => ()
      }
      let auto_stamp_code = if auto_assigns.length() > 0 {
        let assigns = auto_assigns.join(", ")
        (
          $|   let \{entity_param_name} = {
          $|     ..\{entity_param_name},
          $|     \{assigns},
          $|   }
        )
      } else {
        ""
      }
      if ret_type == "Bool" {
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.upsert_into(\{table_expr}).from(\{entity_param_name})
          $|   self.engine.exec(q).ok
          $| }
          $|
        )
      } else if m.returns_option {
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.upsert_into(\{table_expr}).from(\{entity_param_name})
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return Some(\{option_decode_expr})
          $|   }
          $|   None
          $| }
          $|
        )
      } else {
        let entity_ty = m.params[0].1
        (
          $|\{auto_stamp_code}
          $|   let q = \{PKG_NAME}.upsert_into(\{table_expr}).from(\{entity_param_name})
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return \{render_query_result_decode_expr(entity_ty, "result", entity_specs, enum_specs)}
          $|   }
          $|   panic()
          $| }
          $|
        )
      }
    } else if m.name == "update" && m.params.length() == 1 {
      let entity_param_name = m.params[0].0
      let update_entity_spec = match entity_spec {
        Some(spec) => Some(spec)
        None =>
          match find_entity_spec(entity_specs, m.params[0].1) {
            Some(spec) => Some(spec)
            None =>
              match spec.table_name {
                Some(table_name) =>
                  find_entity_spec_by_table(entity_specs, table_name)
                None => None
              }
          }
      }
      let auto_assigns : Array[String] = []
      match update_entity_spec {
        Some(update_spec) =>
          for field in update_spec.fields {
            if field_auto_update_time(field) {
              match auto_time_value_expr(field) {
                Some(expr) => auto_assigns.push(field.label + ": " + expr)
                None => ()
              }
            }
          }
        None => ()
      }
      let auto_stamp_code = if auto_assigns.length() > 0 {
        let assigns = auto_assigns.join(", ")
        (
          $|   let \{entity_param_name} = {
          $|     ..\{entity_param_name},
          $|     \{assigns},
          $|   }
        )
      } else {
        ""
      }
      let partial_update_code = match update_entity_spec {
        Some(update_spec) =>
          render_partial_update_expr(table_expr, update_spec, entity_param_name)
        None => None
      }
      let update_query_expr = match partial_update_code {
        Some(code) => code
        None => "\{PKG_NAME}.update(\{table_expr}).from(\{entity_param_name})"
      }
      if ret_type == "Bool" {
        (
          $|\{auto_stamp_code}
          $|   let q = \{update_query_expr}
          $|   self.engine.exec(q).ok
          $| }
          $|
        )
      } else if m.returns_option {
        (
          $|\{auto_stamp_code}
          $|   let q = \{update_query_expr}
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return Some(\{option_decode_expr})
          $|   }
          $|   None
          $| }
          $|
        )
      } else {
        (
          $|\{auto_stamp_code}
          $|   let q = \{update_query_expr}
          $|   let res = self.engine.exec(q)
          $|   if res.rows is [result, ..] {
          $|     return \{value_decode_expr}
          $|   }
          $|   panic()
          $| }
          $|
        )
      }
    } else if m.name == "delete" && m.params.length() == 1 {
      let entity_param_name = m.params[0].0
      (
        $|   let q = \{PKG_NAME}.delete_from(\{table_expr}).from(\{entity_param_name})
        $|   self.engine.exec(q).ok
        $| }
        $|
      )
    } else {
      let builder_code_with_fetch = match m.fetch_join {
        Some(join_sql) => {
          let join_escaped = join_sql.replace(old="\"", new="\\\"")
          match m.builder_code {
            Some(code) => Some(code + ".join(\"" + join_escaped + "\")")
            None => None
          }
        }
        None => m.builder_code
      }
      match m.builder_code {
        Some(_) =>
          match builder_code_with_fetch {
            Some(code) =>
              if ret_type == "Bool" &&
                (
                  code.has_prefix("\{PKG_NAME}.update(") ||
                  code.has_prefix("\{PKG_NAME}.delete_from(") ||
                  code.has_prefix("\{PKG_NAME}.insert_into(") ||
                  code.has_prefix("\{PKG_NAME}.upsert_into(")
                ) {
                (
                  $|   let q = \{code}
                  $|   self.engine.exec(q).ok
                  $| }
                  $|
                )
              } else if return_kind == "Page" {
                match pageable_param_name {
                  Some(pageable_name) =>
                    (
                      $|   @morm.paginate(self.engine, \{code}, \{pageable_name})
                      $| }
                      $|
                    )
                  None =>
                    (
                      $|   panic()
                      $| }
                      $|
                    )
                }
              } else if return_kind
                is ("FixedArray" | "Array" | "Set" | "List" | "Map") {
                render_collection_decode_code(
                  ret_type,
                  return_kind,
                  m.return_item_type,
                  map_key_type,
                  map_value_type,
                  "self.engine.exec(\{code})",
                  collection_decode_expr,
                  entity_specs,
                )
              } else if m.returns_option {
                (
                  $|   let q = \{code}
                  $|   if self.engine.exec(q).rows
                  $|     is [result, ..] {
                  $|     return Some(\{option_decode_expr})
                  $|   }
                  $|   None
                  $| }
                  $|
                )
              } else {
                (
                  $|   let q = \{code}
                  $|   if self.engine.exec(q).rows
                  $|     is [result, ..] {
                  $|     return \{value_decode_expr}
                  $|   }
                  $|   panic()
                  $| }
                  $|
                )
              }
            None => panic()
          }
        None => {
          let sql = m.sql.unwrap()
          if ret_type == "Bool" {
            (
              $|   self.engine.exec_raw("\{sql}", \{query_args}).ok
              $| }
              $|
            )
          } else if return_kind == "Page" {
            match pageable_param_name {
              Some(pageable_name) =>
                (
                  $|   @morm.paginate_raw(self.engine, "\{sql}", \{query_args}, \{pageable_name})
                  $| }
                  $|
                )
              None =>
                (
                  $|   panic()
                  $| }
                  $|
                )
            }
          } else if return_kind
            is ("FixedArray" | "Array" | "Set" | "List" | "Map") {
            render_collection_decode_code(
              ret_type,
              return_kind,
              m.return_item_type,
              map_key_type,
              map_value_type,
              "self.engine.exec_raw(\"\{sql}\", \{query_args})",
              collection_decode_expr,
              entity_specs,
            )
          } else if m.returns_option {
            (
              $|   if self.engine.exec_raw("\{sql}", \{query_args}).rows
              $|     is [result, ..] {
              $|     return Some(\{option_decode_expr})
              $|   }
              $|   None
              $| }
              $|
            )
          } else {
            (
              $|   if self.engine.exec_raw("\{sql}", \{query_args}).rows
              $|     is [result, ..] {
              $|     return \{value_decode_expr}
              $|   }
              $|   panic()
              $| }
              $|
            )
          }
        }
      }
    }
    impls = impls + method_header + body
  }
  struct_def + mapper_fn + mapper_helpers + impls
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let cli_args = if argv.length() > 0 { argv[1:] } else { [] }
  let cmd = @argparse.Command(
    "mormgen",
    about="MoonBit ORM CLI tool for generating database schema from MoonBit files",
    options=[
      @argparse.OptionArg(
        "output-file",
        short='o',
        about="Output file",
        required=true,
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "input_file",
        about="Input MoonBit source file",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
  let matches = cmd.parse(argv=cli_args, env={}) catch {
    e => {
      println("\{e}")
      return
    }
  }
  let input_file = match matches.values.get("input_file") {
    Some([file, ..]) => file
    _ => {
      println(cmd.render_help())
      return
    }
  }
  let output_file = match matches.values.get("output-file") {
    Some([file, ..]) => file
    _ => {
      println(cmd.render_help())
      return
    }
  }
  try {
    let (ast, _) = @parser.parse_file(input_file)
    let source_content = @fs.read_file_to_string(input_file)
    let specs = parse_entities_from_ast(ast)
    let all_entity_specs = collect_package_entity_specs(input_file)
    let package_enum_specs = collect_package_enum_specs(input_file)
    let source_enum_specs = parse_enum_specs_from_source(source_content)
    let mapper_specs = parse_mappers_from_ast(
      ast, source_content, all_entity_specs,
    )
    //
    let codes : Array[String] = []
    source_enum_specs.each(enum_spec => {
      codes.push(render_enum_codec_impl(enum_spec))
    })
    specs.each(spec => {
      let table = transform_entity_to_table(
        spec, source_content, package_enum_specs,
      )
      let code = generate_entity_impl(spec, table, package_enum_specs)
      codes.push(code)
    })
    mapper_specs.each(ms => {
      let mcode = generate_mapper_code(ms, all_entity_specs, package_enum_specs)
      codes.push(mcode)
    })
    let code = codes.join("\n\n")
    @fs.write_string_to_file(output_file, code, encoding="utf8")
    let entity_names = specs.map(spec => spec.name)
    let mapper_names = mapper_specs.map(ms => ms.trait_name)
    if entity_names.length() > 0 {
      println("Generated \{output_file} for entities: \{entity_names}")
    }
    if mapper_names.length() > 0 {
      println("Generated \{output_file} for mappers: \{mapper_names}")
    }
  } catch {
    @fs.IOError(e) => println("IOError: \{e}")
  }
}
