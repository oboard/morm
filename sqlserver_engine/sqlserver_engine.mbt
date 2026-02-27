///|
pub struct SQLServerEngine {
  host : String
  port : Int
  user : String
  password : String
  database : String
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
fn parse_sqlserver_dsn(dsn : String) -> SQLServerEngine? {
  let raw = if dsn.strip_prefix("sqlserver://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let query = if raw.find("?") is Some(i) {
    raw[i + 1:].to_string() catch { _ => "" }
  } else {
    ""
  }

  let mut auth_host = main
  let mut database = "master"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string() catch { _ => main }
    database = main[i + 1:].to_string() catch { _ => "master" }
  }

  let mut user = "sa"
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

  let (host, port) = parse_host_port(host_port, 1433)
  let container = match query_param(query, "container") {
    Some(v) => v
    None => host
  }
  Some({ host, port, user, password, database, container })
}

///|
pub fn SQLServerEngine::open(dsn : String) -> Result[SQLServerEngine, String] {
  if parse_sqlserver_dsn(dsn) is Some(cfg) {
    Ok(cfg)
  } else {
    Err("invalid sqlserver dsn: " + dsn)
  }
}

///|
fn param_sql(p : @engine.Param) -> String {
  match p {
    @engine.Null => "NULL"
    @engine.Bool(v) => if v { "1" } else { "0" }
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
fn fail(message : String) -> @engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn shell_escape_single(text : String) -> String {
  text.replace(old="'", new="'\"'\"'")
}

///|
fn parse_table_output(stdout : String) -> FixedArray[Json] {
  let rows : Array[Json] = []
  let lines = stdout.split("\n").collect()
  for line in lines {
    let text = line.to_string().trim()
    if text == "" {
      continue
    }
    if text.contains("rows affected") ||
      text.contains("Changed database context") ||
      text.has_prefix("-") {
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
async fn run_sqlcmd(cfg : SQLServerEngine, sql : String) -> @engine.QueryResult {
  let script =
    "cat <<'SQL' | /opt/mssql-tools18/bin/sqlcmd -C -b -S localhost," +
    cfg.port.to_string() +
    " -U '" +
    shell_escape_single(cfg.user) +
    "' -P '" +
    shell_escape_single(cfg.password) +
    "' -d '" +
    shell_escape_single(cfg.database) +
    "' -h -1 -W -s '|'\n" +
    "SET NOCOUNT ON;\n" +
    sql +
    "\nSQL"

  let (code, out, err) = @process.collect_output("docker", [
    "exec",
    cfg.container,
    "bash",
    "-lc",
    script,
  ])
  if code != 0 {
    return fail("sqlserver exec failed: " + err.text())
  }
  let stderr = err.text().trim().to_string()
  if stderr != "" {
    return fail("sqlserver error: " + stderr)
  }
  let rows = parse_table_output(out.text())
  { ok: true, rows_affected: rows.length(), rows, error: None }
}

///|
pub async fn SQLServerEngine::ping(self : SQLServerEngine) -> Bool {
  run_sqlcmd(self, "SELECT 1").ok
}

///|
pub impl @engine.Engine for SQLServerEngine with render(_self, stmt : @engine.Statement) -> (
  String,
  FixedArray[@engine.Param],
) {
  @engine.render_default_sql(stmt)
}

///|
pub impl @engine.Engine for SQLServerEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let table : @morm.Table = @json.from_json(table_schema) catch {
    _ => return fail("invalid table schema")
  }
  let sql = table.to_create_sql(SqlServer)
  self.exec_raw(sql, [])
}

///|
pub impl @engine.Engine for SQLServerEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let query = inline_sql(sql, params)
  run_sqlcmd(self, query)
}

///|
pub impl @engine.Engine for SQLServerEngine with close(_self) -> Unit {
  ()
}
