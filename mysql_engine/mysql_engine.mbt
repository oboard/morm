///|
pub struct MySQLEngine {
  host : String
  port : Int
  user : String
  password : String
  database : String
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
fn parse_mysql_dsn(dsn : String) -> MySQLEngine? {
  let raw = if dsn.strip_prefix("mysql://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut database = ""
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string() catch { _ => main }
    database = main[i + 1:].to_string() catch { _ => "" }
  }

  let mut user = "root"
  let mut password = ""
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

  let (host, port) = parse_host_port(host_port, 3306)
  Some({ host, port, user, password, database })
}

///|
pub fn MySQLEngine::open(dsn : String) -> Result[MySQLEngine, String] {
  if parse_mysql_dsn(dsn) is Some(cfg) {
    Ok(cfg)
  } else {
    Err("invalid mysql dsn: " + dsn)
  }
}

///|
fn param_sql(p : @engine.Param) -> String {
  match p {
    @engine.Null => "NULL"
    @engine.Bool(v) => if v { "TRUE" } else { "FALSE" }
    @engine.Int(v) => v.to_string()
    @engine.Int64(v) => v.to_string()
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
async fn exec_tcp(cfg : MySQLEngine, payload : String) -> @engine.QueryResult {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ =>
      return {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("mysql connect failed"),
      }
  }
  defer conn.close()
  conn.write(payload) catch {
    _ =>
      return {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("mysql write failed"),
      }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub fn MySQLEngine::ping(self : MySQLEngine) -> Bool {
  let mut ok = false
  @async.run_async_main(() => {
    let res = exec_tcp(self, "/* ping */")
    ok = res.ok
  })
  ok
}

///|
pub impl @engine.Engine for MySQLEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  @engine.render_default_sql(stmt)
}

///|
pub impl @engine.Engine for MySQLEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let table : @morm.Table = @json.from_json(table_schema) catch {
    _ =>
      return {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("invalid table schema"),
      }
  }
  let sql = table.to_create_sql(MySQL)
  self.exec_raw(sql, [])
}

///|
pub impl @engine.Engine for MySQLEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let mut res : @engine.QueryResult = {
    ok: false,
    rows_affected: 0,
    rows: [],
    error: Some("async execution did not return"),
  }
  let query = inline_sql(sql, params)
  @async.run_async_main(() => res = exec_tcp(self, query))
  res
}

///|
pub impl @engine.Engine for MySQLEngine with close(_self) -> Unit {
  ()
}
