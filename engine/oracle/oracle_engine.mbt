///|
pub struct OracleEngine {
  host : String
  port : Int
  user : String
  password : String
  service : String
}

///|
fn first_part(input : String, sep : String) -> String {
  let parts = input.split(sep).collect()
  if parts.length() > 0 {
    parts[0].to_owned()
  } else {
    input
  }
}

///|
fn parse_host_port(input : String, default_port : Int) -> (String, Int) {
  if input.find(":") is Some(i) {
    let host = input[:i].to_owned()
    let port_text = input[i + 1:].to_owned()
    let port = @string.parse_int(port_text) catch { _ => default_port }
    (if host == "" { "127.0.0.1" } else { host }, port)
  } else {
    (if input == "" { "127.0.0.1" } else { input }, default_port)
  }
}

///|
fn parse_oracle_dsn(dsn : String) -> OracleEngine? {
  let dsn = if dsn.strip_prefix("jdbc:") is Some(rest) {
    rest.to_owned()
  } else {
    dsn
  }
  let raw = if dsn.strip_prefix("oracle://") is Some(rest) {
    rest.to_owned()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut service = "XEPDB1"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_owned()
    service = main[i + 1:].to_owned()
  }

  let mut user = "system"
  let mut password = "oracle"
  let mut host_port = auth_host
  if auth_host.find("@") is Some(i) {
    let auth = auth_host[:i].to_owned()
    host_port = auth_host[i + 1:].to_owned()
    if auth.find(":") is Some(ci) {
      user = auth[:ci].to_owned()
      password = auth[ci + 1:].to_owned()
    } else if auth != "" {
      user = auth
    }
  }

  let (host, port) = parse_host_port(host_port, 1521)
  Some({ host, port, user, password, service })
}

///|
pub fn OracleEngine::open(dsn : String) -> Result[OracleEngine, String] {
  if parse_oracle_dsn(dsn) is Some(cfg) {
    Ok(cfg)
  } else {
    Err("invalid oracle dsn: " + dsn)
  }
}

///|
fn param_sql(p : @morm/engine.Param) -> String {
  let quote = fn(s : String) -> String {
    let esc = s.replace(old="'", new="''")
    "'\{esc}'"
  }
  match p {
    Null => "NULL"
    Bool(v) => if v { "1" } else { "0" }
    Byte(v) => v.to_int().to_string()
    Int(v) => v.to_string()
    Int16(v) => v.to_string()
    UInt16(v) => v.to_string()
    UInt(v) => v.to_string()
    UInt64(v) => v.to_string()
    Int64(v) => v.to_string()
    BigInt(v) => v.to_string()
    Float(v) => v.to_string()
    Double(v) => v.to_string()
    Decimal(v) => v
    Date(v, format) => quote(@morm/engine.format_plain_date(v, format))
    Time(v, format) => quote(@morm/engine.format_plain_time(v, format))
    DateTime(v, format) => quote(@morm/engine.format_plain_date_time(v, format))
    Timestamp(v, format) =>
      quote(@morm/engine.format_zoned_date_time(v, format))
    Uuid(v) => quote(v)
    Object(v) => quote(v.to_json().stringify())
    Json(v) => quote(v.stringify())
    String(v) => quote(v)
    Bytes(v) => "hextoraw('\{@morm/engine.bytes_to_hex(v)}')"
  }
}

///|
fn inline_sql(sql : String, params : FixedArray[@morm/engine.Param]) -> String {
  let out = StringBuilder()
  let mut i = 0
  for c in sql {
    if c == '?' && i < params.length() {
      out.write_string(param_sql(params[i]))
      i = i + 1
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn fail(message : String) -> @morm/engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn oracle_connect_descriptor(cfg : OracleEngine) -> String {
  "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" +
  cfg.host +
  ")(PORT=" +
  cfg.port.to_string() +
  "))(CONNECT_DATA=(SERVICE_NAME=" +
  cfg.service +
  ")))"
}

///|
async fn oracle_tns_handshake(cfg : OracleEngine) -> Bool {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ => return false
  }
  let connect_packet = build_tns_connect_packet(
    oracle_connect_descriptor(cfg),
    0x2000,
    0x2000,
    317,
    300,
  )
  conn.write(connect_packet) catch {
    _ => return false
  }
  let hdr = conn.read_exactly(8) catch { _ => return false }
  if hdr.length() < 8 {
    return false
  }
  // TNS packet type is byte #4 (0-based).
  let packet_type = hdr[4].to_int()
  packet_type is (2 | 4 | 5)
}

///|
pub async fn OracleEngine::ping(self : OracleEngine) -> Bool {
  oracle_tns_handshake(self)
}

///|
fn oracle_table_engine_option(
  table_schema : @table.Table,
  key : String,
  default : String,
) -> String {
  match table_schema.engine_options.get(key) {
    Some([value, ..]) => value
    _ => default
  }
}

///|
fn oracle_column_engine_option(
  column : @table.Column,
  key : String,
  default : String,
) -> String {
  match column.engine_options.get(key) {
    Some([value, ..]) => value
    _ => default
  }
}

///|
fn oracle_table_name(table_schema : @table.Table) -> String {
  let schema = table_schema.schema.unwrap_or("")
  if schema != "" {
    "\{schema}.\{table_schema.name}"
  } else {
    table_schema.name
  }
}

///|
fn oracle_type_from_column_type(column_type : @table.ColumnType) -> String {
  match column_type {
    TinyInt => "NUMBER(3)"
    SmallInt => "NUMBER(5)"
    MediumInt => "NUMBER(7)"
    Int => "NUMBER(10)"
    BigInt => "NUMBER(19)"
    Float => "BINARY_FLOAT"
    Double => "BINARY_DOUBLE"
    Decimal(a0, a1) => "NUMBER(\{a0}, \{a1})"
    Char(a0) => "CHAR(\{a0})"
    VarChar(a0) => "VARCHAR2(\{a0})"
    Text | MediumText | LongText => "CLOB"
    Binary(a0) | VarBinary(a0) => "RAW(\{a0})"
    Blob | MediumBlob | LongBlob => "BLOB"
    Date => "DATE"
    Time => "DATE"
    DateTime | Timestamp => "TIMESTAMP"
    Year => "NUMBER(4)"
    Json | JsonB => "CLOB"
    Enum(_, values) =>
      if values.length() == 0 {
        "VARCHAR2(255)"
      } else {
        let mut max_len = 1
        for value in values {
          if value.length() > max_len {
            max_len = value.length()
          }
        }
        "VARCHAR2(\{max_len})"
      }
    Boolean => "NUMBER(1)"
  }
}

///|
fn oracle_json_storage_type(column : @table.Column) -> String {
  match oracle_column_engine_option(column, "json.storage", "") {
    "blob" | "bson" | "jsonb" => "BLOB"
    "text" | "string" | "json" => "CLOB"
    _ => "CLOB"
  }
}

///|
fn oracle_pk_strategy_default(column : @table.Column) -> String? {
  if !column.primary_key || column.auto_increment {
    return None
  }
  match oracle_column_engine_option(column, "pk.strategy", "") {
    "uuid" => Some("SYS_GUID()")
    _ => None
  }
}

///|
fn oracle_column_default_expr(column : @table.Column) -> String? {
  if column.default_value is Some(v) {
    return Some(v)
  }
  oracle_pk_strategy_default(column)
}

///|
fn oracle_column_def(column : @table.Column) -> String {
  if column.name == "" {
    return ""
  }
  let col_type = match column.column_type {
    Json | JsonB => oracle_json_storage_type(column)
    _ => oracle_type_from_column_type(column.column_type)
  }
  let default_value = oracle_column_default_expr(column).unwrap_or("")
  let bool_default = if default_value.to_lower() == "true" {
    "1"
  } else if default_value.to_lower() == "false" {
    "0"
  } else {
    default_value
  }
  let buf = StringBuilder()
  buf.write_string(column.name)
  buf.write_string(" ")
  buf.write_string(col_type)
  if column.auto_increment {
    buf.write_string(" GENERATED BY DEFAULT AS IDENTITY")
  }
  if !column.nullable {
    buf.write_string(" NOT NULL")
  }
  if column.primary_key {
    buf.write_string(" PRIMARY KEY")
  }
  if column.unique {
    buf.write_string(" UNIQUE")
  }
  if bool_default != "" {
    buf.write_string(" DEFAULT ")
    buf.write_string(bool_default)
  }
  buf.to_string()
}

///|
fn oracle_fk_def(fk : @table.ForeignKey) -> String {
  if fk.column == "" || fk.referenced_table == "" || fk.referenced_column == "" {
    return ""
  }
  let mut sql = "FOREIGN KEY (\{fk.column}) REFERENCES \{fk.referenced_table}(\{fk.referenced_column})"
  if fk.name != "" {
    sql = "CONSTRAINT \{fk.name} " + sql
  }
  if fk.on_delete != "" {
    sql = sql + " ON DELETE " + fk.on_delete
  }
  if fk.on_update != "" {
    sql = sql + " ON UPDATE " + fk.on_update
  }
  sql
}

///|
fn oracle_create_table_sql(table_schema : @table.Table) -> String {
  if table_schema.name == "" {
    return ""
  }
  let table_name = oracle_table_name(table_schema)
  let defs : Array[String] = []
  for column in table_schema.columns {
    let def = oracle_column_def(column)
    if def != "" {
      defs.push(def)
    }
  }
  for fk in table_schema.foreign_keys {
    let def = oracle_fk_def(fk)
    if def != "" {
      defs.push(def)
    }
  }
  let defs_sql = defs.join(", ")
  let create_prefix = if table_schema.temporary {
    "CREATE GLOBAL TEMPORARY TABLE "
  } else {
    "CREATE TABLE "
  }
  let mut sql = "\{create_prefix}\{table_name} (\{defs_sql})"
  let tablespace = table_schema.tablespace.unwrap_or("")
  if tablespace != "" {
    sql = sql + " TABLESPACE " + tablespace
  }
  let organization = oracle_table_engine_option(
    table_schema, "oracle.organization", "",
  )
  if organization != "" {
    sql = sql + " ORGANIZATION " + organization
  }
  let on_commit = oracle_table_engine_option(
    table_schema, "oracle.on_commit", "",
  )
  if table_schema.temporary && on_commit != "" {
    sql = sql + " ON COMMIT " + on_commit
  }
  let create_suffix = oracle_table_engine_option(
    table_schema, "create_suffix", "",
  )
  if create_suffix != "" {
    sql = sql + " " + create_suffix
  }
  sql
}

///|
fn oracle_comment_sql(table_schema : @table.Table) -> String {
  if table_schema.comment == "" || table_schema.name == "" {
    return ""
  }
  let table_name = oracle_table_name(table_schema)
  "COMMENT ON TABLE \{table_name} IS '" +
  table_schema.comment.replace(old="'", new="''") +
  "'"
}

///|
fn oracle_index_sqls(table_schema : @table.Table) -> Array[String] {
  if table_schema.name == "" {
    return []
  }
  let table_name = oracle_table_name(table_schema)
  let sqls : Array[String] = []
  for idx in table_schema.indexes {
    if idx.name is ("" | "PRIMARY") || idx.columns.length() == 0 {
      continue
    }
    let unique = if idx.index_type == Unique { "UNIQUE " } else { "" }
    let cols_sql = idx.columns.join(", ")
    sqls.push(
      "CREATE \{unique}INDEX \{idx.name} ON \{table_name} (\{cols_sql})",
    )
  }
  sqls
}

///|
fn oracle_tx_sql(op : @morm/engine.TxOp) -> String {
  match op {
    // Oracle starts transaction implicitly on first DML.
    Begin => ""
    Commit => "COMMIT"
    Rollback => "ROLLBACK"
    Savepoint(name) => "SAVEPOINT " + name
    RollbackToSavepoint(name) => "ROLLBACK TO " + name
  }
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn exec(
  self,
  query : &@morm/engine.QueryBuilder,
) -> @morm/engine.QueryResult {
  let (sql, params) = match query.to_query() {
    Statement(stmt) => @morm/engine.render_default_sql(stmt)
    Raw(sql, params) => (sql, params)
    Tx(op) => (oracle_tx_sql(op), [])
  }
  if sql.trim() == "" {
    return { ok: true, rows_affected: 0, rows: [], error: None }
  }
  let _query = inline_sql(sql, params)
  if !oracle_tns_handshake(self) {
    return fail("oracle connect failed")
  }
  fail(
    "oracle native SQL execution is in progress; docker/sqlplus path removed",
  )
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn page(
  self,
  query : &@morm/engine.QueryBuilder,
  pageable : @morm/engine.Pageable,
) -> @morm/engine.QueryResult {
  let normalized_page = if pageable.page < 1 { 1 } else { pageable.page }
  let offset = (normalized_page - 1) * pageable.size
  let page_query = match query.to_query() {
    Statement(stmt) =>
      match stmt {
        Select(sel) => {
          let order_by = match pageable.sort {
            Some(s) =>
              sel.order_by +
              [
                match s.direction {
                  Asc => Asc(s.property)
                  Desc => Desc(s.property)
                },
              ]
            None => sel.order_by
          }
          @morm/engine.Statement(
            Select({
              ..sel,
              order_by,
              limit: Some(pageable.size),
              offset: Some(offset),
            }),
          )
        }
        _ => Statement(stmt)
      }
    Raw(sql, params) =>
      Raw(sql + " LIMIT \{pageable.size} OFFSET \{offset}", params)
    other => other
  }
  self.exec(page_query)
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn page_raw(
  self,
  sql : String,
  params : FixedArray[@morm/engine.Param],
  pageable : @morm/engine.Pageable,
) -> @morm/engine.QueryResult {
  self.page(@morm/engine.Raw(sql, params), pageable)
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn exec_raw(
  self,
  sql : String,
  params : FixedArray[@morm/engine.Param],
) -> @morm/engine.QueryResult {
  self.exec(@morm/engine.Raw(sql, params))
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn migrate_table(
  self,
  table_schema : @table.Table,
) -> @morm/engine.QueryResult {
  let create_sql = oracle_create_table_sql(table_schema)
  if create_sql == "" {
    return fail("invalid table schema")
  }
  let create_res = self.exec(@morm/engine.Raw(create_sql, []))
  if !create_res.ok {
    return create_res
  }
  let comment_sql = oracle_comment_sql(table_schema)
  if comment_sql != "" {
    let comment_res = self.exec(@morm/engine.Raw(comment_sql, []))
    if !comment_res.ok {
      return comment_res
    }
  }
  for sql in oracle_index_sqls(table_schema) {
    let res = self.exec(@morm/engine.Raw(sql, []))
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub impl @morm/engine.Engine for OracleEngine with fn close(_self) -> Unit {
  ()
}
