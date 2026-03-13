///|
pub struct MySQLEngine {
  host : String
  port : Int
  user : String
  password : String
  database : String
  pool : @engine.ConnectionPool[@socket.Tcp]
  mut tx_conn : @socket.Tcp?
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
    let host = input[:i].to_string()
    let port_text = input[i + 1:].to_string()
    let port = @strconv.parse_int(port_text) catch { _ => default_port }
    (if host == "" { "127.0.0.1" } else { host }, port)
  } else {
    (if input == "" { "127.0.0.1" } else { input }, default_port)
  }
}

///|
fn parse_mysql_dsn(dsn : String) -> MySQLEngine? {
  let dsn = if dsn.strip_prefix("jdbc:") is Some(rest) {
    rest.to_string()
  } else {
    dsn
  }
  let raw = if dsn.strip_prefix("mysql://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("mariadb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("tidb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("oceanbase://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("polardb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("doris://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("starrocks://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("selectdb://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut database = ""
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string()
    database = main[i + 1:].to_string()
  }

  let mut user = "root"
  let mut password = ""
  let mut host_port = auth_host
  if auth_host.find("@") is Some(i) {
    let auth = auth_host[:i].to_string()
    host_port = auth_host[i + 1:].to_string()
    if auth.find(":") is Some(ci) {
      user = auth[:ci].to_string()
      password = auth[ci + 1:].to_string()
    } else if auth != "" {
      user = auth
    }
  }

  let (host, port) = parse_host_port(host_port, 3306)
  Some({
    host,
    port,
    user,
    password,
    database,
    pool: @engine.ConnectionPool::new(8),
    tx_conn: None,
  })
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
  let quote = fn(s : String) -> String {
    let esc = s.replace(old="'", new="''")
    "'\{esc}'"
  }
  match p {
    @engine.Null => "NULL"
    @engine.Bool(v) => if v { "TRUE" } else { "FALSE" }
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
    @engine.Date(v, format) => quote(@engine.format_plain_date(v, format))
    @engine.Time(v, format) => quote(@engine.format_plain_time(v, format))
    @engine.DateTime(v, format) =>
      quote(@engine.format_plain_date_time(v, format))
    @engine.Timestamp(v, format) =>
      quote(@engine.format_zoned_date_time(v, format))
    @engine.Uuid(v) => quote(v)
    @engine.Json(v) => quote(v.stringify())
    @engine.String(v) => quote(v)
    @engine.Bytes(v) => "x'\{@engine.bytes_to_hex(v)}'"
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
fn le_u24(v : Int) -> Bytes {
  let b = @buffer.new()
  b.write_uint_le(v.reinterpret_as_uint())
  b.to_bytes()[:3].to_bytes()
}

///|
fn le_u32(v : Int) -> Bytes {
  let b = @buffer.new()
  b.write_uint_le(v.reinterpret_as_uint())
  b.to_bytes()[:4].to_bytes()
}

///|
fn bytes_xor(a : Bytes, b : Bytes) -> Bytes {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  let out = @buffer.new()
  let mut i = 0
  while i < n {
    out.write_byte((a[i].to_int() ^ b[i].to_int()).to_byte())
    i = i + 1
  }
  out.to_bytes()
}

///|
fn mysql_native_token(password : String, seed : Bytes) -> Bytes {
  if password == "" {
    return b""
  }
  let pass = @utf8.encode(password)
  let s1 = @crypto.sha1(pass).unsafe_reinterpret_as_bytes()
  let s2 = @crypto.sha1(s1).unsafe_reinterpret_as_bytes()
  let s3 = @crypto.sha1(seed + s2).unsafe_reinterpret_as_bytes()
  bytes_xor(s1, s3)
}

///|
fn caching_sha2_token(password : String, seed : Bytes) -> Bytes {
  if password == "" {
    return b""
  }
  let pass = @utf8.encode(password)
  let s1 = @crypto.sha256(pass).unsafe_reinterpret_as_bytes()
  let s2 = @crypto.sha256(s1).unsafe_reinterpret_as_bytes()
  let s3 = @crypto.sha256(s2).unsafe_reinterpret_as_bytes()
  let s4 = @crypto.sha256(s3 + seed).unsafe_reinterpret_as_bytes()
  bytes_xor(s1, s4)
}

///|
fn auth_token(plugin : String, password : String, seed : Bytes) -> Bytes {
  if plugin == "mysql_native_password" {
    mysql_native_token(password, seed)
  } else if plugin == "caching_sha2_password" {
    caching_sha2_token(password, seed)
  } else if password == "" {
    b""
  } else {
    mysql_native_token(password, seed)
  }
}

///|
fn lenenc_int(data : Bytes, pos : Int) -> (Int, Int)? {
  if pos >= data.length() {
    return None
  }
  let first = data[pos].to_int()
  if first < 0xfb {
    Some((first, pos + 1))
  } else if first == 0xfc {
    if pos + 2 >= data.length() {
      None
    } else {
      Some((data[pos + 1].to_int() | (data[pos + 2].to_int() << 8), pos + 3))
    }
  } else if first == 0xfd {
    if pos + 3 >= data.length() {
      None
    } else {
      Some(
        (
          data[pos + 1].to_int() |
          (data[pos + 2].to_int() << 8) |
          (data[pos + 3].to_int() << 16),
          pos + 4,
        ),
      )
    }
  } else {
    None
  }
}

///|
fn lenenc_str(data : Bytes, pos : Int) -> (String?, Int)? {
  if pos >= data.length() {
    return None
  }
  if data[pos].to_int() == 0xfb {
    return Some((None, pos + 1))
  }
  match lenenc_int(data, pos) {
    Some((len, next)) =>
      if next + len > data.length() {
        None
      } else {
        Some(
          (
            Some(@utf8.decode_lossy(data[next:next + len].to_bytes())),
            next + len,
          ),
        )
      }
    None => None
  }
}

///|
fn parse_ok_affected_rows(payload : Bytes) -> Int {
  if payload.length() <= 1 {
    return 0
  }
  match lenenc_int(payload, 1) {
    Some((n, _)) => n
    None => 0
  }
}

///|
fn parse_error_packet(payload : Bytes) -> String {
  if payload.length() < 3 {
    return "mysql error"
  }
  let code = payload[1].to_int() | (payload[2].to_int() << 8)
  if payload.length() > 9 && payload[3] == b'#' {
    let msg = @utf8.decode_lossy(payload[9:payload.length()].to_bytes())
    "mysql error \{code}: " + msg
  } else {
    let msg = if payload.length() > 3 {
      @utf8.decode_lossy(payload[3:payload.length()].to_bytes())
    } else {
      ""
    }
    "mysql error \{code}: " + msg
  }
}

///|
fn json_from_text(text : String) -> Json {
  if text is ("true" | "TRUE") {
    return Json::boolean(true)
  }
  if text is ("false" | "FALSE") {
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
async fn read_packet(conn : @socket.Tcp) -> (Int, Bytes)? {
  let hdr_opt = @async.with_timeout_opt(2000, () => conn.read_exactly(4))
  if hdr_opt is None {
    return None
  }
  let hdr = match hdr_opt {
    Some(v) => v
    None => return None
  }
  let (len, seq) = match hdr {
    [u8be(b0), u8be(b1), u8be(b2), u8be(s)] =>
      (
        b0.reinterpret_as_int() |
        (b1.reinterpret_as_int() << 8) |
        (b2.reinterpret_as_int() << 16),
        s.reinterpret_as_int(),
      )
    _ => return None
  }
  let payload_opt = @async.with_timeout_opt(3000, () => conn.read_exactly(len))
  if payload_opt is None {
    return None
  }
  let payload = match payload_opt {
    Some(v) => v
    None => return None
  }
  Some((seq, payload))
}

///|
async fn write_packet(conn : @socket.Tcp, seq : Int, payload : Bytes) -> Bool {
  conn.write(le_u24(payload.length())) catch {
    _ => return false
  }
  let s = @buffer.new()
  s.write_byte((seq & 0xff).to_byte())
  conn.write(s.to_bytes()) catch {
    _ => return false
  }
  conn.write(payload) catch {
    _ => return false
  }
  true
}

///|
fn plugin_name_from_handshake(payload : Bytes) -> String {
  let mut i = 1
  while i < payload.length() && payload[i] != 0 {
    i = i + 1
  }
  i = i + 1 // server_version terminator
  if i + 4 + 8 + 1 + 2 + 1 + 2 + 2 + 1 + 10 > payload.length() {
    return "mysql_native_password"
  }
  i = i + 4 // connection id
  i = i + 8 // auth plugin data part 1
  i = i + 1 // filler
  let cap_low = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  i = i + 2
  i = i + 1 + 2 // charset + status
  let cap_high = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  let caps = cap_low | (cap_high << 16)
  i = i + 2
  let auth_len = payload[i].to_int()
  i = i + 1 + 10
  if (caps & 0x00080000) == 0 || i >= payload.length() {
    return "mysql_native_password"
  }
  let mut j = i
  let take = if auth_len > 8 { auth_len - 8 } else { 12 }
  if take > 0 {
    let mut skipped = 0
    while j < payload.length() && skipped < take && payload[j] != 0 {
      j = j + 1
      skipped = skipped + 1
    }
  }
  if j < payload.length() && payload[j] == 0 {
    j = j + 1
  }
  let mut k = j
  while k < payload.length() && payload[k] != 0 {
    k = k + 1
  }
  if k > j {
    @utf8.decode_lossy(payload[j:k].to_bytes())
  } else {
    "mysql_native_password"
  }
}

///|
fn seed_from_handshake(payload : Bytes) -> Bytes {
  let out = @buffer.new()
  let mut i = 1
  while i < payload.length() && payload[i] != 0 {
    i = i + 1
  }
  i = i + 1
  if i + 4 + 8 + 1 > payload.length() {
    return b""
  }
  i = i + 4
  out.write_bytes(payload[i:i + 8].to_bytes())
  i = i + 8 + 1
  if i + 2 + 1 + 2 + 2 + 1 + 10 > payload.length() {
    return out.to_bytes()
  }
  let cap_low = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  i = i + 2
  i = i + 1 + 2
  let cap_high = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  let caps = cap_low | (cap_high << 16)
  i = i + 2
  let auth_len = payload[i].to_int()
  i = i + 1 + 10
  if (caps & 0x00008000) != 0 && i < payload.length() {
    let need = if auth_len > 8 { auth_len - 8 } else { 12 }
    let mut j = 0
    while i + j < payload.length() && j < need && payload[i + j] != 0 {
      out.write_byte(payload[i + j])
      j = j + 1
    }
  }
  out.to_bytes()
}

///|
fn make_handshake_response(
  cfg : MySQLEngine,
  server_caps : Int,
  plugin : String,
  seed : Bytes,
) -> Bytes {
  let mut client_caps = 0x00000200 | // CLIENT_PROTOCOL_41
    0x00008000 | // CLIENT_SECURE_CONNECTION
    0x00000001 | // CLIENT_LONG_PASSWORD
    0x00000004 | // CLIENT_LONG_FLAG
    0x00002000 | // CLIENT_TRANSACTIONS
    0x00080000 | // CLIENT_PLUGIN_AUTH
    0x01000000 // CLIENT_DEPRECATE_EOF
  if cfg.database != "" {
    client_caps = client_caps | 0x00000008 // CLIENT_CONNECT_WITH_DB
  }
  let caps = client_caps & server_caps
  let auth = auth_token(plugin, cfg.password, seed)

  let b = @buffer.new()
  b.write_bytes(le_u32(caps))
  b.write_bytes(le_u32(1024 * 1024))
  b.write_byte(45) // utf8mb4_general_ci
  let mut i = 0
  while i < 23 {
    b.write_byte(0)
    i = i + 1
  }
  b.write_bytes(@utf8.encode(cfg.user))
  b.write_byte(0)
  b.write_byte(auth.length().to_byte())
  b.write_bytes(auth)
  if cfg.database != "" {
    b.write_bytes(@utf8.encode(cfg.database))
    b.write_byte(0)
  }
  b.write_bytes(@utf8.encode(plugin))
  b.write_byte(0)
  b.to_bytes()
}

///|
fn parse_server_caps(payload : Bytes) -> Int {
  let mut i = 1
  while i < payload.length() && payload[i] != 0 {
    i = i + 1
  }
  i = i + 1
  if i + 4 + 8 + 1 + 2 + 1 + 2 + 2 > payload.length() {
    return 0
  }
  i = i + 4 + 8 + 1
  let low = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  i = i + 2 + 1 + 2
  let high = payload[i].to_int() | (payload[i + 1].to_int() << 8)
  low | (high << 16)
}

///|
async fn mysql_query_async(cfg : MySQLEngine) -> Result[@socket.Tcp, String] {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ => return Err("mysql connect failed")
  }

  let handshake = read_packet(conn) catch { _ => None }
  if handshake is None {
    conn.close()
    return Err("mysql handshake read failed")
  }
  let (_, hs_payload) = handshake.unwrap()
  if hs_payload.length() == 0 {
    conn.close()
    return Err("mysql empty handshake")
  }
  if hs_payload[0].to_int() == 0xff {
    conn.close()
    return Err(parse_error_packet(hs_payload))
  }

  let server_caps = parse_server_caps(hs_payload)
  let plugin = plugin_name_from_handshake(hs_payload)
  let seed = seed_from_handshake(hs_payload)
  let resp = make_handshake_response(cfg, server_caps, plugin, seed)

  if !(write_packet(conn, 1, resp) catch { _ => false }) {
    conn.close()
    return Err("mysql handshake write failed")
  }

  let auth_res = read_packet(conn) catch { _ => None }
  if auth_res is None {
    conn.close()
    return Err("mysql auth response read failed")
  }
  let (seq0, auth_payload0) = auth_res.unwrap()
  let mut seq = seq0
  let mut auth_payload = auth_payload0

  if auth_payload.length() > 0 && auth_payload[0].to_int() == 0xfe {
    // Auth switch request
    let mut i = 1
    while i < auth_payload.length() && auth_payload[i] != 0 {
      i = i + 1
    }
    let switch_plugin = if i > 1 {
      @utf8.decode_lossy(auth_payload[1:i].to_bytes())
    } else {
      "mysql_native_password"
    }
    let switch_seed = if i + 1 < auth_payload.length() {
      auth_payload[i + 1:auth_payload.length()].to_bytes()
    } else {
      b""
    }
    let token = auth_token(switch_plugin, cfg.password, switch_seed)
    if !(write_packet(conn, seq + 1, token) catch { _ => false }) {
      conn.close()
      return Err("mysql auth switch write failed")
    }
    let p = read_packet(conn) catch { _ => None }
    if p is None {
      conn.close()
      return Err("mysql auth switch read failed")
    }
    let (s2, p2) = p.unwrap()
    seq = s2
    auth_payload = p2
  }

  if auth_payload.length() > 0 && auth_payload[0].to_int() == 0x01 {
    // AuthMoreData (caching_sha2_password)
    if auth_payload.length() >= 2 && auth_payload[1].to_int() == 0x03 {
      let p = read_packet(conn) catch { _ => None }
      if p is None {
        conn.close()
        return Err("mysql auth final read failed")
      }
      let (_, final_auth) = p.unwrap()
      auth_payload = final_auth
    } else {
      conn.close()
      return Err("mysql auth requires full authentication")
    }
  }

  if auth_payload.length() == 0 {
    conn.close()
    return Err("mysql empty auth response")
  }
  if auth_payload[0].to_int() == 0xff {
    conn.close()
    return Err(parse_error_packet(auth_payload))
  }
  if auth_payload[0].to_int() != 0x00 {
    conn.close()
    return Err("mysql auth failed")
  }

  Ok(conn)
}

///|
fn close_mysql_tcp(conn : @socket.Tcp) -> Unit {
  conn.close()
}

///|
async fn mysql_query_on_conn(
  conn : @socket.Tcp,
  sql : String,
) -> (@engine.QueryResult, Bool) {
  let q = @buffer.new()
  q.write_byte(0x03) // COM_QUERY
  q.write_bytes(@utf8.encode(sql))
  if !(write_packet(conn, 0, q.to_bytes()) catch { _ => false }) {
    return (fail("mysql query write failed"), false)
  }

  let first = read_packet(conn) catch { _ => None }
  if first is None {
    return (fail("mysql query read failed"), false)
  }
  let (_, first_payload) = first.unwrap()
  if first_payload.length() == 0 {
    return (fail("mysql empty query response"), false)
  }

  let tag = first_payload[0].to_int()
  if tag == 0xff {
    return (fail(parse_error_packet(first_payload)), true)
  }
  if tag == 0x00 {
    let affected = parse_ok_affected_rows(first_payload)
    return ({ ok: true, rows_affected: affected, rows: [], error: None }, true)
  }

  let col_count = match lenenc_int(first_payload, 0) {
    Some((n, _)) => n
    None => return (fail("mysql invalid column-count packet"), false)
  }

  let cols : Array[String] = []
  let mut i = 0
  while i < col_count {
    let p = read_packet(conn) catch { _ => None }
    if p is None {
      return (fail("mysql column definition read failed"), false)
    }
    let (_, col_def) = p.unwrap()
    let (_, p1) = match lenenc_str(col_def, 0) {
      Some(v) => v
      None => return (fail("mysql bad column definition"), false)
    }
    let (_, p2) = match lenenc_str(col_def, p1) {
      Some(v) => v
      None => return (fail("mysql bad column definition"), false)
    }
    let (_, p3) = match lenenc_str(col_def, p2) {
      Some(v) => v
      None => return (fail("mysql bad column definition"), false)
    }
    let (_, p4) = match lenenc_str(col_def, p3) {
      Some(v) => v
      None => return (fail("mysql bad column definition"), false)
    }
    let (name, _) = match lenenc_str(col_def, p4) {
      Some(v) => v
      None => return (fail("mysql bad column definition"), false)
    }
    cols.push(name.unwrap_or("c" + i.to_string()))
    i = i + 1
  }

  // EOF / OK after column definitions may be present depending on server/client flags.
  let mut pending_row : Bytes? = None
  let after_cols = read_packet(conn) catch { _ => None }
  if after_cols is None {
    return (fail("mysql missing packet after column definitions"), false)
  }
  let (_, after_cols_payload) = after_cols.unwrap()
  if !(after_cols_payload.length() > 0 &&
    (
      (
        after_cols_payload[0].to_int() == 0xfe &&
        after_cols_payload.length() < 9
      ) ||
      (
        after_cols_payload[0].to_int() == 0x00 &&
        after_cols_payload.length() < 9
      )
    )) {
    pending_row = Some(after_cols_payload)
  }

  let rows : Array[Json] = []
  let mut done = false
  let mut first_pending = pending_row
  while !done {
    let row_pkt = match first_pending {
      Some(v) => {
        first_pending = None
        v
      }
      None => {
        let p = read_packet(conn) catch { _ => None }
        if p is None {
          return (fail("mysql row read failed"), false)
        }
        let (_, pkt) = p.unwrap()
        pkt
      }
    }
    if row_pkt.length() > 0 && row_pkt[0].to_int() == 0xff {
      return (fail(parse_error_packet(row_pkt)), true)
    }
    if row_pkt.length() > 0 &&
      row_pkt[0].to_int() == 0xfe &&
      row_pkt.length() < 9 {
      done = true
    } else if row_pkt.length() > 0 &&
      row_pkt[0].to_int() == 0x00 &&
      row_pkt.length() < 9 {
      done = true
    } else {
      let obj : Map[String, Json] = {}
      let mut pos = 0
      let mut c = 0
      while c < cols.length() {
        let parsed = lenenc_str(row_pkt, pos)
        if parsed is None {
          return (fail("mysql bad row packet"), false)
        }
        let (v, np) = parsed.unwrap()
        pos = np
        obj[cols[c]] = match v {
          Some(s) => json_from_text(s)
          None => Json::null()
        }
        c = c + 1
      }
      rows.push(obj.to_json())
    }
  }

  (
    {
      ok: true,
      rows_affected: rows.length(),
      rows: FixedArray::from_array(rows),
      error: None,
    },
    true,
  )
}

///|
fn mysql_is_tx_begin(sql : String) -> Bool {
  sql.trim() == "START TRANSACTION"
}

///|
fn mysql_is_tx_commit(sql : String) -> Bool {
  sql.trim() == "COMMIT"
}

///|
fn mysql_is_tx_rollback(sql : String) -> Bool {
  sql.trim() == "ROLLBACK"
}

///|
async fn mysql_exec_sql(
  engine : MySQLEngine,
  sql : String,
) -> @engine.QueryResult {
  if mysql_is_tx_begin(sql) {
    if engine.tx_conn is Some(_) {
      return fail("mysql transaction already active")
    }
    let conn = match engine.pool.borrow(() => mysql_query_async(engine)) {
      Ok(conn) => conn
      Err(err) => return fail(err)
    }
    let (res, reusable) = mysql_query_on_conn(conn, sql)
    if res.ok {
      engine.tx_conn = Some(conn)
    } else {
      engine.pool.release(conn, close_mysql_tcp, reusable~)
    }
    return res
  }

  if engine.tx_conn is Some(conn) {
    let (res, reusable) = mysql_query_on_conn(conn, sql)
    if mysql_is_tx_commit(sql) || mysql_is_tx_rollback(sql) {
      engine.tx_conn = None
      engine.pool.release(conn, close_mysql_tcp, reusable~)
    } else if !reusable {
      engine.tx_conn = None
      engine.pool.release(conn, close_mysql_tcp, reusable=false)
    }
    return res
  }

  let conn = match engine.pool.borrow(() => mysql_query_async(engine)) {
    Ok(conn) => conn
    Err(err) => return fail(err)
  }
  let (res, reusable) = mysql_query_on_conn(conn, sql)
  engine.pool.release(conn, close_mysql_tcp, reusable~)
  res
}

///|
pub async fn MySQLEngine::ping(self : MySQLEngine) -> Bool {
  mysql_exec_sql(self, "SELECT 1").ok
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
fn schema_get_int(obj : Map[String, Json], key : String, default : Int) -> Int {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
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
fn mysql_table_name(obj : Map[String, Json], name : String) -> String {
  let schema = schema_get_string(obj, "schema", "")
  let catalog = schema_get_string(obj, "catalog", "")
  let table_ns = if schema != "" { schema } else { catalog }
  if table_ns != "" {
    "\{table_ns}.\{name}"
  } else {
    name
  }
}

///|
fn mysql_type_from_json(v : Json) -> String {
  let from_name = fn(name : String, arg0 : Int, arg1 : Int) -> String {
    match name {
      "TinyInt" => "TINYINT"
      "SmallInt" => "SMALLINT"
      "MediumInt" => "MEDIUMINT"
      "Int" => "INT"
      "BigInt" => "BIGINT"
      "Float" => "FLOAT"
      "Double" => "DOUBLE"
      "Decimal" => "DECIMAL(\{arg0}, \{arg1})"
      "Char" => "CHAR(\{arg0})"
      "VarChar" => "VARCHAR(\{arg0})"
      "Text" => "TEXT"
      "MediumText" => "MEDIUMTEXT"
      "LongText" => "LONGTEXT"
      "Binary" => "BINARY(\{arg0})"
      "VarBinary" => "VARBINARY(\{arg0})"
      "Blob" => "BLOB"
      "MediumBlob" => "MEDIUMBLOB"
      "LongBlob" => "LONGBLOB"
      "Date" => "DATE"
      "Time" => "TIME"
      "DateTime" => "DATETIME"
      "Timestamp" => "TIMESTAMP"
      "Year" => "YEAR"
      "Json" | "JsonB" => "JSON"
      "Boolean" => "TINYINT(1)"
      _ => "TEXT"
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
        "TEXT"
      }
    _ => "TEXT"
  }
}

///|
fn mysql_json_storage_type(
  obj : Map[String, Json],
  default_jsonb : Bool,
) -> String {
  match schema_get_engine_option(obj, "json.storage", "") {
    "blob" | "bson" => "LONGBLOB"
    "text" | "string" => "LONGTEXT"
    "jsonb" => "JSON"
    "json" => "JSON"
    _ => if default_jsonb { "JSON" } else { "JSON" }
  }
}

///|
fn mysql_column_def(col_json : Json) -> String {
  if col_json is Object(obj) {
    let name = schema_get_string(obj, "name", "")
    if name == "" {
      return ""
    }
    let col_type = match obj.get("column_type") {
      Some(String("Json")) => mysql_json_storage_type(obj, false)
      Some(String("JsonB")) => mysql_json_storage_type(obj, true)
      Some(v) => mysql_type_from_json(v)
      None => "TEXT"
    }
    let primary_key = schema_get_bool(obj, "primary_key", false)
    let auto_increment = schema_get_bool(obj, "auto_increment", false)
    let nullable = schema_get_bool(obj, "nullable", true)
    let unique = schema_get_bool(obj, "unique", false)
    let mut sql = "\{name} \{col_type}"
    if auto_increment {
      sql = sql + " AUTO_INCREMENT"
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
fn mysql_fk_def(fk_json : Json) -> String {
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
fn mysql_create_table_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let base_name = schema_get_string(obj, "name", "")
    if base_name == "" {
      return ""
    }
    let table_name = mysql_table_name(obj, base_name)
    let defs : Array[String] = []
    if obj.get("columns") is Some([.. v]) {
      for c in v {
        let d = mysql_column_def(c)
        if d != "" {
          defs.push(d)
        }
      }
    }
    if obj.get("foreign_keys") is Some([.. v]) {
      for fk in v {
        let d = mysql_fk_def(fk)
        if d != "" {
          defs.push(d)
        }
      }
    }
    let defs_sql = defs.join(", ")
    let temporary = schema_get_bool(obj, "temporary", false)
    let if_not_exists = schema_get_bool(obj, "if_not_exists", true)
    let create_prefix = if temporary {
      "CREATE TEMPORARY TABLE"
    } else {
      "CREATE TABLE"
    }
    let mut sql = if if_not_exists {
      "\{create_prefix} IF NOT EXISTS \{table_name} (\{defs_sql})"
    } else {
      "\{create_prefix} \{table_name} (\{defs_sql})"
    }
    let engine_name = schema_get_string(obj, "engine", "InnoDB")
    let charset = schema_get_string(obj, "charset", "utf8mb4")
    let collation = schema_get_string(obj, "collation", "utf8mb4_unicode_ci")
    sql = sql + " ENGINE=" + engine_name
    sql = sql + " DEFAULT CHARSET=" + charset
    sql = sql + " COLLATE=" + collation
    let auto_increment = schema_get_int(obj, "auto_increment", 1)
    if auto_increment > 1 {
      sql = sql + " AUTO_INCREMENT=" + auto_increment.to_string()
    }
    let row_format = schema_get_engine_option(obj, "mysql.row_format", "")
    if row_format != "" {
      sql = sql + " ROW_FORMAT=" + row_format
    }
    let key_block_size = schema_get_engine_option(
      obj, "mysql.key_block_size", "",
    )
    if key_block_size != "" {
      sql = sql + " KEY_BLOCK_SIZE=" + key_block_size
    }
    let compression = schema_get_engine_option(obj, "mysql.compression", "")
    if compression != "" {
      sql = sql +
        " COMPRESSION='" +
        compression.replace(old="'", new="''") +
        "'"
    }
    let tablespace = schema_get_string(obj, "tablespace", "")
    if tablespace != "" {
      sql = sql + " TABLESPACE=" + tablespace
    }
    let comment = schema_get_string(obj, "comment", "")
    if comment != "" {
      sql = sql + " COMMENT='" + comment.replace(old="'", new="''") + "'"
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
fn mysql_comment_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let comment = schema_get_string(obj, "comment", "")
    let base_name = schema_get_string(obj, "name", "")
    if comment == "" || base_name == "" {
      return ""
    }
    let table_name = mysql_table_name(obj, base_name)
    "ALTER TABLE " +
    table_name +
    " COMMENT = '" +
    comment.replace(old="'", new="''") +
    "'"
  } else {
    ""
  }
}

///|
fn mysql_index_sqls(table_schema : Json) -> Array[String] {
  if table_schema is Object(obj) {
    let base_name = schema_get_string(obj, "name", "")
    if base_name == "" {
      return []
    }
    let table_name = mysql_table_name(obj, base_name)
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
          let prefix = if idx_type == "Unique" {
            "CREATE UNIQUE INDEX "
          } else {
            "CREATE INDEX "
          }
          sqls.push(
            prefix +
            idx_name +
            " ON " +
            table_name +
            " (" +
            cols.join(", ") +
            ")",
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
pub impl @engine.Engine for MySQLEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  @engine.render_default_sql(stmt)
}

///|
pub impl @engine.Engine for MySQLEngine with tx_begin_sql(_self) -> String {
  "START TRANSACTION"
}

///|
pub impl @engine.Engine for MySQLEngine with tx_commit_sql(_self) -> String {
  "COMMIT"
}

///|
pub impl @engine.Engine for MySQLEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK"
}

///|
pub impl @engine.Engine for MySQLEngine with tx_savepoint_sql(
  _self,
  name : String,
) -> String {
  "SAVEPOINT " + name
}

///|
pub impl @engine.Engine for MySQLEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TO SAVEPOINT " + name
}

///|
pub impl @engine.Engine for MySQLEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let create_sql = mysql_create_table_sql(table_schema)
  if create_sql == "" {
    return {
      ok: false,
      rows_affected: 0,
      rows: [],
      error: Some("invalid table schema"),
    }
  }
  let create_res = self.exec_raw(create_sql, [])
  if !create_res.ok {
    return create_res
  }
  let comment_sql = mysql_comment_sql(table_schema)
  if comment_sql != "" {
    let comment_res = self.exec_raw(comment_sql, [])
    if !comment_res.ok {
      return comment_res
    }
  }
  for sql in mysql_index_sqls(table_schema) {
    let res = self.exec_raw(sql, [])
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub impl @engine.Engine for MySQLEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let query = inline_sql(sql, params)
  mysql_exec_sql(self, query)
}

///|
pub impl @engine.Engine for MySQLEngine with preload_belongs_to_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  let sql = @engine.preload_in_sql_qmark(
    target_table,
    target_key,
    key_params.length(),
  )
  @engine.preload_belongs_to_default(self, sql, target_key, key_params)
}

///|
pub impl @engine.Engine for MySQLEngine with preload_has_one_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  let sql = @engine.preload_in_sql_qmark(
    target_table,
    target_key,
    key_params.length(),
  )
  @engine.preload_belongs_to_default(self, sql, target_key, key_params)
}

///|
pub impl @engine.Engine for MySQLEngine with preload_has_many_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let sql = @engine.preload_in_sql_qmark(
    target_table,
    target_key,
    key_params.length(),
  )
  @engine.preload_has_many_default(self, sql, target_key, key_params)
}

///|
pub impl @engine.Engine for MySQLEngine with preload_many_to_many_json(
  self,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let sql = @engine.preload_many_to_many_sql_qmark(
    target_table,
    target_key,
    join_table,
    join_owner_key,
    join_target_key,
    key_params.length(),
  )
  @engine.preload_many_to_many_default(self, sql, key_params)
}

///|
pub impl @engine.Engine for MySQLEngine with close(self) -> Unit {
  if self.tx_conn is Some(conn) {
    self.tx_conn = None
    close_mysql_tcp(conn)
  }
  self.pool.close(close_mysql_tcp)
}
