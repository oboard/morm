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
  let mut i = params.length() - 1
  while i >= 0 {
    let needle = "$" + (i + 1).to_string()
    out = out.replace(old=needle, new=param_sql(params[i]))
    i = i - 1
  }
  out
}

///|
fn fail(message : String) -> @engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn cstring(data : Bytes, start : Int) -> (String, Int)? {
  if start < 0 || start >= data.length() {
    return None
  }
  let mut i = start
  while i < data.length() && data[i] != 0 {
    i = i + 1
  }
  if i >= data.length() {
    return None
  }
  Some((@utf8.decode_lossy(data[start:i].to_bytes()), i + 1))
}

///|
fn pg_md5_password(user : String, password : String, salt : Bytes) -> String {
  let inner = @crypto.bytes_to_hex_string(
    @crypto.md5(@utf8.encode(password) + @utf8.encode(user)),
  )
  let outer = @crypto.bytes_to_hex_string(
    @crypto.md5(@utf8.encode(inner) + salt),
  )
  "md5" + outer
}

///|
fn parse_error_response(payload : Bytes) -> String {
  let mut i = 0
  let mut msg = ""
  while i < payload.length() {
    let tag = payload[i]
    if tag == 0 {
      break
    }
    if cstring(payload, i + 1) is Some((text, next)) {
      if tag == b'M' {
        msg = text
      }
      i = next
    } else {
      break
    }
  }
  if msg == "" {
    "pgsql error"
  } else {
    msg
  }
}

///|
fn json_from_text(text : String) -> Json {
  if text is ("t" | "true" | "TRUE") {
    return Json::boolean(true)
  }
  if text is ("f" | "false" | "FALSE") {
    return Json::boolean(false)
  }
  let i = @strconv.parse_int(text) catch { _ => -2147483648 }
  if i != -2147483648 || text == "-2147483648" {
    return Json::number(i.to_double())
  }
  let d = @strconv.parse_double(text) catch { _ => -9.999999999999999e307 }
  if d != -9.999999999999999e307 {
    return Json::number(d)
  }
  Json::string(text)
}

///|
fn parse_rows_affected(command_complete : String) -> Int {
  let parts = command_complete.split(" ").collect()
  if parts.length() == 0 {
    return 0
  }
  let last = parts[parts.length() - 1].to_string()
  @strconv.parse_int(last) catch {
    _ => 0
  }
}

///|
async fn read_message(conn : @socket.Tcp) -> (Byte, Bytes)? {
  let tag = conn.read_exactly(1) catch { _ => return None }
  let nbuf = conn.read_exactly(4) catch { _ => return None }
  let len = match nbuf {
    [u8be(b0), u8be(b1), u8be(b2), u8be(b3)] =>
      (b0.reinterpret_as_int() << 24) |
      (b1.reinterpret_as_int() << 16) |
      (b2.reinterpret_as_int() << 8) |
      b3.reinterpret_as_int()
    _ => return None
  }
  if len < 4 {
    return None
  }
  let payload = conn.read_exactly(len - 4) catch { _ => return None }
  Some((tag[0], payload))
}

///|
async fn write_tagged(conn : @socket.Tcp, tag : Byte, payload : Bytes) -> Bool {
  let h = @buffer.new()
  h.write_byte(tag)
  h.write_int_be(payload.length() + 4)
  conn.write(h.to_bytes()) catch {
    _ => return false
  }
  conn.write(payload) catch {
    _ => return false
  }
  true
}

///|
async fn send_startup(conn : @socket.Tcp, cfg : PgSQLEngine) -> Bool {
  let body = @buffer.new()
  body.write_int_be(196608) // protocol 3.0
  body.write_bytes(@utf8.encode("user"))
  body.write_byte(0)
  body.write_bytes(@utf8.encode(cfg.user))
  body.write_byte(0)
  body.write_bytes(@utf8.encode("database"))
  body.write_byte(0)
  body.write_bytes(@utf8.encode(cfg.database))
  body.write_byte(0)
  body.write_byte(0)
  let data = body.to_bytes()
  let len_buf = @buffer.new()
  len_buf.write_int_be(data.length() + 4)
  conn.write(len_buf.to_bytes()) catch {
    _ => return false
  }
  conn.write(data) catch {
    _ => return false
  }
  true
}

///|
async fn pg_query_async(cfg : PgSQLEngine, sql : String) -> @engine.QueryResult {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ => return fail("pgsql connect failed")
  }
  defer conn.close()

  if !(send_startup(conn, cfg) catch { _ => false }) {
    return fail("pgsql startup write failed")
  }

  let mut startup_done = false
  while !startup_done {
    let msg = read_message(conn) catch { _ => None }
    if msg is None {
      return fail("pgsql startup read failed")
    }
    let (tag, payload) = msg.unwrap()
    if tag == b'R' {
      if payload.length() < 4 {
        return fail("pgsql bad auth message")
      }
      let kind = match payload[:4] {
        [u8be(b0), u8be(b1), u8be(b2), u8be(b3)] =>
          (b0.reinterpret_as_int() << 24) |
          (b1.reinterpret_as_int() << 16) |
          (b2.reinterpret_as_int() << 8) |
          b3.reinterpret_as_int()
        _ => return fail("pgsql bad auth message")
      }
      if kind == 0 {
        ()
      } else if kind == 3 {
        let p = @buffer.new()
        p.write_bytes(@utf8.encode(cfg.password))
        p.write_byte(0)
        if !(write_tagged(conn, b'p', p.to_bytes()) catch { _ => false }) {
          return fail("pgsql cleartext auth write failed")
        }
      } else if kind == 5 {
        if payload.length() < 8 {
          return fail("pgsql bad md5 auth payload")
        }
        let salt = payload[4:8].to_bytes()
        let md5_pass = pg_md5_password(cfg.user, cfg.password, salt)
        let p = @buffer.new()
        p.write_bytes(@utf8.encode(md5_pass))
        p.write_byte(0)
        if !(write_tagged(conn, b'p', p.to_bytes()) catch { _ => false }) {
          return fail("pgsql md5 auth write failed")
        }
      } else {
        return fail("unsupported pg auth kind: " + kind.to_string())
      }
    } else if tag == b'E' {
      return fail(parse_error_response(payload))
    } else if tag == b'Z' {
      startup_done = true
    } else {
      ()
    }
  }

  let q = @buffer.new()
  q.write_bytes(@utf8.encode(sql))
  q.write_byte(0)
  if !(write_tagged(conn, b'Q', q.to_bytes()) catch { _ => false }) {
    return fail("pgsql query write failed")
  }

  let cols : Array[String] = []
  let rows : Array[Json] = []
  let mut rows_affected = 0
  let mut done = false

  while !done {
    let msg = read_message(conn) catch { _ => None }
    if msg is None {
      return fail("pgsql query read failed")
    }
    let (tag, payload) = msg.unwrap()
    if tag == b'T' {
      if payload.length() < 2 {
        return fail("pgsql bad row-description")
      }
      cols.clear()
      let count = match payload[:2] {
        [u8be(b0), u8be(b1)] =>
          (b0.reinterpret_as_int() << 8) | b1.reinterpret_as_int()
        _ => return fail("pgsql bad row-description")
      }
      let mut pos = 2
      let mut i = 0
      while i < count {
        if cstring(payload, pos) is Some((name, next)) {
          cols.push(name)
          pos = next + 18
          if pos > payload.length() {
            return fail("pgsql truncated row-description")
          }
        } else {
          return fail("pgsql bad column name")
        }
        i = i + 1
      }
    } else if tag == b'D' {
      if payload.length() < 2 {
        return fail("pgsql bad data-row")
      }
      let count = match payload[:2] {
        [u8be(b0), u8be(b1)] =>
          (b0.reinterpret_as_int() << 8) | b1.reinterpret_as_int()
        _ => return fail("pgsql bad data-row")
      }
      let obj : Map[String, Json] = {}
      let mut pos = 2
      let mut i = 0
      while i < count {
        if pos + 4 > payload.length() {
          return fail("pgsql truncated data-row")
        }
        let len = match payload[pos:pos + 4] {
          [u8be(b0), u8be(b1), u8be(b2), u8be(b3)] =>
            (b0.reinterpret_as_int() << 24) |
            (b1.reinterpret_as_int() << 16) |
            (b2.reinterpret_as_int() << 8) |
            b3.reinterpret_as_int()
          _ => return fail("pgsql truncated data-row")
        }
        pos = pos + 4
        let key = if i < cols.length() { cols[i] } else { "c" + i.to_string() }
        if len < 0 {
          obj[key] = Json::null()
        } else {
          if pos + len > payload.length() {
            return fail("pgsql truncated data value")
          }
          let text = @utf8.decode_lossy(payload[pos:pos + len].to_bytes())
          obj[key] = json_from_text(text)
          pos = pos + len
        }
        i = i + 1
      }
      rows.push(obj.to_json())
    } else if tag == b'C' {
      if cstring(payload, 0) is Some((cmd, _)) {
        rows_affected = parse_rows_affected(cmd)
      }
    } else if tag == b'E' {
      return fail(parse_error_response(payload))
    } else if tag == b'Z' {
      done = true
    } else {
      ()
    }
  }

  { ok: true, rows_affected, rows: FixedArray::from_array(rows), error: None }
}

///|
pub async fn PgSQLEngine::ping(self : PgSQLEngine) -> Bool {
  let res_opt = @async.with_timeout_opt(5000, () => {
    pg_query_async(self, "SELECT 1")
  })
  match res_opt {
    Some(res) => res.ok
    None => false
  }
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
  let query = inline_sql(sql, params)
  let res_opt = @async.with_timeout_opt(5000, () => pg_query_async(self, query))
  match res_opt {
    Some(v) => v
    None =>
      {
        ok: false,
        rows_affected: 0,
        rows: [],
        error: Some("pgsql query timeout"),
      }
  }
}

///|
pub impl @engine.Engine for PgSQLEngine with close(_self) -> Unit {
  ()
}
