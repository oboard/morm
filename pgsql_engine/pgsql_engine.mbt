///|
pub struct PgSQLEngine {
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
fn parse_pg_dsn(dsn : String) -> PgSQLEngine? {
  let raw = if dsn.strip_prefix("postgres://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("postgresql://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut database = "postgres"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string() catch { _ => main }
    database = main[i + 1:].to_string() catch { _ => "postgres" }
  }

  let mut user = "postgres"
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

  let (host, port) = parse_host_port(host_port, 5432)
  Some({ host, port, user, password, database })
}

///|
pub fn PgSQLEngine::open(dsn : String) -> Result[PgSQLEngine, String] {
  if parse_pg_dsn(dsn) is Some(cfg) {
    Ok(cfg)
  } else {
    Err("invalid postgres dsn: " + dsn)
  }
}

///|
fn pg_render(stmt : @engine.Statement) -> (String, FixedArray[@engine.Param]) {
  let (sql, params) = @engine.render_default_sql(stmt)
  let out = @buffer.new()
  let mut index = 1
  for c in sql {
    if c == '?' {
      out.write_string("$")
      out.write_string(index.to_string())
      index = index + 1
    } else {
      out.write_char(c)
    }
  }
  (out.to_string(), params)
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
  let mut out = sql
  let mut i = 0
  while i < params.length() {
    let needle = "$" + (i + 1).to_string()
    out = out.replace(old=needle, new=param_sql(params[i]))
    i = i + 1
  }
  out
}

///|
async fn exec_tcp(cfg : PgSQLEngine, payload : String) -> @engine.QueryResult {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ =>
      return {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("pgsql connect failed"),
      }
  }
  defer conn.close()
  conn.write(payload) catch {
    _ =>
      return {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("pgsql write failed"),
      }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub fn PgSQLEngine::ping(self : PgSQLEngine) -> Bool {
  let mut ok = false
  @async.run_async_main(() => {
    let res = exec_tcp(self, "-- ping")
    ok = res.ok
  })
  ok
}

///|
pub impl @engine.Engine for PgSQLEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  pg_render(stmt)
}

///|
pub impl @engine.Engine for PgSQLEngine with migrate_table(
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
  let sql = table.to_create_sql(PgSQL)
  self.exec_raw(sql, [])
}

///|
pub impl @engine.Engine for PgSQLEngine with exec_raw(
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
pub impl @engine.Engine for PgSQLEngine with close(_self) -> Unit {
  ()
}
