///|
pub struct PgSQLEngine {
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
fn parse_pg_dsn(dsn : String) -> PgSQLEngine? {
  let dsn = if dsn.strip_prefix("jdbc:") is Some(rest) {
    rest.to_string()
  } else {
    dsn
  }
  let raw = if dsn.strip_prefix("postgres://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("postgresql://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("gaussdb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("cockroachdb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("opengauss://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("mogdb://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("kingbase://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("kingbase8://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("highgo://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("vastbase://") is Some(rest) {
    rest.to_string()
  } else if dsn.strip_prefix("ivorysql://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut database = "postgres"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string()
    database = main[i + 1:].to_string()
  }

  let mut user = "postgres"
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

  let (host, port) = parse_host_port(host_port, 5432)
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
    @engine.Bytes(v) => "decode('\{@engine.bytes_to_hex(v)}', 'hex')"
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
  h.write_uint_be((payload.length() + 4).reinterpret_as_uint())
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
  let protocol_v3 : UInt = 196608
  body.write_uint_be(protocol_v3) // protocol 3.0
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
  len_buf.write_uint_be((data.length() + 4).reinterpret_as_uint())
  conn.write(len_buf.to_bytes()) catch {
    _ => return false
  }
  conn.write(data) catch {
    _ => return false
  }
  true
}

///|
async fn open_pg_connection(cfg : PgSQLEngine) -> Result[@socket.Tcp, String] {
  let conn = @socket.Tcp::connect_to_host(cfg.host, port=cfg.port) catch {
    _ => return Err("pgsql connect failed")
  }

  if !(send_startup(conn, cfg) catch { _ => false }) {
    conn.close()
    return Err("pgsql startup write failed")
  }

  let mut startup_done = false
  while !startup_done {
    let msg = read_message(conn) catch { _ => None }
    if msg is None {
      conn.close()
      return Err("pgsql startup read failed")
    }
    let (tag, payload) = msg.unwrap()
    if tag == b'R' {
      if payload.length() < 4 {
        conn.close()
        return Err("pgsql bad auth message")
      }
      let kind = match payload[:4] {
        [u8be(b0), u8be(b1), u8be(b2), u8be(b3)] =>
          (b0.reinterpret_as_int() << 24) |
          (b1.reinterpret_as_int() << 16) |
          (b2.reinterpret_as_int() << 8) |
          b3.reinterpret_as_int()
        _ => {
          conn.close()
          return Err("pgsql bad auth message")
        }
      }
      if kind == 0 {
        ()
      } else if kind == 3 {
        let p = @buffer.new()
        p.write_bytes(@utf8.encode(cfg.password))
        p.write_byte(0)
        if !(write_tagged(conn, b'p', p.to_bytes()) catch { _ => false }) {
          conn.close()
          return Err("pgsql cleartext auth write failed")
        }
      } else if kind == 5 {
        if payload.length() < 8 {
          conn.close()
          return Err("pgsql bad md5 auth payload")
        }
        let salt = payload[4:8].to_bytes()
        let md5_pass = pg_md5_password(cfg.user, cfg.password, salt)
        let p = @buffer.new()
        p.write_bytes(@utf8.encode(md5_pass))
        p.write_byte(0)
        if !(write_tagged(conn, b'p', p.to_bytes()) catch { _ => false }) {
          conn.close()
          return Err("pgsql md5 auth write failed")
        }
      } else {
        conn.close()
        return Err("unsupported pg auth kind: " + kind.to_string())
      }
    } else if tag == b'E' {
      conn.close()
      return Err(parse_error_response(payload))
    } else if tag == b'Z' {
      startup_done = true
    } else {
      ()
    }
  }

  Ok(conn)
}

///|
fn close_pg_tcp(conn : @socket.Tcp) -> Unit {
  conn.close()
}

///|
async fn pg_query_on_conn(
  conn : @socket.Tcp,
  sql : String,
) -> (@engine.QueryResult, Bool) {
  let q = @buffer.new()
  q.write_bytes(@utf8.encode(sql))
  q.write_byte(0)
  if !(write_tagged(conn, b'Q', q.to_bytes()) catch { _ => false }) {
    return (fail("pgsql query write failed"), false)
  }

  let cols : Array[String] = []
  let rows : Array[Json] = []
  let mut rows_affected = 0
  let mut done = false

  while !done {
    let msg = read_message(conn) catch { _ => None }
    if msg is None {
      return (fail("pgsql query read failed"), false)
    }
    let (tag, payload) = msg.unwrap()
    if tag == b'T' {
      if payload.length() < 2 {
        return (fail("pgsql bad row-description"), false)
      }
      cols.clear()
      let count = match payload[:2] {
        [u8be(b0), u8be(b1)] =>
          (b0.reinterpret_as_int() << 8) | b1.reinterpret_as_int()
        _ => return (fail("pgsql bad row-description"), false)
      }
      let mut pos = 2
      let mut i = 0
      while i < count {
        if cstring(payload, pos) is Some((name, next)) {
          cols.push(name)
          pos = next + 18
          if pos > payload.length() {
            return (fail("pgsql truncated row-description"), false)
          }
        } else {
          return (fail("pgsql bad column name"), false)
        }
        i = i + 1
      }
    } else if tag == b'D' {
      if payload.length() < 2 {
        return (fail("pgsql bad data-row"), false)
      }
      let count = match payload[:2] {
        [u8be(b0), u8be(b1)] =>
          (b0.reinterpret_as_int() << 8) | b1.reinterpret_as_int()
        _ => return (fail("pgsql bad data-row"), false)
      }
      let obj : Map[String, Json] = {}
      let mut pos = 2
      let mut i = 0
      while i < count {
        if pos + 4 > payload.length() {
          return (fail("pgsql truncated data-row"), false)
        }
        let len = match payload[pos:pos + 4] {
          [u8be(b0), u8be(b1), u8be(b2), u8be(b3)] =>
            (b0.reinterpret_as_int() << 24) |
            (b1.reinterpret_as_int() << 16) |
            (b2.reinterpret_as_int() << 8) |
            b3.reinterpret_as_int()
          _ => return (fail("pgsql truncated data-row"), false)
        }
        pos = pos + 4
        let key = if i < cols.length() { cols[i] } else { "c" + i.to_string() }
        if len < 0 {
          obj[key] = Json::null()
        } else {
          if pos + len > payload.length() {
            return (fail("pgsql truncated data value"), false)
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
      return (fail(parse_error_response(payload)), true)
    } else if tag == b'Z' {
      done = true
    } else {
      ()
    }
  }

  (
    { ok: true, rows_affected, rows: FixedArray::from_array(rows), error: None },
    true,
  )
}

///|
fn pg_is_tx_begin(sql : String) -> Bool {
  sql.trim() == "BEGIN"
}

///|
fn pg_is_tx_commit(sql : String) -> Bool {
  sql.trim() == "COMMIT"
}

///|
fn pg_is_tx_rollback(sql : String) -> Bool {
  sql.trim() == "ROLLBACK"
}

///|
async fn pg_exec_sql(engine : PgSQLEngine, sql : String) -> @engine.QueryResult {
  if pg_is_tx_begin(sql) && engine.tx_conn is Some(_) {
    return fail("pgsql transaction already active")
  }
  if pg_is_tx_begin(sql) {
    let conn = match engine.pool.borrow(() => open_pg_connection(engine)) {
      Ok(conn) => conn
      Err(err) => return fail(err)
    }
    let (res, reusable) = pg_query_on_conn(conn, sql)
    if res.ok {
      engine.tx_conn = Some(conn)
    } else {
      engine.pool.release(conn, close_pg_tcp, reusable~)
    }
    return res
  }

  if engine.tx_conn is Some(conn) {
    let (res, reusable) = pg_query_on_conn(conn, sql)
    if pg_is_tx_commit(sql) || pg_is_tx_rollback(sql) {
      engine.tx_conn = None
      engine.pool.release(conn, close_pg_tcp, reusable~)
    } else if !reusable {
      engine.tx_conn = None
      engine.pool.release(conn, close_pg_tcp, reusable=false)
    }
    return res
  }

  let conn = match engine.pool.borrow(() => open_pg_connection(engine)) {
    Ok(conn) => conn
    Err(err) => return fail(err)
  }
  let (res, reusable) = pg_query_on_conn(conn, sql)
  engine.pool.release(conn, close_pg_tcp, reusable~)
  res
}

///|
pub async fn PgSQLEngine::ping(self : PgSQLEngine) -> Bool {
  let res_opt = @async.with_timeout_opt(5000, () => {
    pg_exec_sql(self, "SELECT 1")
  })
  match res_opt {
    Some(res) => res.ok
    None => false
  }
}

///|
fn pg_table_engine_option(
  table_schema : @table.Table,
  key : String,
  default : String,
) -> String {
  for option in table_schema.engine_options {
    if option.key == key {
      return option.value
    }
  }
  default
}

///|
fn pg_column_engine_option(
  column : @table.Column,
  key : String,
  default : String,
) -> String {
  for option in column.engine_options {
    if option.key == key {
      return option.value
    }
  }
  default
}

///|
fn pg_table_name(table_schema : @table.Table) -> String {
  let schema = table_schema.schema.unwrap_or("")
  if schema != "" {
    "\{schema}.\{table_schema.name}"
  } else {
    table_schema.name
  }
}

///|
fn pg_type_from_column_type(column_type : @table.ColumnType) -> String {
  match column_type {
    @table.TinyInt | @table.SmallInt => "SMALLINT"
    @table.MediumInt | @table.Int => "INTEGER"
    @table.BigInt => "BIGINT"
    @table.Float => "REAL"
    @table.Double => "DOUBLE PRECISION"
    @table.Decimal(a0, a1) => "DECIMAL(\{a0}, \{a1})"
    @table.Char(a0) => "CHAR(\{a0})"
    @table.VarChar(a0) => "VARCHAR(\{a0})"
    @table.Text | @table.MediumText | @table.LongText => "TEXT"
    @table.Binary(_)
    | @table.VarBinary(_)
    | @table.Blob
    | @table.MediumBlob
    | @table.LongBlob => "BYTEA"
    @table.Date => "DATE"
    @table.Time => "TIME"
    @table.DateTime | @table.Timestamp => "TIMESTAMP"
    @table.Year => "INTEGER"
    @table.Json => "JSON"
    @table.JsonB => "JSONB"
    @table.Boolean => "BOOLEAN"
  }
}

///|
fn pg_json_storage_type(column : @table.Column, default_jsonb : Bool) -> String {
  match pg_column_engine_option(column, "json.storage", "") {
    "blob" | "bson" => "BYTEA"
    "text" | "string" => "TEXT"
    "json" => "JSON"
    "jsonb" => "JSONB"
    _ => if default_jsonb { "JSONB" } else { "JSON" }
  }
}

///|
fn pg_pk_strategy_default(column : @table.Column) -> String? {
  if !column.primary_key || column.auto_increment {
    return None
  }
  match pg_column_engine_option(column, "pk.strategy", "") {
    "uuid" => Some("gen_random_uuid()")
    _ => None
  }
}

///|
fn pg_column_default_expr(column : @table.Column) -> String? {
  if column.default_value is Some(v) {
    return Some(v)
  }
  pg_pk_strategy_default(column)
}

///|
fn pg_column_def(column : @table.Column) -> String {
  if column.name == "" {
    return ""
  }
  let mut col_type = match column.column_type {
    @table.Json => pg_json_storage_type(column, false)
    @table.JsonB => pg_json_storage_type(column, true)
    _ => pg_type_from_column_type(column.column_type)
  }
  let default_value = pg_column_default_expr(column).unwrap_or("")
  if column.auto_increment {
    col_type = if col_type == "BIGINT" { "BIGSERIAL" } else { "SERIAL" }
  }
  let buf = @buffer.new()
  buf.write_string(column.name)
  buf.write_string(" ")
  buf.write_string(col_type)
  if !column.nullable && !column.auto_increment {
    buf.write_string(" NOT NULL")
  }
  if column.primary_key {
    buf.write_string(" PRIMARY KEY")
  }
  if column.unique {
    buf.write_string(" UNIQUE")
  }
  if default_value != "" {
    buf.write_string(" DEFAULT ")
    buf.write_string(default_value)
  }
  buf.to_string()
}

///|
fn pg_fk_def(fk : @table.ForeignKey) -> String {
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
fn pg_create_table_sql(table_schema : @table.Table) -> String {
  if table_schema.name == "" {
    return ""
  }
  let table_name = pg_table_name(table_schema)
  let defs : Array[String] = []
  for column in table_schema.columns {
    let def = pg_column_def(column)
    if def != "" {
      defs.push(def)
    }
  }
  for fk in table_schema.foreign_keys {
    let def = pg_fk_def(fk)
    if def != "" {
      defs.push(def)
    }
  }
  let defs_sql = defs.join(", ")
  let unlogged = pg_table_engine_option(table_schema, "pgsql.unlogged", "") ==
    "true"
  let create_prefix = if table_schema.temporary {
    "CREATE TEMPORARY TABLE"
  } else if unlogged {
    "CREATE UNLOGGED TABLE"
  } else {
    "CREATE TABLE"
  }
  let mut sql = if table_schema.if_not_exists {
    "\{create_prefix} IF NOT EXISTS \{table_name} (\{defs_sql})"
  } else {
    "\{create_prefix} \{table_name} (\{defs_sql})"
  }
  let tablespace = table_schema.tablespace.unwrap_or("")
  if tablespace != "" {
    sql = sql + " TABLESPACE " + tablespace
  }
  let with_clause = pg_table_engine_option(table_schema, "pgsql.with", "")
  if with_clause != "" {
    sql = sql + " WITH (" + with_clause + ")"
  }
  let on_commit = pg_table_engine_option(table_schema, "pgsql.on_commit", "")
  if table_schema.temporary && on_commit != "" {
    sql = sql + " ON COMMIT " + on_commit
  }
  let create_suffix = pg_table_engine_option(table_schema, "create_suffix", "")
  if create_suffix != "" {
    sql = sql + " " + create_suffix
  }
  sql
}

///|
fn pg_comment_sql(table_schema : @table.Table) -> String {
  if table_schema.comment == "" || table_schema.name == "" {
    return ""
  }
  let table_name = pg_table_name(table_schema)
  "COMMENT ON TABLE \{table_name} IS '" +
  table_schema.comment.replace(old="'", new="''") +
  "'"
}

///|
fn pg_index_sqls(table_schema : @table.Table) -> Array[String] {
  if table_schema.name == "" {
    return []
  }
  let table_name = pg_table_name(table_schema)
  let sqls : Array[String] = []
  for idx in table_schema.indexes {
    if idx.name is ("" | "PRIMARY") || idx.columns.length() == 0 {
      continue
    }
    let prefix = if idx.index_type == @table.Unique {
      "CREATE UNIQUE INDEX "
    } else {
      "CREATE INDEX "
    }
    sqls.push(
      prefix +
      idx.name +
      " ON " +
      table_name +
      " (" +
      idx.columns.join(", ") +
      ")",
    )
  }
  sqls
}

///|
fn pg_tx_sql(op : @engine.TxOp) -> String {
  match op {
    @engine.Begin => "BEGIN"
    @engine.Commit => "COMMIT"
    @engine.Rollback => "ROLLBACK"
    @engine.Savepoint(name) => "SAVEPOINT " + name
    @engine.RollbackToSavepoint(name) => "ROLLBACK TO SAVEPOINT " + name
  }
}

///|
pub impl @engine.Engine for PgSQLEngine with exec(self, query : @engine.Query) -> @engine.QueryResult {
  let (sql, params) = match query {
    @engine.Statement(stmt) => pg_render(stmt)
    @engine.Raw(sql, params) => (sql, params)
    @engine.Tx(op) => (pg_tx_sql(op), [])
  }
  let query = inline_sql(sql, params)
  let res_opt = @async.with_timeout_opt(5000, () => pg_exec_sql(self, query))
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
pub impl @engine.Engine for PgSQLEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  self.exec(@engine.Raw(sql, params))
}

///|
pub impl @engine.Engine for PgSQLEngine with migrate_table(
  self,
  table_schema : @table.Table,
) -> @engine.QueryResult {
  let create_sql = pg_create_table_sql(table_schema)
  if create_sql == "" {
    return {
      ok: false,
      rows_affected: 0,
      rows: [],
      error: Some("invalid table schema"),
    }
  }
  let create_res = self.exec(@engine.Raw(create_sql, []))
  if !create_res.ok {
    return create_res
  }
  let comment_sql = pg_comment_sql(table_schema)
  if comment_sql != "" {
    let comment_res = self.exec(@engine.Raw(comment_sql, []))
    if !comment_res.ok {
      return comment_res
    }
  }
  for sql in pg_index_sqls(table_schema) {
    let res = self.exec(@engine.Raw(sql, []))
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub impl @engine.Engine for PgSQLEngine with close(self) -> Unit {
  if self.tx_conn is Some(conn) {
    self.tx_conn = None
    close_pg_tcp(conn)
  }
  self.pool.close(close_pg_tcp)
}
