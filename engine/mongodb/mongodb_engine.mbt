///|
pub(all) struct MongoDBEngine {
  host : String
  port : Int
  seeds : FixedArray[String]
  database : String
  auth_database : String
  user : String
  password : String
  pool : @engine.ConnectionPool[@socket.Tcp]
}

///|
fn ok_result(
  rows_affected : Int,
  rows : FixedArray[Json],
) -> @engine.QueryResult {
  { ok: true, rows_affected, rows, error: None }
}

///|
fn fail_result(msg : String) -> @engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(msg) }
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
fn find_query_param(raw_query : String, key : String) -> String? {
  for part in raw_query.split("&") {
    if part.find("=") is Some(idx) {
      let name = part[:idx].to_string()
      if name == key {
        return Some(part[idx + 1:].to_string())
      }
    } else if part == key {
      return Some("")
    }
  }
  None
}

///|
fn parse_host_port(text : String, default_port : Int) -> (String, Int) {
  if text.rev_find(":") is Some(idx) {
    let host = text[:idx].to_string()
    let port_text = text[idx + 1:].to_string()
    let port = @strconv.parse_int(port_text) catch { _ => default_port }
    (if host == "" { "127.0.0.1" } else { host }, port)
  } else {
    (if text == "" { "127.0.0.1" } else { text }, default_port)
  }
}

///|
fn parse_seed_list(hosts : String, default_port : Int) -> FixedArray[String] {
  let out : Array[String] = []
  for part in hosts.split(",") {
    let item = part.trim().to_string()
    if item != "" {
      let (host, port) = parse_host_port(item, default_port)
      out.push("\{host}:\{port}")
    }
  }
  if out.is_empty() {
    out.push("127.0.0.1:\{default_port}")
  }
  FixedArray::from_array(out)
}

///|
fn parse_mongodb_dsn(dsn : String) -> MongoDBEngine? {
  let (raw, is_srv) = if dsn.strip_prefix("mongodb://") is Some(rest) {
    (rest.to_string(), false)
  } else if dsn.strip_prefix("mongodb+srv://") is Some(rest) {
    (rest.to_string(), true)
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let raw_query = if raw.find("?") is Some(idx) {
    raw[idx + 1:].to_string()
  } else {
    ""
  }
  let mut auth_host = main
  let mut database = "test"
  let mut has_database = false
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string()
    database = main[i + 1:].to_string()
    has_database = database != ""
  }

  let mut user = ""
  let mut password = ""
  let mut host_port = auth_host
  if auth_host.find("@") is Some(i) {
    let auth = auth_host[:i].to_string()
    host_port = auth_host[i + 1:].to_string()
    if auth.find(":") is Some(ci) {
      user = auth[:ci].to_string()
      password = auth[ci + 1:].to_string()
    } else {
      user = auth
    }
  }

  let seeds = parse_seed_list(host_port, 27017)
  let (host, port) = if seeds.length() > 0 {
    parse_host_port(seeds[0], 27017)
  } else {
    ("127.0.0.1", 27017)
  }
  let auth_database = match find_query_param(raw_query, "authSource") {
    Some(source) if source != "" => source
    _ => if user != "" && !has_database { "admin" } else { database }
  }
  if is_srv && host_port.contains(":") {
    return None
  }
  Some({
    host,
    port,
    seeds,
    database: if database == "" {
      "test"
    } else {
      database
    },
    auth_database: if auth_database == "" {
      "admin"
    } else {
      auth_database
    },
    user,
    password,
    pool: @engine.ConnectionPool::new(8),
  })
}

///|
pub fn MongoDBEngine::open(dsn : String) -> Result[MongoDBEngine, String] {
  match parse_mongodb_dsn(dsn) {
    Some(cfg) => Ok(cfg)
    None => Err("invalid mongodb dsn: \{dsn}")
  }
}

///|
fn param_to_json(value : @engine.Param) -> Json {
  match value {
    @engine.Bytes(data) => @bson.from_bytes(data) catch { _ => data.to_json() }
    _ => value.to_json()
  }
}

///|
fn json_to_param(value : Json) -> @engine.Param {
  match value {
    Null => @engine.Null
    True => @engine.Bool(true)
    False => @engine.Bool(false)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        @engine.Int(n.to_int())
      } else {
        @engine.Double(n)
      }
    String(s) => @engine.String(s)
    Array(_) | Object(_) => @engine.Json(value)
  }
}

///|
fn i32le_bytes(v : Int) -> Bytes {
  let b = @buffer.new()
  b.write_int_le(v)
  b.to_bytes()
}

///|
fn read_i32(data : Bytes, offset : Int) -> Int? {
  if offset < 0 || offset + 4 > data.length() {
    return None
  }
  match data[offset:offset + 4] {
    [i32le(v)] => Some(v)
    _ => None
  }
}

///|
async fn read_exact_timed(
  conn : @socket.Tcp,
  len : Int,
  timeout_ms : Int,
) -> Bytes? {
  @async.with_timeout_opt(timeout_ms, () => conn.read_exactly(len))
}

///|
async fn connect_server(engine : MongoDBEngine) -> @socket.Tcp? {
  for seed in engine.seeds {
    let (host, port) = parse_host_port(seed, 27017)
    let conn = @async.with_timeout_opt(2000, () => {
      @socket.Tcp::connect_to_host(host, port~)
    }) catch {
      _ => None
    }
    if conn is Some(conn) {
      return Some(conn)
    }
  }
  None
}

///|
fn close_tcp(conn : @socket.Tcp) -> Unit {
  conn.close()
}

///|
async fn write_all(conn : @socket.Tcp, data : Bytes) -> Bool {
  conn.write(data) catch {
    _ => return false
  }
  true
}

///|
async fn write_op_msg(
  conn : @socket.Tcp,
  request_id : Int,
  command_bson : Bytes,
) -> Bool {
  let body = i32le_bytes(0) + b"\x00" + command_bson
  let header = i32le_bytes(16 + body.length()) +
    i32le_bytes(request_id) +
    i32le_bytes(0) +
    i32le_bytes(2013)
  write_all(conn, header + body)
}

///|
async fn read_op_msg(conn : @socket.Tcp) -> Json? {
  let header = read_exact_timed(conn, 16, 3000)
  guard header is Some(header) else { return None }
  let total_len = read_i32(header, 0).unwrap_or(0)
  let op_code = read_i32(header, 12).unwrap_or(0)
  guard total_len >= 21 && op_code == 2013 else { return None }
  let body_len = total_len - 16
  let body = read_exact_timed(conn, body_len, 3000)
  guard body is Some(body) else { return None }
  guard body.length() >= 5 && body[4].to_int() == 0 else { return None }
  let doc_len = read_i32(body, 5).unwrap_or(0)
  guard doc_len >= 5 && 5 + doc_len <= body.length() else { return None }
  Some(@bson.from_document_bytes(body[5:5 + doc_len].to_bytes())) catch {
    _ => None
  }
}

///|
fn command_err(doc : Json) -> String? {
  match doc {
    { "errmsg": String(msg), .. } => Some(msg)
    _ => None
  }
}

///|
fn command_ok(doc : Json) -> Bool {
  match doc {
    { "ok": Number(n, ..), .. } => n != 0.0
    { "ok": True, .. } => true
    _ => false
  }
}

///|
fn command_failed_message(doc : Json, fallback : String) -> String {
  match command_err(doc) {
    Some(msg) => msg
    None => fallback
  }
}

///|
fn json_to_int(value : Json) -> Int? {
  match value {
    String(text) => Some(@strconv.parse_int(text)) catch { _ => None }
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
fn json_to_bool(value : Json) -> Bool? {
  match value {
    True => Some(true)
    False => Some(false)
    _ => None
  }
}

///|
fn write_bson_bool_field(
  buf : @buffer.Buffer,
  key : String,
  value : Bool,
) -> Unit {
  buf.write_byte(0x08)
  write_cstring(buf, key)
  buf.write_byte(if value { 1 } else { 0 })
}

///|
fn write_bson_binary_field(
  buf : @buffer.Buffer,
  key : String,
  value : Bytes,
  subtype? : Byte = b'\x00',
) -> Unit {
  buf.write_byte(0x05)
  write_cstring(buf, key)
  buf.write_int_le(value.length())
  buf.write_byte(subtype)
  buf.write_bytes(value)
}

///|
fn write_bson_document_field(
  buf : @buffer.Buffer,
  key : String,
  value : Bytes,
) -> Unit {
  buf.write_byte(0x03)
  write_cstring(buf, key)
  buf.write_bytes(value)
}

///|
fn encode_skip_empty_options() -> Bytes {
  let body = @buffer.new()
  write_bson_bool_field(body, "skipEmptyExchange", true)
  body.write_byte(0)
  let out = @buffer.new()
  out.write_int_le(body.length() + 4)
  out.write_bytes(body.to_bytes())
  out.to_bytes()
}

///|
fn encode_sasl_start_command(engine : MongoDBEngine, payload : String) -> Bytes {
  let body = @buffer.new()
  write_bson_i32_field(body, "saslStart", 1)
  write_bson_string_field(body, "mechanism", "SCRAM-SHA-256")
  write_bson_binary_field(body, "payload", @utf8.encode(payload))
  write_bson_i32_field(body, "autoAuthorize", 1)
  write_bson_document_field(body, "options", encode_skip_empty_options())
  write_bson_string_field(body, "$db", engine.auth_database)
  body.write_byte(0)
  let out = @buffer.new()
  out.write_int_le(body.length() + 4)
  out.write_bytes(body.to_bytes())
  out.to_bytes()
}

///|
fn encode_sasl_continue_command(
  engine : MongoDBEngine,
  conversation_id : Int,
  payload : String,
) -> Bytes {
  let body = @buffer.new()
  write_bson_i32_field(body, "saslContinue", 1)
  write_bson_i32_field(body, "conversationId", conversation_id)
  write_bson_binary_field(body, "payload", @utf8.encode(payload))
  write_bson_string_field(body, "$db", engine.auth_database)
  body.write_byte(0)
  let out = @buffer.new()
  out.write_int_le(body.length() + 4)
  out.write_bytes(body.to_bytes())
  out.to_bytes()
}

///|
fn escape_scram_name(text : String) -> String {
  text.replace(old="=", new="=3D").replace(old=",", new="=2C")
}

///|
fn parse_scram_fields(message : String) -> Map[String, String] {
  let out : Map[String, String] = {}
  for part in message.split(",") {
    if part.find("=") is Some(idx) {
      let key = part[:idx].to_string()
      let value = part[idx + 1:].to_string()
      out[key] = value
    }
  }
  out
}

///|
fn scram_hmac(key : Bytes, message : Bytes) -> FixedArray[Byte] {
  @crypto.hmac(@crypto.SHA256::new(), key, message)
}

///|
fn i32be_bytes(v : Int) -> Bytes {
  let out = @buffer.new(size_hint=4)
  out.write_byte(((v >> 24) & 0xFF).to_byte())
  out.write_byte(((v >> 16) & 0xFF).to_byte())
  out.write_byte(((v >> 8) & 0xFF).to_byte())
  out.write_byte((v & 0xFF).to_byte())
  out.to_bytes()
}

///|
fn xor_bytes(
  lhs : FixedArray[Byte],
  rhs : FixedArray[Byte],
) -> FixedArray[Byte] {
  let n = if lhs.length() < rhs.length() { lhs.length() } else { rhs.length() }
  let out = FixedArray::make(n, b'\x00')
  for i = 0; i < n; i = i + 1 {
    out[i] = lhs[i] ^ rhs[i]
  }
  out
}

///|
fn pbkdf2_sha256(
  password : Bytes,
  salt : Bytes,
  iterations : Int,
  key_len : Int,
) -> Bytes {
  let out = @buffer.new(size_hint=key_len)
  let block_count = (key_len + 31) / 32
  for block = 1; block <= block_count; block = block + 1 {
    let mut u = scram_hmac(password, salt + i32be_bytes(block))
    let t = u.copy()
    for iter_idx = 1; iter_idx < iterations; iter_idx = iter_idx + 1 {
      u = scram_hmac(password, u.unsafe_reinterpret_as_bytes())
      for i = 0; i < t.length(); i = i + 1 {
        t[i] = t[i] ^ u[i]
      }
    }
    let remaining = key_len - out.length()
    let take = if remaining < t.length() { remaining } else { t.length() }
    for i = 0; i < take; i = i + 1 {
      out.write_byte(t[i])
    }
  }
  out.to_bytes()
}

///|
fn auth_payload_text(doc : Json) -> String? {
  match doc {
    { "payload": String(text), .. } => Some(text)
    { "payload": payload, .. } =>
      match @bson.json_bytes_to_bytes(payload) {
        Some(data) => Some(@utf8.decode_lossy(data))
        None => None
      }
    _ => None
  }
}

///|
fn auth_conversation_id(doc : Json) -> Int? {
  match doc {
    { "conversationId": value, .. } => json_to_int(value)
    _ => None
  }
}

///|
fn auth_done(doc : Json) -> Bool {
  match doc {
    { "done": value, .. } => json_to_bool(value).unwrap_or(false)
    _ => false
  }
}

///|
async fn write_checked(
  conn : @socket.Tcp,
  request_id : Int,
  command_bson : Bytes,
  label : String,
) -> Result[Json, String] {
  if !(write_op_msg(conn, request_id, command_bson) catch { _ => false }) {
    return Err("mongodb \{label} write failed")
  }
  let reply = read_op_msg(conn) catch { _ => None }
  guard reply is Some(reply_doc) else {
    return Err("mongodb \{label} read failed")
  }
  if !command_ok(reply_doc) {
    return Err(command_failed_message(reply_doc, "mongodb \{label} failed"))
  }
  Ok(reply_doc)
}

///|
async fn write_read(
  conn : @socket.Tcp,
  request_id : Int,
  command_bson : Bytes,
  label : String,
) -> Result[Json, String] {
  if !(write_op_msg(conn, request_id, command_bson) catch { _ => false }) {
    return Err("mongodb \{label} write failed")
  }
  let reply = read_op_msg(conn) catch { _ => None }
  guard reply is Some(reply_doc) else {
    return Err("mongodb \{label} read failed")
  }
  Ok(reply_doc)
}

///|
async fn authenticate_connection(
  engine : MongoDBEngine,
  conn : @socket.Tcp,
) -> Result[Unit, String] {
  if engine.user == "" {
    return Ok(())
  }

  let nonce_seed = @utf8.encode(
    "\{engine.user}:\{engine.password}@\{engine.host}:\{engine.port}/\{engine.auth_database}",
  )
  let client_nonce = @base64.encode(
    @crypto.sha256(nonce_seed).unsafe_reinterpret_as_bytes(),
    padding=false,
  )
  let client_first_bare = "n=\{escape_scram_name(engine.user)},r=\{client_nonce}"
  let client_first = "n,,\{client_first_bare}"
  let start_reply = write_checked(
    conn,
    2,
    encode_sasl_start_command(engine, client_first),
    "saslStart",
  )
  let start_doc = match start_reply {
    Ok(doc) => doc
    Err(err) => return Err(err)
  }
  let conversation_id = match auth_conversation_id(start_doc) {
    Some(id) => id
    None => return Err("mongodb saslStart conversation id missing")
  }
  let mut next_request_id = 3
  let mut server_first = auth_payload_text(start_doc).unwrap_or("")
  if server_first == "" {
    let first_continue = write_checked(
      conn,
      next_request_id,
      encode_sasl_continue_command(engine, conversation_id, client_first),
      "saslContinue client first",
    )
    next_request_id = next_request_id + 1
    let first_continue_doc = match first_continue {
      Ok(doc) => doc
      Err(err) => return Err(err)
    }
    server_first = match auth_payload_text(first_continue_doc) {
      Some(text) if text != "" => text
      _ => return Err("mongodb saslStart payload missing")
    }
  }

  let first_fields = parse_scram_fields(server_first)
  let server_nonce = first_fields.get("r").unwrap_or("")
  let salt_text = first_fields.get("s").unwrap_or("")
  let iter_text = first_fields.get("i").unwrap_or("")
  guard server_nonce.strip_prefix(client_nonce) is Some(rest) && rest != "" else {
    return Err("mongodb scram nonce mismatch")
  }
  let salt = @base64.decode(salt_text) catch {
    _ => return Err("mongodb scram salt decode failed")
  }
  let iterations = @strconv.parse_int(iter_text) catch {
    _ => return Err("mongodb scram iteration parse failed")
  }
  guard iterations > 0 else { return Err("mongodb scram iteration invalid") }

  let password = @utf8.encode(engine.password)
  let salted_password = pbkdf2_sha256(password, salt, iterations, 32)
  let client_final_without_proof = "c=biws,r=\{server_nonce}"
  let auth_message = client_first_bare +
    "," +
    server_first +
    "," +
    client_final_without_proof
  let client_key = scram_hmac(salted_password, @utf8.encode("Client Key"))
  let stored_key = @crypto.sha256(client_key.unsafe_reinterpret_as_bytes())
  let client_signature = scram_hmac(
    stored_key.unsafe_reinterpret_as_bytes(),
    @utf8.encode(auth_message),
  )
  let client_proof = xor_bytes(client_key, client_signature)
  let server_key = scram_hmac(salted_password, @utf8.encode("Server Key"))
  let expected_server_sig = @base64.encode(
    scram_hmac(
      server_key.unsafe_reinterpret_as_bytes(),
      @utf8.encode(auth_message),
    ).unsafe_reinterpret_as_bytes(),
  )
  let client_final = client_final_without_proof +
    ",p=" +
    @base64.encode(client_proof.unsafe_reinterpret_as_bytes())

  let continue_reply = write_checked(
    conn,
    next_request_id,
    encode_sasl_continue_command(engine, conversation_id, client_final),
    "saslContinue",
  )
  next_request_id = next_request_id + 1
  let continue_doc = match continue_reply {
    Ok(doc) => doc
    Err(err) => return Err(err)
  }
  let server_final = auth_payload_text(continue_doc).unwrap_or("")
  let final_fields = parse_scram_fields(server_final)
  if final_fields.get("e") is Some(msg) {
    return Err("mongodb auth failed: \{msg}")
  }
  let server_sig = final_fields.get("v").unwrap_or("")
  guard server_sig == expected_server_sig else {
    return Err("mongodb scram server signature mismatch")
  }

  if !auth_done(continue_doc) {
    match
      write_checked(
        conn,
        next_request_id,
        encode_sasl_continue_command(engine, conversation_id, ""),
        "saslContinue finalize",
      ) {
      Ok(_) => ()
      Err(err) => return Err(err)
    }
  }
  Ok(())
}

///|
async fn open_authenticated_connection(
  engine : MongoDBEngine,
) -> Result[@socket.Tcp, String] {
  let conn = connect_server(engine)
  guard conn is Some(conn) else { return Err("mongodb connect failed") }

  let hello : Json = {
    "hello": Json::number(1.0),
    "$db": Json::string(engine.database),
  }
  let hello_bson = @bson.to_document_bytes(hello) catch {
    _ => return Err("mongodb hello encode failed")
  }
  match write_checked(conn, 1, hello_bson, "hello") {
    Ok(_) => ()
    Err(err) => {
      close_tcp(conn)
      return Err(err)
    }
  }
  match authenticate_connection(engine, conn) {
    Ok(_) => ()
    Err(err) => {
      close_tcp(conn)
      return Err(err)
    }
  }
  Ok(conn)
}

///|
async fn run_command_bson(
  engine : MongoDBEngine,
  command_bson : Bytes,
) -> Result[Json, String] {
  let conn = match
    engine.pool.borrow(() => open_authenticated_connection(engine)) {
    Ok(conn) => conn
    Err(err) => return Err(err)
  }
  let reply = write_read(conn, 10, command_bson, "command")
  match reply {
    Ok(doc) => {
      engine.pool.release(conn, close_tcp)
      if !command_ok(doc) {
        Err(command_failed_message(doc, "mongodb command failed"))
      } else {
        Ok(doc)
      }
    }
    Err(err) => {
      engine.pool.release(conn, close_tcp, reusable=false)
      Err(err)
    }
  }
}

///|
async fn run_command(
  engine : MongoDBEngine,
  command : Json,
) -> Result[Json, String] {
  let command = match command {
    Object(obj) => {
      let out = obj.copy()
      out["$db"] = Json::string(engine.database)
      out.to_json()
    }
    _ => return Err("mongodb command must be an object")
  }
  let command_bson = @bson.to_document_bytes(command) catch {
    _ => return Err("mongodb command encode failed")
  }
  run_command_bson(engine, command_bson)
}

///|
fn write_cstring(buf : @buffer.Buffer, text : String) -> Unit {
  buf.write_string_utf8(text)
  buf.write_byte(0)
}

///|
fn write_bson_string_field(
  buf : @buffer.Buffer,
  key : String,
  value : String,
) -> Unit {
  buf.write_byte(0x02)
  write_cstring(buf, key)
  let tmp = @buffer.new()
  tmp.write_string_utf8(value)
  let bytes = tmp.to_bytes()
  buf.write_int_le(bytes.length() + 1)
  buf.write_bytes(bytes)
  buf.write_byte(0)
}

///|
fn write_bson_i32_field(
  buf : @buffer.Buffer,
  key : String,
  value : Int,
) -> Unit {
  buf.write_byte(0x10)
  write_cstring(buf, key)
  buf.write_int_le(value)
}

///|
fn write_bson_i64_field(
  buf : @buffer.Buffer,
  key : String,
  value : Int64,
) -> Unit {
  buf.write_byte(0x12)
  write_cstring(buf, key)
  buf.write_int64_le(value)
}

///|
fn encode_getmore_command(
  engine : MongoDBEngine,
  cursor_id : Int64,
  table : String,
  batch_size : Int,
) -> Bytes {
  let body = @buffer.new()
  write_bson_i64_field(body, "getMore", cursor_id)
  write_bson_string_field(body, "collection", table)
  write_bson_i32_field(body, "batchSize", batch_size)
  write_bson_string_field(body, "$db", engine.database)
  body.write_byte(0)
  let out = @buffer.new()
  out.write_int_le(body.length() + 4)
  out.write_bytes(body.to_bytes())
  out.to_bytes()
}

///|
fn parse_projection(select : String) -> FixedArray[String]? {
  let text = select.trim()
  if text == "" || text == "*" {
    None
  } else {
    Some(
      FixedArray::from_iter(
        text
        .split(",")
        .map(part => part.trim().to_string())
        .filter(name => name != ""),
      ),
    )
  }
}

///|
fn projection_doc(select : String) -> Json? {
  match parse_projection(select) {
    None => None
    Some(cols) => {
      let out : Map[String, Json] = {}
      for col in cols {
        out[col] = Json::number(1.0)
      }
      Some(out.to_json())
    }
  }
}

///|
fn append_condition(
  filter : Map[String, Json],
  col : String,
  op : String?,
  value : Json,
) -> Unit {
  match op {
    None =>
      if filter.get(col) is Some(Object(existing)) {
        let next = existing.copy()
        next["$eq"] = value
        filter[col] = next.to_json()
      } else {
        filter[col] = value
      }
    Some(name) => {
      let next : Map[String, Json] = match filter.get(col) {
        Some(Object(existing)) => existing.copy()
        Some(existing) => {
          let tmp : Map[String, Json] = {}
          tmp["$eq"] = existing
          tmp
        }
        None => Map::new()
      }
      next[name] = value
      filter[col] = next.to_json()
    }
  }
}

///|
fn where_to_filter(where_ : FixedArray[@engine.Where]) -> Json {
  let filter : Map[String, Json] = {}
  for clause in where_ {
    let value = param_to_json(clause.value)
    match clause.ty {
      Eq => append_condition(filter, clause.col, None, value)
      Ne => append_condition(filter, clause.col, Some("$ne"), value)
      Gt => append_condition(filter, clause.col, Some("$gt"), value)
      Lt => append_condition(filter, clause.col, Some("$lt"), value)
      Gte => append_condition(filter, clause.col, Some("$gte"), value)
      Lte => append_condition(filter, clause.col, Some("$lte"), value)
      Like => {
        let regex = match value {
          String(pattern) => pattern.replace_all(old="%", new=".*")
          _ => ""
        }
        append_condition(
          filter,
          clause.col,
          Some("$regex"),
          Json::string(regex),
        )
      }
    }
  }
  filter.to_json()
}

///|
fn sort_doc(order_by : FixedArray[@engine.OrderBy]) -> Json? {
  if order_by.is_empty() {
    return None
  }
  let sort : Map[String, Json] = {}
  for order in order_by {
    match order {
      Asc(col) => sort[col] = Json::number(1.0)
      Desc(col) => sort[col] = Json::number(-1.0)
    }
  }
  Some(sort.to_json())
}

///|
fn document_from_insert(
  columns : FixedArray[String],
  values : FixedArray[@engine.Param],
) -> Json {
  let obj : Map[String, Json] = {}
  let mut i = 0
  while i < columns.length() && i < values.length() {
    obj[columns[i]] = param_to_json(values[i])
    i = i + 1
  }
  obj.to_json()
}

///|
fn documents_from_insert(
  columns : FixedArray[String],
  values : FixedArray[@engine.Param],
  rows : FixedArray[FixedArray[@engine.Param]],
) -> FixedArray[Json] {
  if !rows.is_empty() {
    rows.map(row => document_from_insert(columns, row))
  } else {
    [document_from_insert(columns, values)]
  }
}

///|
fn document_from_sets(sets : FixedArray[@engine.Set]) -> Json {
  let obj : Map[String, Json] = {}
  for set_ in sets {
    obj[set_.col] = param_to_json(set_.value)
  }
  obj.to_json()
}

///|
fn normalize_rows(
  rows : Array[Json],
  strip_internal_id? : Bool = true,
) -> FixedArray[Json] {
  let out : Array[Json] = []
  for row in rows {
    match row {
      Object(obj) if strip_internal_id => {
        let next = obj.copy()
        ignore(next.remove("_id"))
        out.push(next.to_json())
      }
      _ => out.push(row)
    }
  }
  FixedArray::from_array(out)
}

///|
fn json_to_int64(value : Json) -> Int64? {
  match value {
    String(text) => Some(@strconv.parse_int64(text)) catch { _ => None }
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Some(@strconv.parse_int64(n.to_int().to_string())) catch {
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn extract_cursor_info(
  doc : Json,
  strip_internal_id? : Bool = true,
) -> (FixedArray[Json], Int64)? {
  match doc {
    { "cursor": { "firstBatch": Array(rows), "id": id_json, .. }, .. } =>
      if json_to_int64(id_json) is Some(cursor_id) {
        Some((normalize_rows(rows, strip_internal_id~), cursor_id))
      } else {
        None
      }
    { "cursor": { "nextBatch": Array(rows), "id": id_json, .. }, .. } =>
      if json_to_int64(id_json) is Some(cursor_id) {
        Some((normalize_rows(rows, strip_internal_id~), cursor_id))
      } else {
        None
      }
    _ => None
  }
}

///|
fn extract_count(doc : Json) -> Int? {
  match doc {
    { "n": Number(n, ..), .. } =>
      if n.to_int().to_double() == n {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}

///|
async fn find_docs(
  engine : MongoDBEngine,
  table : String,
  filter : Json,
  select? : String = "*",
  order_by? : FixedArray[@engine.OrderBy] = [],
  limit? : Int? = None,
  offset? : Int? = None,
) -> Result[FixedArray[Json], String] {
  let batch_size = match limit {
    Some(n) if n > 0 && n < 100 => n
    _ => 100
  }
  let cmd : Map[String, Json] = {}
  cmd["find"] = Json::string(table)
  cmd["filter"] = filter
  if projection_doc(select) is Some(projection) {
    cmd["projection"] = projection
  }
  if sort_doc(order_by) is Some(sort) {
    cmd["sort"] = sort
  }
  cmd["batchSize"] = Json::number(batch_size.to_double())
  if limit is Some(n) {
    cmd["limit"] = Json::number(n.to_double())
  }
  if offset is Some(n) {
    cmd["skip"] = Json::number(n.to_double())
  }
  let reply = run_command(engine, cmd.to_json())
  match reply {
    Ok(doc) =>
      match extract_cursor_info(doc) {
        Some((rows, cursor_id)) => {
          let all_rows : Array[Json] = []
          for row in rows {
            all_rows.push(row)
          }
          let mut cursor_id = cursor_id
          while cursor_id != 0 {
            let next_batch_size = match limit {
              Some(n) => {
                let remaining = n - all_rows.length()
                if remaining <= 0 {
                  0
                } else if remaining < batch_size {
                  remaining
                } else {
                  batch_size
                }
              }
              None => batch_size
            }
            if next_batch_size == 0 {
              break
            }
            let next_reply = run_command_bson(
              engine,
              encode_getmore_command(engine, cursor_id, table, next_batch_size),
            )
            match next_reply {
              Ok(next_doc) =>
                match extract_cursor_info(next_doc) {
                  Some((next_rows, next_cursor_id)) => {
                    for row in next_rows {
                      all_rows.push(row)
                    }
                    cursor_id = next_cursor_id
                  }
                  None => return Err("mongodb cursor nextBatch missing")
                }
              Err(err) => return Err(err)
            }
          }
          Ok(FixedArray::from_array(all_rows))
        }
        None => Err("mongodb cursor batch missing")
      }
    Err(err) => Err(err)
  }
}

///|
async fn collect_cursor_rows(
  engine : MongoDBEngine,
  collection : String,
  initial : Json,
  limit? : Int? = None,
) -> Result[FixedArray[Json], String] {
  let batch_size = match limit {
    Some(n) if n > 0 && n < 100 => n
    _ => 100
  }
  match extract_cursor_info(initial, strip_internal_id=false) {
    Some((first_batch, cursor_id)) => {
      let rows : Array[Json] = []
      for row in first_batch {
        rows.push(row)
      }
      let mut next_cursor = cursor_id
      while next_cursor != 0L {
        let next_batch_size = match limit {
          Some(n) => {
            let remaining = n - rows.length()
            if remaining <= 0 {
              next_cursor = 0L
              0
            } else if remaining < batch_size {
              remaining
            } else {
              batch_size
            }
          }
          None => batch_size
        }
        if next_cursor == 0L || next_batch_size <= 0 {
          next_cursor = 0L
        } else {
          let next_reply = run_command_bson(
            engine,
            encode_getmore_command(
              engine, next_cursor, collection, next_batch_size,
            ),
          )
          match next_reply {
            Ok(next_doc) =>
              match extract_cursor_info(next_doc, strip_internal_id=false) {
                Some((batch, next_id)) => {
                  for row in batch {
                    rows.push(row)
                  }
                  next_cursor = next_id
                }
                None => return Err("mongodb invalid getMore response")
              }
            Err(err) => return Err(err)
          }
        }
      }
      let final_rows = match limit {
        Some(n) if n >= 0 && rows.length() > n =>
          FixedArray::from_iter(rows.iter().take(n))
        _ => FixedArray::from_array(rows)
      }
      Ok(final_rows)
    }
    None => Err("mongodb invalid cursor response")
  }
}

///|
async fn find_docs_raw(
  engine : MongoDBEngine,
  collection : String,
  filter : Json,
  projection? : Json? = None,
  sort? : Json? = None,
  limit? : Int? = None,
  skip? : Int? = None,
) -> Result[FixedArray[Json], String] {
  let batch_size = match limit {
    Some(n) if n > 0 && n < 100 => n
    _ => 100
  }
  let cmd : Map[String, Json] = {}
  cmd["find"] = Json::string(collection)
  cmd["filter"] = filter
  if projection is Some(projection) {
    cmd["projection"] = projection
  }
  if sort is Some(sort) {
    cmd["sort"] = sort
  }
  if limit is Some(n) && n > 0 {
    cmd["limit"] = Json::number(n.to_double())
    cmd["batchSize"] = Json::number(batch_size.to_double())
  }
  if skip is Some(n) && n > 0 {
    cmd["skip"] = Json::number(n.to_double())
  }
  match run_command(engine, cmd.to_json()) {
    Ok(doc) => collect_cursor_rows(engine, collection, doc, limit~)
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::run_command_json(
  self : MongoDBEngine,
  command : Json,
) -> Result[Json, String] {
  run_command(self, command)
}

///|
pub async fn MongoDBEngine::find(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  projection? : Json? = None,
  sort? : Json? = None,
  limit? : Int? = None,
  skip? : Int? = None,
) -> Result[FixedArray[Json], String] {
  find_docs_raw(self, collection, filter, projection~, sort~, limit~, skip~)
}

///|
pub async fn MongoDBEngine::find_one(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  projection? : Json? = None,
  sort? : Json? = None,
) -> Result[Json?, String] {
  match
    find_docs_raw(self, collection, filter, projection~, sort~, limit=Some(1)) {
    Ok(rows) => if rows.is_empty() { Ok(None) } else { Ok(Some(rows[0])) }
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::insert_one(
  self : MongoDBEngine,
  collection : String,
  document : Json,
) -> Result[Json, String] {
  let cmd : Json = { "insert": collection, "documents": [document] }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::insert_many(
  self : MongoDBEngine,
  collection : String,
  documents : FixedArray[Json],
  ordered? : Bool = true,
) -> Result[Json, String] {
  let cmd : Json = {
    "insert": collection,
    "documents": documents,
    "ordered": ordered,
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::update_one(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> Result[Json, String] {
  let cmd : Json = {
    "update": collection,
    "updates": [{ "q": filter, "u": update, "upsert": upsert, "multi": false }],
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::update_many(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  update : Json,
  upsert? : Bool = false,
) -> Result[Json, String] {
  let cmd : Json = {
    "update": collection,
    "updates": [{ "q": filter, "u": update, "upsert": upsert, "multi": true }],
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::replace_one(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  replacement : Json,
  upsert? : Bool = false,
) -> Result[Json, String] {
  let cmd : Json = {
    "update": collection,
    "updates": [
      { "q": filter, "u": replacement, "upsert": upsert, "multi": false },
    ],
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::delete_one(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
) -> Result[Json, String] {
  let cmd : Json = {
    "delete": collection,
    "deletes": [{ "q": filter, "limit": 1 }],
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::delete_many(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
) -> Result[Json, String] {
  let cmd : Json = {
    "delete": collection,
    "deletes": [{ "q": filter, "limit": 0 }],
  }
  run_command(self, cmd)
}

///|
pub async fn MongoDBEngine::aggregate(
  self : MongoDBEngine,
  collection : String,
  pipeline : FixedArray[Json],
  allow_disk_use? : Bool = false,
  limit? : Int? = None,
) -> Result[FixedArray[Json], String] {
  let batch_size = match limit {
    Some(n) if n > 0 && n < 100 => n
    _ => 100
  }
  let cursor = if limit is Some(n) && n > 0 {
    { "batchSize": batch_size }
  } else {
    {}
  }
  let cmd : Json = {
    "aggregate": collection,
    "pipeline": pipeline,
    "cursor": cursor,
    "allowDiskUse": allow_disk_use,
  }
  match run_command(self, cmd) {
    Ok(doc) => collect_cursor_rows(self, collection, doc, limit~)
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::count_documents(
  self : MongoDBEngine,
  collection : String,
  filter? : Json = {},
) -> Result[Int, String] {
  match run_command(self, { "count": collection, "query": filter }) {
    Ok(doc) =>
      match extract_count(doc) {
        Some(n) => Ok(n)
        None => Err("mongodb invalid count response")
      }
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::distinct(
  self : MongoDBEngine,
  collection : String,
  field : String,
  filter? : Json = {},
) -> Result[FixedArray[Json], String] {
  match
    run_command(self, { "distinct": collection, "key": field, "query": filter }) {
    Ok({ "values": Array(values), .. }) => Ok(FixedArray::from_array(values))
    Ok(_) => Err("mongodb invalid distinct response")
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::find_one_and_update(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  update : Json,
  return_new? : Bool = true,
  upsert? : Bool = false,
) -> Result[Json?, String] {
  let cmd : Json = {
    "findAndModify": collection,
    "query": filter,
    "update": update,
    "new": return_new,
    "upsert": upsert,
  }
  match run_command(self, cmd) {
    Ok({ "value": Null, .. }) => Ok(None)
    Ok({ "value": value, .. }) => Ok(Some(value))
    Ok(_) => Err("mongodb invalid findAndModify response")
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::find_one_and_delete(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
) -> Result[Json?, String] {
  let cmd : Json = {
    "findAndModify": collection,
    "query": filter,
    "remove": true,
  }
  match run_command(self, cmd) {
    Ok({ "value": Null, .. }) => Ok(None)
    Ok({ "value": value, .. }) => Ok(Some(value))
    Ok(_) => Err("mongodb invalid findAndModify response")
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::find_one_and_replace(
  self : MongoDBEngine,
  collection : String,
  filter : Json,
  replacement : Json,
  return_new? : Bool = true,
  upsert? : Bool = false,
) -> Result[Json?, String] {
  let cmd : Json = {
    "findAndModify": collection,
    "query": filter,
    "update": replacement,
    "new": return_new,
    "upsert": upsert,
  }
  match run_command(self, cmd) {
    Ok({ "value": Null, .. }) => Ok(None)
    Ok({ "value": value, .. }) => Ok(Some(value))
    Ok(_) => Err("mongodb invalid findAndModify response")
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::estimated_document_count(
  self : MongoDBEngine,
  collection : String,
) -> Result[Int, String] {
  match run_command(self, { "count": collection }) {
    Ok(doc) =>
      match extract_count(doc) {
        Some(n) => Ok(n)
        None => Err("mongodb invalid count response")
      }
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::drop(
  self : MongoDBEngine,
  collection : String,
) -> Result[Json, String] {
  run_command(self, { "drop": collection })
}

///|
pub async fn MongoDBEngine::create_index(
  self : MongoDBEngine,
  collection : String,
  keys : Json,
  name? : String? = None,
  unique? : Bool = false,
  sparse? : Bool = false,
) -> Result[Json, String] {
  let spec : Map[String, Json] = {
    "key": keys,
    "unique": unique.to_json(),
    "sparse": sparse.to_json(),
  }
  if name is Some(name) {
    spec["name"] = Json::string(name)
  }
  run_command(self, { "createIndexes": collection, "indexes": [spec] })
}

///|
pub async fn MongoDBEngine::create_indexes(
  self : MongoDBEngine,
  collection : String,
  indexes : FixedArray[Json],
) -> Result[Json, String] {
  run_command(self, { "createIndexes": collection, "indexes": indexes })
}

///|
pub async fn MongoDBEngine::list_indexes(
  self : MongoDBEngine,
  collection : String,
) -> Result[FixedArray[Json], String] {
  match run_command(self, { "listIndexes": collection }) {
    Ok(doc) => collect_cursor_rows(self, collection, doc)
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::list_index_names(
  self : MongoDBEngine,
  collection : String,
) -> Result[FixedArray[String], String] {
  match self.list_indexes(collection) {
    Ok(indexes) => {
      let names : Array[String] = []
      for index in indexes {
        if index is { "name": String(name), .. } {
          names.push(name)
        }
      }
      Ok(FixedArray::from_array(names))
    }
    Err(err) => Err(err)
  }
}

///|
pub async fn MongoDBEngine::drop_index(
  self : MongoDBEngine,
  collection : String,
  name : String,
) -> Result[Json, String] {
  run_command(self, { "dropIndexes": collection, "index": name })
}

///|
pub async fn MongoDBEngine::drop_indexes(
  self : MongoDBEngine,
  collection : String,
) -> Result[Json, String] {
  run_command(self, { "dropIndexes": collection, "index": "*" })
}

///|
pub async fn MongoDBEngine::create_search_index(
  self : MongoDBEngine,
  collection : String,
  name : String,
  definition : Json,
) -> Result[Json, String] {
  run_command(self, {
    "createSearchIndexes": collection,
    "indexes": [{ "name": name, "definition": definition }],
  })
}

///|
pub async fn MongoDBEngine::create_search_indexes(
  self : MongoDBEngine,
  collection : String,
  indexes : FixedArray[Json],
) -> Result[Json, String] {
  run_command(self, { "createSearchIndexes": collection, "indexes": indexes })
}

///|
pub async fn MongoDBEngine::list_search_indexes(
  self : MongoDBEngine,
  collection : String,
  name? : String? = None,
) -> Result[FixedArray[Json], String] {
  let stage = if name is Some(name) {
    { "$listSearchIndexes": { "name": name } }
  } else {
    { "$listSearchIndexes": {} }
  }
  self.aggregate(collection, [stage])
}

///|
pub async fn MongoDBEngine::update_search_index(
  self : MongoDBEngine,
  collection : String,
  name : String,
  definition : Json,
) -> Result[Json, String] {
  run_command(self, {
    "updateSearchIndex": collection,
    "name": name,
    "definition": definition,
  })
}

///|
pub async fn MongoDBEngine::drop_search_index(
  self : MongoDBEngine,
  collection : String,
  name : String,
) -> Result[Json, String] {
  run_command(self, { "dropSearchIndex": collection, "name": name })
}

///|
fn bulk_bool_option(
  body : Map[String, Json],
  key : String,
  default : Bool,
) -> Bool {
  match body.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
pub async fn MongoDBEngine::bulk_write(
  self : MongoDBEngine,
  collection : String,
  operations : FixedArray[Json],
  ordered? : Bool = true,
) -> Result[FixedArray[Json], String] {
  let out : Array[Json] = []
  let mut i = 0
  while i < operations.length() {
    let op = operations[i]
    let result : Result[Json, String] = match op {
      { "insertOne": Object(body), .. } =>
        match body.get("document") {
          Some(document) => self.insert_one(collection, document)
          None =>
            Err(
              "mongodb bulk_write insertOne missing document at index " +
              i.to_string(),
            )
        }
      { "updateOne": Object(body), .. } =>
        match (body.get("filter"), body.get("update")) {
          (Some(filter), Some(update)) =>
            self.update_one(
              collection,
              filter,
              update,
              upsert=bulk_bool_option(body, "upsert", false),
            )
          _ =>
            Err(
              "mongodb bulk_write updateOne missing filter/update at index " +
              i.to_string(),
            )
        }
      { "updateMany": Object(body), .. } =>
        match (body.get("filter"), body.get("update")) {
          (Some(filter), Some(update)) =>
            self.update_many(
              collection,
              filter,
              update,
              upsert=bulk_bool_option(body, "upsert", false),
            )
          _ =>
            Err(
              "mongodb bulk_write updateMany missing filter/update at index " +
              i.to_string(),
            )
        }
      { "replaceOne": Object(body), .. } =>
        match (body.get("filter"), body.get("replacement")) {
          (Some(filter), Some(replacement)) =>
            self.replace_one(
              collection,
              filter,
              replacement,
              upsert=bulk_bool_option(body, "upsert", false),
            )
          _ =>
            Err(
              "mongodb bulk_write replaceOne missing filter/replacement at index " +
              i.to_string(),
            )
        }
      { "deleteOne": Object(body), .. } =>
        match body.get("filter") {
          Some(filter) => self.delete_one(collection, filter)
          None =>
            Err(
              "mongodb bulk_write deleteOne missing filter at index " +
              i.to_string(),
            )
        }
      { "deleteMany": Object(body), .. } =>
        match body.get("filter") {
          Some(filter) => self.delete_many(collection, filter)
          None =>
            Err(
              "mongodb bulk_write deleteMany missing filter at index " +
              i.to_string(),
            )
        }
      _ =>
        Err(
          "mongodb bulk_write unsupported operation at index " + i.to_string(),
        )
    }
    match result {
      Ok(reply) => out.push(reply)
      Err(err) =>
        if ordered {
          return Err(err)
        } else {
          out.push({ "error": err, "index": i.to_json() })
        }
    }
    i = i + 1
  }
  Ok(FixedArray::from_array(out))
}

///|
async fn run_select(
  engine : MongoDBEngine,
  stmt : @engine.SelectStatement,
) -> @engine.QueryResult {
  if !stmt.joins.is_empty() {
    return fail_result("mongodb join is not supported")
  }
  let filter = where_to_filter(stmt.where_)
  if stmt.select.trim() == "count(*)" {
    let reply = run_command(engine, { "count": stmt.from, "query": filter })
    return match reply {
      Ok(doc) =>
        match extract_count(doc) {
          Some(n) => ok_result(1, [Json::number(n.to_double())])
          None => fail_result("mongodb count reply missing n")
        }
      Err(err) => fail_result(err)
    }
  }
  let rows = find_docs(
    engine,
    stmt.from,
    filter,
    select=stmt.select,
    order_by=stmt.order_by,
    limit=stmt.limit,
    offset=stmt.offset,
  )
  match rows {
    Ok(items) => ok_result(items.length(), items)
    Err(err) => fail_result(err)
  }
}

///|
async fn run_insert(
  engine : MongoDBEngine,
  stmt : @engine.InsertStatement,
) -> @engine.QueryResult {
  let docs = documents_from_insert(stmt.columns, stmt.values, stmt.rows)
  let reply = run_command(engine, {
    "insert": stmt.into,
    "documents": docs,
    "ordered": true,
  })
  match reply {
    Ok(doc) =>
      match extract_count(doc) {
        Some(n) => ok_result(n, [])
        None => ok_result(1, [])
      }
    Err(err) => fail_result(err)
  }
}

///|
fn upsert_filter(stmt : @engine.UpsertStatement, doc : Json) -> Json {
  let filter : Map[String, Json] = {}
  match doc {
    Object(obj) =>
      if !stmt.conflict_target.is_empty() {
        for key in stmt.conflict_target {
          if obj.get(key) is Some(value) {
            filter[key] = value
          }
        }
      } else if obj.get("id") is Some(id) {
        filter["id"] = id
      } else {
        for key in obj.keys() {
          if obj.get(key) is Some(value) {
            filter[key] = value
          }
        }
      }
    _ => ()
  }
  filter.to_json()
}

///|
async fn run_upsert(
  engine : MongoDBEngine,
  stmt : @engine.UpsertStatement,
) -> @engine.QueryResult {
  let set_doc = document_from_sets(stmt.sets)
  let filter = upsert_filter(stmt, set_doc)
  let reply = run_command(engine, {
    "update": stmt.table,
    "updates": [
      { "q": filter, "u": { "$set": set_doc }, "upsert": true, "multi": false },
    ],
    "ordered": true,
  })
  match reply {
    Ok(_) =>
      match find_docs(engine, stmt.table, filter, limit=Some(1)) {
        Ok(rows) =>
          if rows is [row, ..] {
            ok_result(1, [row])
          } else {
            ok_result(0, [])
          }
        Err(err) => fail_result(err)
      }
    Err(err) => fail_result(err)
  }
}

///|
async fn run_update(
  engine : MongoDBEngine,
  stmt : @engine.UpdateStatement,
) -> @engine.QueryResult {
  let reply = run_command(engine, {
    "update": stmt.table,
    "updates": [
      {
        "q": where_to_filter(stmt.where_),
        "u": { "$set": document_from_sets(stmt.sets) },
        "multi": true,
      },
    ],
    "ordered": true,
  })
  match reply {
    Ok(doc) =>
      match extract_count(doc) {
        Some(n) => ok_result(n, [])
        None => ok_result(0, [])
      }
    Err(err) => fail_result(err)
  }
}

///|
async fn run_delete(
  engine : MongoDBEngine,
  stmt : @engine.DeleteStatement,
) -> @engine.QueryResult {
  let reply = run_command(engine, {
    "delete": stmt.from,
    "deletes": [{ "q": where_to_filter(stmt.where_), "limit": 0 }],
    "ordered": true,
  })
  match reply {
    Ok(doc) =>
      match extract_count(doc) {
        Some(n) => ok_result(n, [])
        None => ok_result(0, [])
      }
    Err(err) => fail_result(err)
  }
}

///|
fn parse_command(sql : String) -> Json? {
  Some(@json5.parse(sql)) catch {
    _ => None
  }
}

///|
fn decode_json_string_array(value : Json) -> FixedArray[String]? {
  guard value is Array(items) else { return None }
  let out : Array[String] = []
  for item in items {
    guard item is String(text) else { return None }
    out.push(text)
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_param_array(value : Json) -> FixedArray[@engine.Param]? {
  guard value is Array(items) else { return None }
  let out : Array[@engine.Param] = []
  for item in items {
    out.push(json_to_param(item))
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_param_matrix(
  value : Json,
) -> FixedArray[FixedArray[@engine.Param]]? {
  guard value is Array(items) else { return None }
  let out : Array[FixedArray[@engine.Param]] = []
  for item in items {
    guard item is Array(row_items) else { return None }
    let row : Array[@engine.Param] = []
    for value in row_items {
      row.push(json_to_param(value))
    }
    out.push(FixedArray::from_array(row))
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_set_array(value : Json) -> FixedArray[@engine.Set]? {
  guard value is Array(items) else { return None }
  let out : Array[@engine.Set] = []
  for item in items {
    guard item is { "col": String(col), "value": set_value, .. } else {
      return None
    }
    out.push({ col, value: json_to_param(set_value) })
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_where_array(value : Json) -> FixedArray[@engine.Where]? {
  guard value is Array(items) else { return None }
  let out : Array[@engine.Where] = []
  for item in items {
    guard item
      is { "col": String(col), "value": where_value, "ty": String(ty), .. } else {
      return None
    }
    let where_ty = match ty {
      "eq" => Some(@engine.WhereType::Eq)
      "ne" => Some(@engine.WhereType::Ne)
      "gt" => Some(@engine.WhereType::Gt)
      "lt" => Some(@engine.WhereType::Lt)
      "gte" => Some(@engine.WhereType::Gte)
      "lte" => Some(@engine.WhereType::Lte)
      "like" => Some(@engine.WhereType::Like)
      _ => None
    }
    guard where_ty is Some(where_ty) else { return None }
    out.push({ col, value: json_to_param(where_value), ty: where_ty })
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_order_array(value : Json) -> FixedArray[@engine.OrderBy]? {
  guard value is Array(items) else { return None }
  let out : Array[@engine.OrderBy] = []
  for item in items {
    guard item is { "col": String(col), "desc": desc, .. } else { return None }
    let flag = match desc {
      True => Some(true)
      False => Some(false)
      _ => None
    }
    guard flag is Some(flag) else { return None }
    out.push(if flag { Desc(col) } else { Asc(col) })
  }
  Some(FixedArray::from_array(out))
}

///|
fn decode_json_int_opt(value : Json) -> (Bool, Int?) {
  match value {
    Null => (true, None)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        (true, Some(n.to_int()))
      } else {
        (false, None)
      }
    _ => (false, None)
  }
}

///|
fn decode_statement_command(cmd : Json) -> @engine.Statement? {
  guard cmd is { "op": String(op), .. } else { return None }
  match op {
    "select" => {
      guard cmd
        is {
          "select": String(select),
          "from": String(from),
          "joins": joins_json,
          "where": where_json,
          "order_by": order_json,
          "limit": limit_json,
          "offset": offset_json,
          ..
        } else {
        return None
      }
      guard decode_json_string_array(joins_json) is Some(joins) else {
        return None
      }
      guard decode_json_where_array(where_json) is Some(where_) else {
        return None
      }
      guard decode_json_order_array(order_json) is Some(order_by) else {
        return None
      }
      let (limit_ok, limit) = decode_json_int_opt(limit_json)
      if !limit_ok {
        return None
      }
      let (offset_ok, offset) = decode_json_int_opt(offset_json)
      if !offset_ok {
        return None
      }
      Some(Select({ select, from, joins, where_, order_by, limit, offset }))
    }
    "insert" => {
      guard cmd
        is {
          "into": String(into),
          "columns": columns_json,
          "values": values_json,
          ..
        } else {
        return None
      }
      guard decode_json_string_array(columns_json) is Some(columns) else {
        return None
      }
      guard decode_json_param_array(values_json) is Some(values) else {
        return None
      }
      let rows = match cmd {
        { "rows": rows_json, .. } =>
          match decode_json_param_matrix(rows_json) {
            Some(rows) => rows
            None => return None
          }
        _ => []
      }
      Some(Insert({ into, columns, values, rows }))
    }
    "upsert" => {
      guard cmd
        is {
          "table": String(table),
          "sets": sets_json,
          "conflict_target": conflict_json,
          "update_sets": update_sets_json,
          ..
        } else {
        return None
      }
      guard decode_json_set_array(sets_json) is Some(sets) else { return None }
      guard decode_json_string_array(conflict_json) is Some(conflict_target) else {
        return None
      }
      guard decode_json_set_array(update_sets_json) is Some(update_sets) else {
        return None
      }
      Some(Upsert({ table, sets, conflict_target, update_sets }))
    }
    "update" => {
      guard cmd
        is {
          "table": String(table),
          "sets": sets_json,
          "where": where_json,
          ..
        } else {
        return None
      }
      guard decode_json_set_array(sets_json) is Some(sets) else { return None }
      guard decode_json_where_array(where_json) is Some(where_) else {
        return None
      }
      Some(Update({ table, sets, where_ }))
    }
    "delete" => {
      guard cmd is { "from": String(from), "where": where_json, .. } else {
        return None
      }
      guard decode_json_where_array(where_json) is Some(where_) else {
        return None
      }
      Some(Delete({ from, where_ }))
    }
    _ => None
  }
}

///|
fn tx_noop() -> @engine.QueryResult {
  ok_result(0, [])
}

///|
pub impl @engine.Engine for MongoDBEngine with migrate_table(self, table_schema) {
  if table_schema is { "name": String(name), .. } {
    let reply = run_command(self, { "create": name })
    match reply {
      Ok(_) => ok_result(0, [])
      Err(err) if err.contains("already exists") => ok_result(0, [])
      Err(err) => fail_result(err)
    }
  } else {
    fail_result("invalid table schema")
  }
}

///|
pub impl @engine.Engine for MongoDBEngine with exec(self, query : @engine.Query) {
  let stmt = match query {
    @engine.Statement(stmt) => stmt
    @engine.Raw(sql, _params) => {
      guard parse_command(sql) is Some(cmd) else {
        return fail_result("mongodb_engine expects JSON commands")
      }
      match decode_statement_command(cmd) {
        Some(stmt) => stmt
        None => return fail_result("mongodb_engine command decode failed")
      }
    }
    @engine.Tx(_) => return tx_noop()
  }
  match stmt {
    Select(select_stmt) => run_select(self, select_stmt)
    Insert(insert_stmt) => run_insert(self, insert_stmt)
    Upsert(upsert_stmt) => run_upsert(self, upsert_stmt)
    Update(update_stmt) => run_update(self, update_stmt)
    Delete(delete_stmt) => run_delete(self, delete_stmt)
  }
}

///|
pub impl @engine.Engine for MongoDBEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) {
  self.exec(@engine.Raw(sql, params))
}

///|
pub impl @engine.Engine for MongoDBEngine with close(self) -> Unit {
  self.pool.close(close_tcp)
}
