///|
pub struct SQLServerEngine {
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
fn parse_sqlserver_dsn(dsn : String) -> SQLServerEngine? {
  let dsn = if dsn.strip_prefix("jdbc:") is Some(rest) {
    rest.to_string()
  } else {
    dsn
  }
  let raw = if dsn.strip_prefix("sqlserver://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("mssql://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("jtds:sqlserver://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
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
  Some({ host, port, user, password, database })
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
fn fail(message : String) -> @engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn param_sql(p : @engine.Param) -> String {
  let quote = fn(s : String) -> String {
    let esc = s.replace(old="'", new="''")
    "'\{esc}'"
  }
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
    @engine.Decimal(v) => v
    @engine.Date(v) => quote(v.to_string())
    @engine.Time(v) => quote(v.to_string())
    @engine.DateTime(v) => quote(v.to_string())
    @engine.Timestamp(v) => quote(v.to_string())
    @engine.Uuid(v) => quote(v)
    @engine.Json(v) => quote(v.stringify())
    @engine.String(v) => quote(v)
    @engine.Bytes(v) => "0x\{@engine.bytes_to_hex(v)}"
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
fn split_go_batches(sql : String) -> Array[String] {
  let batches : Array[String] = []
  let mut curr = ""
  for line in sql.split("\n").collect() {
    let s = line.to_string()
    if s.trim() is ("GO" | "go" | "Go" | "gO") {
      if curr.trim() != "" {
        batches.push(curr)
      }
      curr = ""
    } else if curr == "" {
      curr = s
    } else {
      curr = curr + "\n" + s
    }
  }
  if curr.trim() != "" {
    batches.push(curr)
  }
  if batches.length() == 0 {
    batches.push(sql)
  }
  batches
}

///|
fn utf16le_bytes(text : String) -> Bytes {
  let b = @buffer.new()
  for c in text {
    b.write_char_utf16le(c)
  }
  b.to_bytes()
}

///|
fn mangle_password(password : String) -> Bytes {
  let b = @buffer.new()
  for x in utf16le_bytes(password) {
    let v = x.to_int()
    let y = (((v << 4) & 0xff) | ((v >> 4) & 0xff)) ^ 0xA5
    b.write_byte(y.to_byte())
  }
  b.to_bytes()
}

///|
fn read_u16_le_at(buf : Bytes, i : Int) -> Int {
  match buf[i:i + 2] {
    [u16le(v)] => v.reinterpret_as_int()
    _ => 0
  }
}

///|
fn read_u32_le_at(buf : Bytes, i : Int) -> Int {
  match buf[i:i + 4] {
    [u32le(v)] => v.reinterpret_as_int()
    _ => 0
  }
}

///|
fn read_u16_be_at(buf : Bytes, i : Int) -> Int {
  match buf[i:i + 2] {
    [u16be(v)] => v.reinterpret_as_int()
    _ => 0
  }
}

///|
async fn[IO : @io.Writer] write_tds_message(
  conn : IO,
  packet_type : Int,
  payload : Bytes,
  packet_size : Int,
) -> Bool {
  let mut seq = 1
  let mut pos = 0
  while pos < payload.length() {
    let remain = payload.length() - pos
    let max_payload = packet_size - 8
    let chunk_len = if remain > max_payload { max_payload } else { remain }
    let is_last = pos + chunk_len >= payload.length()

    let hdr = @buffer.new()
    hdr.write_byte(packet_type.to_byte())
    hdr.write_byte((if is_last { 1 } else { 0 }).to_byte())
    hdr.write_uint16_be((chunk_len + 8).reinterpret_as_uint().to_uint16())
    hdr.write_uint16_be(0)
    hdr.write_byte((seq & 0xff).to_byte())
    hdr.write_byte(0)

    conn.write(hdr.to_bytes()) catch {
      _ => return false
    }
    conn.write(payload[pos:pos + chunk_len].to_bytes()) catch {
      _ => return false
    }

    pos = pos + chunk_len
    seq = seq + 1
  }
  true
}

///|
async fn[IO : @io.Reader] read_tds_message(conn : IO) -> (Int, Bytes)? {
  let out = @buffer.new()
  let mut packet_type = -1
  let mut done = false
  while !done {
    let hdr = conn.read_exactly(8) catch { _ => return None }
    if hdr.length() != 8 {
      return None
    }
    packet_type = hdr[0].to_int()
    let status = hdr[1].to_int()
    let size = read_u16_be_at(hdr, 2)
    if size < 8 {
      return None
    }
    let body = conn.read_exactly(size - 8) catch { _ => return None }
    out.write_bytes(body)
    if (status & 0x01) != 0 {
      done = true
    }
  }
  Some((packet_type, out.to_bytes()))
}

///|
fn prelogin_payload() -> Bytes {
  let types : Array[Int] = [0, 1, 2, 3, 4]
  let data : Array[Bytes] = [
    b"\x00\x00\x00\x00\x00\x00", b"\x02", b"\x00", b"\x00\x00\x00\x00", b"\x00",
  ]
  let b = @buffer.new()
  let offset_base = data.length() * 5 + 1
  let mut offset = offset_base
  let mut i = 0
  while i < data.length() {
    let v = data[i]
    b.write_byte(types[i].to_byte())
    b.write_uint16_be(offset.reinterpret_as_uint().to_uint16())
    b.write_uint16_be(v.length().reinterpret_as_uint().to_uint16())
    offset = offset + v.length()
    i = i + 1
  }
  b.write_byte(0xff)
  i = 0
  while i < data.length() {
    let v = data[i]
    b.write_bytes(v)
    i = i + 1
  }
  b.to_bytes()
}

///|
fn parse_prelogin_encryption(data : Bytes) -> Int {
  let mut i = 0
  while i + 5 <= data.length() {
    let typ = data[i].to_int()
    if typ == 0xff {
      break
    }
    let off = read_u16_be_at(data, i + 1)
    let len = read_u16_be_at(data, i + 3)
    if typ == 1 && off + len <= data.length() && len >= 1 {
      return data[off].to_int()
    }
    i = i + 5
  }
  2
}

///|
fn login7_payload(cfg : SQLServerEngine, packet_size : Int) -> Bytes {
  let host = utf16le_bytes("moonbit")
  let user = utf16le_bytes(cfg.user)
  let pass = mangle_password(cfg.password)
  let app = utf16le_bytes("morm")
  let server = utf16le_bytes(cfg.host)
  let ctl = utf16le_bytes("")
  let lang = utf16le_bytes("")
  let db = utf16le_bytes(cfg.database)
  let sspi = b""
  let atch = b""
  let chgp = b""

  let hdr_len = 94
  let mut off = hdr_len

  let host_off = off
  off = off + host.length()
  let user_off = off
  off = off + user.length()
  let pass_off = off
  off = off + pass.length()
  let app_off = off
  off = off + app.length()
  let server_off = off
  off = off + server.length()
  let ctl_off = off
  off = off + ctl.length()
  let lang_off = off
  off = off + lang.length()
  let db_off = off
  off = off + db.length()
  let sspi_off = off
  off = off + sspi.length()
  let atch_off = off
  off = off + atch.length()
  let chgp_off = off
  off = off + chgp.length()

  let b = @buffer.new()
  b.write_uint_le(off.reinterpret_as_uint())
  b.write_uint_le(0x71000001)
  b.write_uint_le(packet_size.reinterpret_as_uint())
  b.write_uint_le(0)
  b.write_uint_le(0)
  b.write_uint_le(0)
  b.write_byte(0xA0) // fUseDB | fSetLang
  b.write_byte(0x02) // fODBC
  b.write_byte(0x00)
  b.write_byte(0x00)
  b.write_uint_le(0)
  b.write_uint_le(0x0409)

  let write_off_len = fn(off : Int, bytes_len : Int) {
    b.write_uint16_le(off.reinterpret_as_uint().to_uint16())
    b.write_uint16_le((bytes_len / 2).reinterpret_as_uint().to_uint16())
  }

  write_off_len(host_off, host.length())
  write_off_len(user_off, user.length())
  write_off_len(pass_off, pass.length())
  write_off_len(app_off, app.length())
  write_off_len(server_off, server.length())
  b.write_uint16_le(0)
  b.write_uint16_le(0)
  write_off_len(ctl_off, ctl.length())
  write_off_len(lang_off, lang.length())
  write_off_len(db_off, db.length())

  let mut i = 0
  while i < 6 {
    b.write_byte(0)
    i = i + 1
  }

  b.write_uint16_le(sspi_off.reinterpret_as_uint().to_uint16())
  b.write_uint16_le(sspi.length().reinterpret_as_uint().to_uint16())
  write_off_len(atch_off, atch.length())
  write_off_len(chgp_off, chgp.length())
  b.write_uint_le(0)

  b.write_bytes(host)
  b.write_bytes(user)
  b.write_bytes(pass)
  b.write_bytes(app)
  b.write_bytes(server)
  b.write_bytes(ctl)
  b.write_bytes(lang)
  b.write_bytes(db)
  b.write_bytes(sspi)
  b.write_bytes(atch)
  b.write_bytes(chgp)
  b.to_bytes()
}

///|
fn parse_tds_reply(data : Bytes) -> (Bool, String, Int) {
  let mut pos = 0
  let mut error_msg = ""
  let mut rows = 0
  while pos < data.length() {
    let tok = data[pos].to_int()
    pos = pos + 1
    match tok {
      0x00 => ()
      0xAD => {
        if pos + 2 > data.length() {
          return (false, "bad loginack", rows)
        }
        let n = read_u16_le_at(data, pos)
        pos = pos + 2 + n
      }
      0xE3 => {
        if pos + 2 > data.length() {
          return (false, "bad envchange", rows)
        }
        let n = read_u16_le_at(data, pos)
        pos = pos + 2 + n
      }
      0xAA => {
        if pos + 2 > data.length() {
          return (false, "bad error token", rows)
        }
        let n = read_u16_le_at(data, pos)
        if pos + 2 + n > data.length() {
          return (false, "bad error token", rows)
        }
        let body = data[pos + 2:pos + 2 + n].to_bytes()
        if body.length() >= 8 {
          let mlen = read_u16_le_at(body, 6)
          let start = 8
          let byte_len = mlen * 2
          if start + byte_len <= body.length() {
            let m = @buffer.new()
            let mut i = 0
            while i < mlen {
              m.write_byte(body[start + i * 2])
              i = i + 1
            }
            error_msg = m.to_bytes().to_string()
          }
        }
        pos = pos + 2 + n
      }
      0xAB => {
        if pos + 2 > data.length() {
          return (false, "bad info token", rows)
        }
        let n = read_u16_le_at(data, pos)
        pos = pos + 2 + n
      }
      0xFD | 0xFE | 0xFF => {
        let remain = data.length() - pos
        if remain >= 12 {
          let status = read_u16_le_at(data, pos)
          let row_count = read_u32_le_at(data, pos + 8)
          if (status & 0x10) != 0 && row_count > 0 {
            rows = rows + row_count
          }
          pos = pos + 12
        } else if remain >= 8 {
          let status = read_u16_le_at(data, pos)
          let row_count = read_u32_le_at(data, pos + 4)
          if (status & 0x10) != 0 && row_count > 0 {
            rows = rows + row_count
          }
          pos = pos + 8
        } else {
          return (false, "bad done token", rows)
        }
      }
      0x81 => {
        // COLMETADATA: for now only skip when count == 0xFFFF
        if pos + 2 > data.length() {
          return (false, "bad colmetadata", rows)
        }
        let count = read_u16_le_at(data, pos)
        pos = pos + 2
        if count != 0xFFFF {
          return (false, "result-set decoding is not implemented yet", rows)
        }
      }
      0x79 => {
        if pos + 4 > data.length() {
          return (false, "bad return status", rows)
        }
        pos = pos + 4
      }
      0xD1 | 0xD2 => return (false, "row decoding is not implemented yet", rows)
      _ => return (false, "unknown token: " + tok.to_string(), rows)
    }
    if pos > data.length() {
      return (false, "bad reply payload", rows)
    }
  }
  if error_msg != "" {
    (false, error_msg, rows)
  } else {
    (true, "", rows)
  }
}

///|
async fn[IO : @io.Reader + @io.Writer] sqlbatch(
  conn : IO,
  sql : String,
  packet_size : Int,
) -> @engine.QueryResult {
  let payload = utf16le_bytes(sql)
  if !(write_tds_message(conn, 1, payload, packet_size) catch { _ => false }) {
    return fail("sqlserver batch write failed")
  }
  let reply = read_tds_message(conn) catch { _ => None }
  if reply is None {
    return fail("sqlserver batch read failed")
  }
  let (pt, body) = reply.unwrap()
  if pt != 4 {
    return fail("sqlserver invalid reply packet")
  }
  let (ok, err, rows) = parse_tds_reply(body)
  if !ok {
    return fail(if err == "" { "sqlserver batch failed" } else { err })
  }
  { ok: true, rows_affected: rows, rows: [], error: None }
}

///|
async fn tds_exec(cfg : SQLServerEngine, sql : String) -> @engine.QueryResult {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ => return fail("sqlserver connect failed")
  }
  defer conn.close()

  let packet_size = 4096

  if !(write_tds_message(conn, 18, prelogin_payload(), packet_size) catch {
      _ => false
    }) {
    return fail("sqlserver prelogin write failed")
  }
  let pre = read_tds_message(conn) catch { _ => None }
  if pre is None {
    return fail("sqlserver prelogin read failed")
  }
  let (pt0, body0) = pre.unwrap()
  if pt0 != 4 {
    return fail("sqlserver invalid prelogin response")
  }
  let enc = parse_prelogin_encryption(body0)
  if enc == 2 {
    if !(write_tds_message(
        conn,
        16,
        login7_payload(cfg, packet_size),
        packet_size,
      ) catch {
        _ => false
      }) {
      return fail("sqlserver login write failed")
    }
    let login_resp = read_tds_message(conn) catch { _ => None }
    if login_resp is None {
      return fail("sqlserver login read failed")
    }
    let (pt1, body1) = login_resp.unwrap()
    if pt1 != 4 {
      return fail("sqlserver invalid login reply")
    }
    let (ok_login, err_login, _) = parse_tds_reply(body1)
    if !ok_login {
      return fail(
        if err_login == "" {
          "sqlserver login failed"
        } else {
          err_login
        },
      )
    }

    let mut final_res : @engine.QueryResult = {
      ok: true,
      rows_affected: 0,
      rows: [],
      error: None,
    }
    for batch in split_go_batches(sql) {
      let stmt = batch.trim().to_string()
      if stmt == "" {
        continue
      }
      let res = sqlbatch(conn, stmt, packet_size) catch {
        _ => fail("sqlserver batch execute failed")
      }
      if !res.ok {
        return res
      }
      final_res = {
        ok: true,
        rows_affected: final_res.rows_affected + res.rows_affected,
        rows: [],
        error: None,
      }
    }
    final_res
  } else {
    let tls_conn = @tls.Tls::client(conn, verify=false, host=cfg.host) catch {
      _ => return fail("sqlserver tls handshake failed")
    }
    defer tls_conn.close()

    if !(write_tds_message(
        tls_conn,
        16,
        login7_payload(cfg, packet_size),
        packet_size,
      ) catch {
        _ => false
      }) {
      return fail("sqlserver login write failed")
    }
    let login_resp = read_tds_message(tls_conn) catch { _ => None }
    if login_resp is None {
      return fail("sqlserver login read failed")
    }
    let (pt1, body1) = login_resp.unwrap()
    if pt1 != 4 {
      return fail("sqlserver invalid login reply")
    }
    let (ok_login, err_login, _) = parse_tds_reply(body1)
    if !ok_login {
      return fail(
        if err_login == "" {
          "sqlserver login failed"
        } else {
          err_login
        },
      )
    }

    let mut final_res : @engine.QueryResult = {
      ok: true,
      rows_affected: 0,
      rows: [],
      error: None,
    }
    for batch in split_go_batches(sql) {
      let stmt = batch.trim().to_string()
      if stmt == "" {
        continue
      }
      let res = sqlbatch(tls_conn, stmt, packet_size) catch {
        _ => fail("sqlserver batch execute failed")
      }
      if !res.ok {
        return res
      }
      final_res = {
        ok: true,
        rows_affected: final_res.rows_affected + res.rows_affected,
        rows: [],
        error: None,
      }
    }
    final_res
  }
}

///|
pub async fn SQLServerEngine::ping(self : SQLServerEngine) -> Bool {
  tds_exec(self, "BEGIN TRAN; ROLLBACK").ok
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
fn schema_get_engine_option(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String {
  match obj.get("engine_options") {
    Some([.. options]) => {
      for option in options {
        if option is Object(option_obj) &&
          schema_get_string(option_obj, "key", "") == key {
          return schema_get_string(option_obj, "value", default)
        }
      }
      default
    }
    _ => default
  }
}

///|
fn schema_has_engine_option_true(obj : Map[String, Json], key : String) -> Bool {
  schema_get_engine_option(obj, key, "") == "true"
}

///|
fn sqlserver_table_name(obj : Map[String, Json], name : String) -> String {
  if schema_get_bool(obj, "temporary", false) {
    if name.strip_prefix("#") is Some(_) {
      name
    } else {
      "#" + name
    }
  } else {
    let schema = schema_get_string(obj, "schema", "")
    let catalog = schema_get_string(obj, "catalog", "")
    if catalog != "" && schema != "" {
      "\{catalog}.\{schema}.\{name}"
    } else if schema != "" {
      "\{schema}.\{name}"
    } else if catalog != "" {
      "\{catalog}.\{name}"
    } else {
      name
    }
  }
}

///|
fn sqlserver_type_from_json(v : Json) -> String {
  let from_name = fn(name : String, arg0 : Int, arg1 : Int) -> String {
    match name {
      "TinyInt" => "TINYINT"
      "SmallInt" => "SMALLINT"
      "MediumInt" | "Int" => "INT"
      "BigInt" => "BIGINT"
      "Float" => "REAL"
      "Double" => "FLOAT"
      "Decimal" => "DECIMAL(\{arg0}, \{arg1})"
      "Char" => "NCHAR(\{arg0})"
      "VarChar" => "NVARCHAR(\{arg0})"
      "Text" | "MediumText" | "LongText" => "NVARCHAR(MAX)"
      "Binary" => "BINARY(\{arg0})"
      "VarBinary" | "Blob" | "MediumBlob" | "LongBlob" => "VARBINARY(MAX)"
      "Date" => "DATE"
      "Time" => "TIME"
      "DateTime" | "Timestamp" => "DATETIME2"
      "Year" => "INT"
      "Json" | "JsonB" => "NVARCHAR(MAX)"
      "Boolean" => "BIT"
      _ => "NVARCHAR(MAX)"
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
        "NVARCHAR(MAX)"
      }
    _ => "NVARCHAR(MAX)"
  }
}

///|
fn sqlserver_json_storage_type(obj : Map[String, Json]) -> String {
  match schema_get_engine_option(obj, "json.storage", "") {
    "blob" | "bson" | "jsonb" => "VARBINARY(MAX)"
    "text" | "string" | "json" => "NVARCHAR(MAX)"
    _ => "NVARCHAR(MAX)"
  }
}

///|
fn sqlserver_column_def(col_json : Json) -> String {
  if col_json is Object(obj) {
    let name = schema_get_string(obj, "name", "")
    if name == "" {
      return ""
    }
    let col_type = match obj.get("column_type") {
      Some(String("Json")) | Some(String("JsonB")) =>
        sqlserver_json_storage_type(obj)
      Some(v) => sqlserver_type_from_json(v)
      None => "NVARCHAR(MAX)"
    }
    let primary_key = schema_get_bool(obj, "primary_key", false)
    let auto_increment = schema_get_bool(obj, "auto_increment", false)
    let nullable = schema_get_bool(obj, "nullable", true)
    let unique = schema_get_bool(obj, "unique", false)
    let mut sql = "\{name} \{col_type}"
    if auto_increment {
      sql = sql + " IDENTITY(1,1)"
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
fn sqlserver_fk_def(fk_json : Json) -> String {
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
fn sqlserver_create_table_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let base_name = schema_get_string(obj, "name", "")
    if base_name == "" {
      return ""
    }
    let table_name = sqlserver_table_name(obj, base_name)
    let defs : Array[String] = []
    if obj.get("columns") is Some([.. v]) {
      for c in v {
        let d = sqlserver_column_def(c)
        if d != "" {
          defs.push(d)
        }
      }
    }
    if obj.get("foreign_keys") is Some([.. v]) {
      for fk in v {
        let d = sqlserver_fk_def(fk)
        if d != "" {
          defs.push(d)
        }
      }
    }
    let defs_sql = defs.join(", ")
    let if_not_exists = schema_get_bool(obj, "if_not_exists", true)
    let mut sql = if if_not_exists {
      "IF OBJECT_ID('\{table_name}', 'U') IS NULL CREATE TABLE \{table_name} (\{defs_sql})"
    } else {
      "CREATE TABLE \{table_name} (\{defs_sql})"
    }
    let with_options : Array[String] = []
    if schema_has_engine_option_true(obj, "sqlserver.memory_optimized") {
      with_options.push("MEMORY_OPTIMIZED = ON")
    }
    let durability = schema_get_engine_option(obj, "sqlserver.durability", "")
    if durability != "" {
      with_options.push("DURABILITY = " + durability)
    }
    if with_options.length() > 0 {
      sql = sql + " WITH (" + with_options.join(", ") + ")"
    }
    let filegroup = schema_get_engine_option(obj, "sqlserver.filegroup", "")
    if filegroup != "" {
      sql = sql + " ON " + filegroup
    }
    let textimage_on = schema_get_engine_option(
      obj, "sqlserver.textimage_on", "",
    )
    if textimage_on != "" {
      sql = sql + " TEXTIMAGE_ON " + textimage_on
    }
    let create_suffix = schema_get_engine_option(obj, "create_suffix", "")
    if create_suffix != "" {
      sql = sql + " " + create_suffix
    }
    sql
  } else {
    ""
  }
}

///|
fn sqlserver_comment_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let comment = schema_get_string(obj, "comment", "")
    let table_name = schema_get_string(obj, "name", "")
    if comment == "" ||
      table_name == "" ||
      schema_get_bool(obj, "temporary", false) {
      return ""
    }
    let schema_name = schema_get_string(obj, "schema", "dbo")
    let escaped_comment = comment.replace(old="'", new="''")
    let escaped_schema = schema_name.replace(old="'", new="''")
    let escaped_table = table_name.replace(old="'", new="''")
    "IF EXISTS (SELECT 1 FROM fn_listextendedproperty (" +
    "N'MS_Description', N'SCHEMA', N'" +
    escaped_schema +
    "', N'TABLE', N'" +
    escaped_table +
    "', NULL, NULL)) " +
    "EXEC sys.sp_updateextendedproperty @name=N'MS_Description', @value=N'" +
    escaped_comment +
    "', @level0type=N'SCHEMA', @level0name=N'" +
    escaped_schema +
    "', @level1type=N'TABLE', @level1name=N'" +
    escaped_table +
    "' ELSE EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'" +
    escaped_comment +
    "', @level0type=N'SCHEMA', @level0name=N'" +
    escaped_schema +
    "', @level1type=N'TABLE', @level1name=N'" +
    escaped_table +
    "'"
  } else {
    ""
  }
}

///|
fn sqlserver_index_sqls(table_schema : Json) -> Array[String] {
  if table_schema is Object(obj) {
    let base_name = schema_get_string(obj, "name", "")
    if base_name == "" {
      return []
    }
    let table_name = sqlserver_table_name(obj, base_name)
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
            "IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '\{idx_name}') CREATE \{unique}INDEX \{idx_name} ON \{table_name} (\{cols_sql})",
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
pub impl @engine.Engine for SQLServerEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  @engine.render_default_sql(stmt)
}

///|
pub impl @engine.Engine for SQLServerEngine with tx_begin_sql(_self) -> String {
  "BEGIN TRANSACTION"
}

///|
pub impl @engine.Engine for SQLServerEngine with tx_commit_sql(_self) -> String {
  "COMMIT TRANSACTION"
}

///|
pub impl @engine.Engine for SQLServerEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK TRANSACTION"
}

///|
pub impl @engine.Engine for SQLServerEngine with tx_savepoint_sql(
  _self,
  name : String,
) -> String {
  "SAVE TRANSACTION " + name
}

///|
pub impl @engine.Engine for SQLServerEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TRANSACTION " + name
}

///|
pub impl @engine.Engine for SQLServerEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let create_sql = sqlserver_create_table_sql(table_schema)
  if create_sql == "" {
    return fail("invalid table schema")
  }
  let create_res = self.exec_raw(create_sql, [])
  if !create_res.ok {
    return create_res
  }
  let comment_sql = sqlserver_comment_sql(table_schema)
  if comment_sql != "" {
    let comment_res = self.exec_raw(comment_sql, [])
    if !comment_res.ok {
      return comment_res
    }
  }
  for sql in sqlserver_index_sqls(table_schema) {
    let res = self.exec_raw(sql, [])
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub impl @engine.Engine for SQLServerEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let query = inline_sql(sql, params)
  tds_exec(self, query)
}

///|
pub impl @engine.Engine for SQLServerEngine with preload_in_sql(
  _self,
  table : String,
  key_col : String,
  count : Int,
) -> String {
  @engine.preload_in_sql_qmark(table, key_col, count)
}

///|
pub impl @engine.Engine for SQLServerEngine with preload_many_to_many_sql(
  _self,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  count : Int,
) -> String {
  @engine.preload_many_to_many_sql_qmark(
    target_table, target_key, join_table, join_owner_key, join_target_key, count,
  )
}

///|
pub impl @engine.Engine for SQLServerEngine with close(_self) -> Unit {
  ()
}
