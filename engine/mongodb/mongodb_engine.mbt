///|
pub(all) struct MongoDBEngine {
  host : String
  port : Int
  database : String
  user : String
  password : String
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
fn parse_host_port(text : String, default_port : Int) -> (String, Int) {
  if text.rev_find(":") is Some(idx) {
    let host = text[:idx].to_string() catch { _ => text }
    let port_text = text[idx + 1:].to_string() catch { _ => "" }
    let port = @strconv.parse_int(port_text) catch { _ => default_port }
    (if host == "" { "127.0.0.1" } else { host }, port)
  } else {
    (if text == "" { "127.0.0.1" } else { text }, default_port)
  }
}

///|
fn parse_mongodb_dsn(dsn : String) -> MongoDBEngine? {
  let raw = if dsn.strip_prefix("mongodb://") is Some(rest) {
    rest.to_string()
  } else {
    return None
  }
  let main = first_part(raw, "?")
  let mut auth_host = main
  let mut database = "test"
  if main.find("/") is Some(i) {
    auth_host = main[:i].to_string() catch { _ => main }
    database = main[i + 1:].to_string() catch { _ => "test" }
  }

  let mut user = ""
  let mut password = ""
  let mut host_port = auth_host
  if auth_host.find("@") is Some(i) {
    let auth = auth_host[:i].to_string() catch { _ => "" }
    host_port = auth_host[i + 1:].to_string() catch { _ => auth_host }
    if auth.find(":") is Some(ci) {
      user = auth[:ci].to_string() catch { _ => "" }
      password = auth[ci + 1:].to_string() catch { _ => "" }
    } else {
      user = auth
    }
  }

  let (host, port) = parse_host_port(host_port, 27017)
  Some({
    host,
    port,
    database: if database == "" {
      "test"
    } else {
      database
    },
    user,
    password,
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
  @async.with_timeout_opt(2000, () => {
    @socket.Tcp::connect_to_host(engine.host, port=engine.port)
  })
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
  command : Json,
) -> Bool {
  let bson = @bson.to_document_bytes(command) catch { _ => return false }
  let body = i32le_bytes(0) + b"\x00" + bson
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
async fn run_command(
  engine : MongoDBEngine,
  command : Json,
) -> Result[Json, String] {
  if engine.user != "" {
    return Err("mongodb auth is not implemented yet")
  }
  let conn = connect_server(engine)
  guard conn is Some(conn) else { return Err("mongodb connect failed") }
  defer conn.close()

  let hello : Json = {
    "hello": Json::number(1.0),
    "$db": Json::string(engine.database),
  }
  if !(write_op_msg(conn, 1, hello) catch { _ => false }) {
    return Err("mongodb hello write failed")
  }
  let hello_res = read_op_msg(conn) catch { _ => None }
  guard hello_res is Some(hello_doc) else {
    return Err("mongodb hello read failed")
  }
  guard command_ok(hello_doc) else {
    return Err(command_failed_message(hello_doc, "mongodb hello failed"))
  }

  let command = match command {
    Object(obj) => {
      let out = obj.copy()
      out["$db"] = Json::string(engine.database)
      out.to_json()
    }
    _ => return Err("mongodb command must be an object")
  }
  if !(write_op_msg(conn, 2, command) catch { _ => false }) {
    return Err("mongodb command write failed")
  }
  let reply = read_op_msg(conn) catch { _ => None }
  guard reply is Some(reply_doc) else {
    return Err("mongodb command read failed")
  }
  if !command_ok(reply_doc) {
    return Err(command_failed_message(reply_doc, "mongodb command failed"))
  }
  Ok(reply_doc)
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
fn document_from_sets(sets : FixedArray[@engine.Set]) -> Json {
  let obj : Map[String, Json] = {}
  for set_ in sets {
    obj[set_.col] = param_to_json(set_.value)
  }
  obj.to_json()
}

///|
fn extract_cursor_batch(doc : Json) -> FixedArray[Json]? {
  match doc {
    { "cursor": { "firstBatch": Array(rows), .. }, .. } => {
      let out : Array[Json] = []
      for row in rows {
        match row {
          Object(obj) => {
            let next = obj.copy()
            ignore(next.remove("_id"))
            out.push(next.to_json())
          }
          _ => out.push(row)
        }
      }
      Some(FixedArray::from_array(out))
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
  let cmd : Map[String, Json] = {}
  cmd["find"] = Json::string(table)
  cmd["filter"] = filter
  if projection_doc(select) is Some(projection) {
    cmd["projection"] = projection
  }
  if sort_doc(order_by) is Some(sort) {
    cmd["sort"] = sort
  }
  if limit is Some(n) {
    cmd["limit"] = Json::number(n.to_double())
    cmd["batchSize"] = Json::number(n.to_double())
  }
  if offset is Some(n) {
    cmd["skip"] = Json::number(n.to_double())
  }
  let reply = run_command(engine, cmd.to_json())
  match reply {
    Ok(doc) =>
      match extract_cursor_batch(doc) {
        Some(rows) => Ok(rows)
        None => Err("mongodb cursor batch missing")
      }
    Err(err) => Err(err)
  }
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
  let doc = document_from_insert(stmt.columns, stmt.values)
  let reply = run_command(engine, {
    "insert": stmt.into,
    "documents": [doc],
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
fn in_filter(field_name : String, values : FixedArray[Json]) -> Json {
  let inner : Map[String, Json] = {}
  inner["$in"] = values.to_json()
  let outer : Map[String, Json] = {}
  outer[field_name] = inner.to_json()
  outer.to_json()
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
fn encode_set_json(set_ : @engine.Set) -> Json {
  { "col": set_.col, "value": param_to_json(set_.value) }
}

///|
fn encode_where_type(ty : @engine.WhereType) -> String {
  match ty {
    Eq => "eq"
    Ne => "ne"
    Gt => "gt"
    Lt => "lt"
    Gte => "gte"
    Lte => "lte"
    Like => "like"
  }
}

///|
fn encode_where_json(where_ : @engine.Where) -> Json {
  {
    "col": where_.col,
    "value": param_to_json(where_.value),
    "ty": encode_where_type(where_.ty),
  }
}

///|
fn encode_order_json(order : @engine.OrderBy) -> Json {
  match order {
    Asc(col) => { "col": col, "desc": false }
    Desc(col) => { "col": col, "desc": true }
  }
}

///|
fn render_command(stmt : @engine.Statement) -> Json {
  match stmt {
    Select(select_stmt) =>
      {
        "op": "select",
        "select": select_stmt.select,
        "from": select_stmt.from,
        "joins": select_stmt.joins,
        "where": select_stmt.where_.map(encode_where_json),
        "order_by": select_stmt.order_by.map(encode_order_json),
        "limit": select_stmt.limit.to_json(),
        "offset": select_stmt.offset.to_json(),
      }
    Insert(insert_stmt) =>
      {
        "op": "insert",
        "into": insert_stmt.into,
        "columns": insert_stmt.columns,
        "values": insert_stmt.values.map(param_to_json),
      }
    Upsert(upsert_stmt) =>
      {
        "op": "upsert",
        "table": upsert_stmt.table,
        "sets": upsert_stmt.sets.map(encode_set_json),
        "conflict_target": upsert_stmt.conflict_target,
        "update_sets": upsert_stmt.update_sets.map(encode_set_json),
      }
    Update(update_stmt) =>
      {
        "op": "update",
        "table": update_stmt.table,
        "sets": update_stmt.sets.map(encode_set_json),
        "where": update_stmt.where_.map(encode_where_json),
      }
    Delete(delete_stmt) =>
      {
        "op": "delete",
        "from": delete_stmt.from,
        "where": delete_stmt.where_.map(encode_where_json),
      }
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
      Some(Insert({ into, columns, values }))
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
pub impl @engine.Engine for MongoDBEngine with render(_self, stmt) {
  (render_command(stmt).stringify(), [])
}

///|
pub impl @engine.Engine for MongoDBEngine with tx_begin_sql(_self) -> String {
  ""
}

///|
pub impl @engine.Engine for MongoDBEngine with tx_commit_sql(_self) -> String {
  ""
}

///|
pub impl @engine.Engine for MongoDBEngine with tx_rollback_sql(_self) -> String {
  ""
}

///|
pub impl @engine.Engine for MongoDBEngine with tx_savepoint_sql(
  _self,
  _name : String,
) -> String {
  ""
}

///|
pub impl @engine.Engine for MongoDBEngine with tx_rollback_to_savepoint_sql(
  _self,
  _name : String,
) -> String {
  ""
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
pub impl @engine.Engine for MongoDBEngine with exec_raw(
  self,
  sql : String,
  _params : FixedArray[@engine.Param],
) {
  guard parse_command(sql) is Some(cmd) else {
    return fail_result("mongodb_engine expects JSON commands")
  }
  let stmt = match decode_statement_command(cmd) {
    Some(stmt) => stmt
    None => return fail_result("mongodb_engine command decode failed")
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
pub impl @engine.Engine for MongoDBEngine with preload_belongs_to_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  let filter = in_filter(target_key, key_params.map(param_to_json))
  let out : Map[String, Json] = Map::new()
  match find_docs(self, target_table, filter) {
    Ok(rows) =>
      for row in rows {
        if row is Object(obj) && obj.get(target_key) is Some(value) {
          out.set(value.stringify(), row)
        }
      }
    Err(_) => ()
  }
  out
}

///|
pub impl @engine.Engine for MongoDBEngine with preload_has_one_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  self.preload_belongs_to_json(target_table, target_key, key_params)
}

///|
pub impl @engine.Engine for MongoDBEngine with preload_has_many_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let filter = in_filter(target_key, key_params.map(param_to_json))
  let out : Map[String, Array[Json]] = Map::new()
  match find_docs(self, target_table, filter) {
    Ok(rows) =>
      for row in rows {
        if row is Object(obj) && obj.get(target_key) is Some(value) {
          let key = value.stringify()
          if out.get(key) is Some(items) {
            items.push(row)
            out.set(key, items)
          } else {
            out.set(key, [row])
          }
        }
      }
    Err(_) => ()
  }
  out
}

///|
pub impl @engine.Engine for MongoDBEngine with preload_many_to_many_json(
  self,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let owner_values = key_params.map(param_to_json)
  let join_filter = in_filter(join_owner_key, owner_values)
  let join_rows = match find_docs(self, join_table, join_filter) {
    Ok(rows) => rows
    Err(_) => return Map::new()
  }
  let target_ids : Array[Json] = []
  for row in join_rows {
    if row is Object(obj) && obj.get(join_target_key) is Some(value) {
      target_ids.push(value)
    }
  }
  let target_filter = in_filter(target_key, FixedArray::from_array(target_ids))
  let target_rows = match find_docs(self, target_table, target_filter) {
    Ok(rows) => rows
    Err(_) => return Map::new()
  }
  let target_index : Map[String, Json] = {}
  for row in target_rows {
    if row is Object(obj) && obj.get(target_key) is Some(value) {
      target_index.set(value.stringify(), row)
    }
  }
  let out : Map[String, Array[Json]] = Map::new()
  for join_row in join_rows {
    if join_row is Object(obj) {
      let owner_value = obj.get(join_owner_key).unwrap_or(Json::null())
      let target_value = obj.get(join_target_key).unwrap_or(Json::null())
      if target_index.get(target_value.stringify()) is Some(target_row) {
        let merged = match target_row {
          Object(target_obj) => target_obj.copy()
          _ => Map::new()
        }
        merged["__morm_owner_key"] = owner_value
        let owner_key = owner_value.stringify()
        let row = merged.to_json()
        if out.get(owner_key) is Some(items) {
          items.push(row)
          out.set(owner_key, items)
        } else {
          out.set(owner_key, [row])
        }
      }
    }
  }
  out
}

///|
pub impl @engine.Engine for MongoDBEngine with close(_self) -> Unit {
  ()
}
