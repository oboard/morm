///|
pub struct OracleEngine {
  host : String
  port : Int
  user : String
  password : String
  service : String
  container : String
}

///|
fn first_part(input : String, sep : String) -> String {
  let parts = input.split(sep).collect()
  if parts.length() > 0 {
    parts[0].to_string()
  } else {
    input
  }
}

///|
fn parse_host_port(input : String, default_port : Int) -> (String, Int) {
  if input.find(":") is Some(i) {
    let host = input[:i].to_string() catch { _ => "127.0.0.1" }
    let port_text = input[i + 1:].to_string() catch { _ => "" }
    let port = @strconv.parse_int(port_text) catch { _ => default_port }
    (if host == "" { "127.0.0.1" } else { host }, port)
  } else {
    (if input == "" { "127.0.0.1" } else { input }, default_port)
  }
}

///|
fn query_param(input : String, key : String) -> String? {
  let parts = input.split("&").collect()
  for p in parts {
    let pair = p.to_string()
    if pair.find("=") is Some(i) {
      let k = pair[:i].to_string() catch { _ => "" }
      if k == key {
        return Some(pair[i + 1:].to_string() catch { _ => "" })
      }
    }
  }
  None
}

///|
fn parse_oracle_dsn(dsn : String) -> OracleEngine? {
  let raw = if dsn.strip_prefix("oracle://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let query = if raw.find("?") is Some(i) {
    raw[i + 1:].to_string() catch {
      _ => ""
    }
  } else {
    ""
  }

  let mut auth_host = main
  let mut service = "XEPDB1"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string() catch { _ => main }
    service = main[i + 1:].to_string() catch { _ => "XEPDB1" }
  }

  let mut user = "system"
  let mut password = "oracle"
  let mut host_port = auth_host
  if auth_host.find("@") is Some(i) {
    let auth = auth_host[:i].to_string() catch { _ => "" }
    host_port = auth_host[i + 1:].to_string() catch { _ => auth_host }
    if auth.find(":") is Some(ci) {
      user = auth[:ci].to_string() catch { _ => user }
      password = auth[ci + 1:].to_string() catch { _ => password }
    } else if auth != "" {
      user = auth
    }
  }

  let (host, port) = parse_host_port(host_port, 1521)
  let container = match query_param(query, "container") {
    Some(v) => v
    None => host
  }
  Some({ host, port, user, password, service, container })
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
fn param_sql(p : @engine.Param) -> String {
  match p {
    @engine.Null => "NULL"
    @engine.Bool(v) => if v { "1" } else { "0" }
    @engine.Byte(v) => v.to_int().to_string()
    @engine.Int(v) => v.to_string()
    @engine.Int16(v) => v.to_string()
    @engine.UInt16(v) => v.to_string()
    @engine.UInt(v) => v.to_string()
    @engine.UInt64(v) => v.to_string()
    @engine.Int64(v) => v.to_string()
    @engine.BigInt(v) => v.to_string()
    @engine.Float(v) => v.to_string()
    @engine.Double(v) => v.to_string()
    @engine.String(v) => "'" + v.replace(old="'", new="''") + "'"
    @engine.Bytes(_) => "NULL"
  }
}

///|
fn inline_sql(sql : String, params : FixedArray[@engine.Param]) -> String {
  let out = @buffer.new()
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
fn fail(message : String) -> @engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn shell_escape_single(text : String) -> String {
  text.replace(old="'", new="'\"'\"'")
}

///|
fn normalize_oracle_batch(sql : String) -> String {
  let stmts : Array[String] = []
  for part in sql.split(";").collect() {
    let stmt = part.to_string().trim().to_string()
    if stmt != "" {
      stmts.push(stmt)
    }
  }
  stmts.join(";\n")
}

///|
fn parse_oracle_output(stdout : String) -> FixedArray[Json] {
  let rows : Array[Json] = []
  let lines = stdout.split("\n").collect()
  for line in lines {
    let text = line.to_string().trim()
    if text == "" || text.has_prefix("SQL>") {
      continue
    }
    if text.has_prefix("ORA-") {
      continue
    }
    let cols = text.split("|").collect()
    let obj : Map[String, Json] = {}
    let mut i = 0
    for c in cols {
      let value = c.to_string().trim().to_string()
      obj["c" + i.to_string()] = Json::string(value)
      i = i + 1
    }
    rows.push(obj.to_json())
  }
  FixedArray::from_array(rows)
}

///|
async fn run_sqlplus(cfg : OracleEngine, sql : String) -> @engine.QueryResult {
  let conn = shell_escape_single(cfg.user) +
    "/" +
    shell_escape_single(cfg.password) +
    "@//localhost:" +
    cfg.port.to_string() +
    "/" +
    shell_escape_single(cfg.service)
  let batch = normalize_oracle_batch(sql)
  let command = "cat <<'SQL' | sqlplus -s '" +
    conn +
    "'\n" +
    "set heading off feedback off pagesize 0 verify off echo off trimspool on linesize 32767 colsep |\n" +
    batch +
    ";\n" +
    "exit\n" +
    "SQL"

  let (code, out, err) = @process.collect_output("docker", [
    "exec",
    cfg.container,
    "bash",
    "-lc",
    command,
  ])
  if code != 0 {
    return fail("oracle exec failed: " + err.text())
  }
  let stderr = err.text().trim().to_string()
  if stderr != "" {
    return fail("oracle error: " + stderr)
  }
  let text = out.text()
  if text.contains("ORA-") {
    return fail("oracle error: " + text)
  }
  let rows = parse_oracle_output(text)
  { ok: true, rows_affected: rows.length(), rows, error: None }
}

///|
pub async fn OracleEngine::ping(self : OracleEngine) -> Bool {
  run_sqlplus(self, "SELECT 1 FROM dual").ok
}

///|
fn schema_get_string(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String {
  match obj.get(key) {
    Some(String(v)) => v
    _ => default
  }
}

///|
fn schema_get_bool(
  obj : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
fn oracle_type_from_json(v : Json) -> String {
  let from_name = fn(name : String, arg0 : Int, arg1 : Int) -> String {
    match name {
      "TinyInt" => "NUMBER(3)"
      "SmallInt" => "NUMBER(5)"
      "MediumInt" => "NUMBER(7)"
      "Int" => "NUMBER(10)"
      "BigInt" => "NUMBER(19)"
      "Float" => "BINARY_FLOAT"
      "Double" => "BINARY_DOUBLE"
      "Decimal" => "NUMBER(\{arg0}, \{arg1})"
      "Char" => "CHAR(\{arg0})"
      "VarChar" => "VARCHAR2(\{arg0})"
      "Text" | "MediumText" | "LongText" => "CLOB"
      "Binary" | "VarBinary" => "RAW(\{arg0})"
      "Blob" | "MediumBlob" | "LongBlob" => "BLOB"
      "Date" => "DATE"
      "Time" => "DATE"
      "DateTime" | "Timestamp" => "TIMESTAMP"
      "Year" => "NUMBER(4)"
      "Json" | "JsonB" => "CLOB"
      "Boolean" => "NUMBER(1)"
      _ => "VARCHAR2(255)"
    }
  }
  match v {
    String(name) => from_name(name, 255, 2)
    Array(arr) =>
      if arr is [String(name), Number(a0, ..), Number(a1, ..), ..] {
        from_name(name, a0.to_int(), a1.to_int())
      } else if arr is [String(name), Number(a0, ..), ..] {
        from_name(name, a0.to_int(), 2)
      } else if arr is [String(name), ..] {
        from_name(name, 255, 2)
      } else {
        "VARCHAR2(255)"
      }
    _ => "VARCHAR2(255)"
  }
}

///|
fn oracle_column_def(col_json : Json) -> String {
  if col_json is Object(obj) {
    let name = schema_get_string(obj, "name", "")
    if name == "" {
      return ""
    }
    let col_type = match obj.get("column_type") {
      Some(v) => oracle_type_from_json(v)
      None => "VARCHAR2(255)"
    }
    let primary_key = schema_get_bool(obj, "primary_key", false)
    let auto_increment = schema_get_bool(obj, "auto_increment", false)
    let nullable = schema_get_bool(obj, "nullable", true)
    let unique = schema_get_bool(obj, "unique", false)
    let mut sql = "\{name} \{col_type}"
    if auto_increment {
      sql = sql + " GENERATED BY DEFAULT AS IDENTITY"
    }
    if !nullable {
      sql = sql + " NOT NULL"
    }
    if primary_key {
      sql = sql + " PRIMARY KEY"
    }
    if unique {
      sql = sql + " UNIQUE"
    }
    sql
  } else {
    ""
  }
}

///|
fn oracle_fk_def(fk_json : Json) -> String {
  if fk_json is Object(obj) {
    let name = schema_get_string(obj, "name", "")
    let col = schema_get_string(obj, "column", "")
    let ref_table = schema_get_string(obj, "referenced_table", "")
    let ref_col = schema_get_string(obj, "referenced_column", "")
    if col == "" || ref_table == "" || ref_col == "" {
      return ""
    }
    let mut sql = "FOREIGN KEY (\{col}) REFERENCES \{ref_table}(\{ref_col})"
    if name != "" {
      sql = "CONSTRAINT \{name} " + sql
    }
    let on_delete = schema_get_string(obj, "on_delete", "")
    let on_update = schema_get_string(obj, "on_update", "")
    if on_delete != "" {
      sql = sql + " ON DELETE " + on_delete
    }
    if on_update != "" {
      sql = sql + " ON UPDATE " + on_update
    }
    sql
  } else {
    ""
  }
}

///|
fn oracle_create_table_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let table_name = schema_get_string(obj, "name", "")
    if table_name == "" {
      return ""
    }
    let defs : Array[String] = []
    if obj.get("columns") is Some([.. v]) {
      for c in v {
        let d = oracle_column_def(c)
        if d != "" {
          defs.push(d)
        }
      }
    }
    if obj.get("foreign_keys") is Some([.. v]) {
      for fk in v {
        let d = oracle_fk_def(fk)
        if d != "" {
          defs.push(d)
        }
      }
    }
    let defs_sql = defs.join(", ")
    "CREATE TABLE \{table_name} (\{defs_sql})"
  } else {
    ""
  }
}

///|
fn oracle_index_sqls(table_schema : Json) -> Array[String] {
  if table_schema is Object(obj) {
    let table_name = schema_get_string(obj, "name", "")
    if table_name == "" {
      return []
    }
    let sqls : Array[String] = []
    if obj.get("indexes") is Some([.. v]) {
      for idx_json in v {
        if idx_json is Object(idx) {
          let idx_name = schema_get_string(idx, "name", "")
          if idx_name == "" || idx_name == "PRIMARY" {
            continue
          }
          let idx_type = schema_get_string(idx, "index_type", "Index")
          let cols : Array[String] = []
          if idx.get("columns") is Some([.. cols_json]) {
            for c in cols_json {
              if c is String(name) {
                cols.push(name)
              }
            }
          }
          if cols.length() == 0 {
            continue
          }
          let unique = if idx_type == "Unique" { "UNIQUE " } else { "" }
          let cols_sql = cols.join(", ")
          sqls.push(
            "CREATE \{unique}INDEX \{idx_name} ON \{table_name} (\{cols_sql})",
          )
        }
      }
    }
    sqls
  } else {
    []
  }
}

///|
pub impl @engine.Engine for OracleEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  @engine.render_default_sql(stmt)
}

///|
pub impl @engine.Engine for OracleEngine with tx_begin_sql(_self) -> String {
  // Oracle starts transaction implicitly on first DML.
  ""
}

///|
pub impl @engine.Engine for OracleEngine with tx_commit_sql(_self) -> String {
  "COMMIT"
}

///|
pub impl @engine.Engine for OracleEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK"
}

///|
pub impl @engine.Engine for OracleEngine with tx_savepoint_sql(
  _self,
  name : String,
) -> String {
  "SAVEPOINT " + name
}

///|
pub impl @engine.Engine for OracleEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TO " + name
}

///|
pub impl @engine.Engine for OracleEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let create_sql = oracle_create_table_sql(table_schema)
  if create_sql == "" {
    return fail("invalid table schema")
  }
  let create_res = self.exec_raw(create_sql, [])
  if !create_res.ok {
    return create_res
  }
  for sql in oracle_index_sqls(table_schema) {
    let res = self.exec_raw(sql, [])
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub impl @engine.Engine for OracleEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let query = inline_sql(sql, params)
  run_sqlplus(self, query)
}

///|
pub impl @engine.Engine for OracleEngine with close(_self) -> Unit {
  ()
}
