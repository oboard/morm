///|
pub(all) struct MongoDBEngine {
  host : String
  port : Int
  database : String
  state : Ref[Map[String, Array[Json]]]
  tx_snapshot : Ref[Map[String, Array[Json]]?]
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
pub fn parse_mongodb_dsn(dsn : String) -> (String, Int, String)? {
  guard dsn.strip_prefix("mongodb://") is Some(rest_view) else { return None }
  let rest = rest_view.to_string()
  let without_auth = if rest.find("@") is Some(idx) {
    rest[idx + 1:].to_string() catch {
      _ => ""
    }
  } else {
    rest
  }
  let (host_port, database) = if without_auth.find("/") is Some(idx) {
    (
      without_auth[:idx].to_string() catch {
        _ => without_auth
      },
      without_auth[idx + 1:].to_string() catch {
        _ => "test"
      },
    )
  } else {
    (without_auth, "test")
  }
  let (host, port) = parse_host_port(host_port, 27017)
  Some((host, port, if database == "" { "test" } else { database }))
}

///|
pub fn MongoDBEngine::open(dsn : String) -> Result[MongoDBEngine, String] {
  match parse_mongodb_dsn(dsn) {
    Some((host, port, database)) =>
      Ok({
        host,
        port,
        database,
        state: @ref.new(Map::new()),
        tx_snapshot: @ref.new((None : Map[String, Array[Json]]?)),
      })
    None => Err("invalid mongodb dsn: \{dsn}")
  }
}

///|
fn clone_state(state : Map[String, Array[Json]]) -> Map[String, Array[Json]] {
  let out : Map[String, Array[Json]] = Map::new(capacity=state.length())
  state.each((name, docs) => out.set(name, docs.copy()))
  out
}

///|
fn collection_docs(engine : MongoDBEngine, name : String) -> Array[Json] {
  match engine.state.val.get(name) {
    Some(docs) => docs.copy()
    None => []
  }
}

///|
fn set_collection(
  engine : MongoDBEngine,
  name : String,
  docs : Array[Json],
) -> Unit {
  engine.state.val.set(name, docs)
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
fn project_doc(row : Json, fields : FixedArray[String]?) -> Json {
  match fields {
    None => row
    Some(cols) =>
      match row {
        Object(obj) => {
          let out : Map[String, Json] = {}
          for col in cols {
            if obj.get(col) is Some(value) {
              out[col] = value
            }
          }
          out.to_json()
        }
        _ => row
      }
  }
}

///|
fn compare_json(a : Json, b : Json) -> Int {
  match (a, b) {
    (Null, Null) => 0
    (True, True) | (False, False) => 0
    (True, False) => 1
    (False, True) => -1
    (Number(x, ..), Number(y, ..)) =>
      if x < y {
        -1
      } else if x > y {
        1
      } else {
        0
      }
    (String(x), String(y)) => x.compare(y)
    _ => a.stringify().compare(b.stringify())
  }
}

///|
fn doc_field(row : Json, col : String) -> Json? {
  match row {
    Object(obj) => obj.get(col)
    _ => None
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
fn matches_where(row : Json, where_ : FixedArray[@engine.Where]) -> Bool {
  for clause in where_ {
    let actual = doc_field(row, clause.col).unwrap_or(Json::null())
    let expected = param_to_json(clause.value)
    let cmp = compare_json(actual, expected)
    let ok = match clause.ty {
      Eq => actual == expected
      Ne => actual != expected
      Gt => cmp > 0
      Lt => cmp < 0
      Gte => cmp >= 0
      Lte => cmp <= 0
      Like =>
        match (actual, expected) {
          (String(text), String(pattern)) => {
            let needle = pattern.replace_all(old="%", new="")
            text.contains(needle)
          }
          _ => false
        }
    }
    if !ok {
      return false
    }
  }
  true
}

///|
fn sort_rows(
  rows : Array[Json],
  order_by : FixedArray[@engine.OrderBy],
) -> Unit {
  if order_by.is_empty() {
    return
  }
  rows.sort_by((a, b) => {
    for order in order_by {
      let (col, desc) = match order {
        Asc(name) => (name, false)
        Desc(name) => (name, true)
      }
      let av = doc_field(a, col).unwrap_or(Json::null())
      let bv = doc_field(b, col).unwrap_or(Json::null())
      let cmp = compare_json(av, bv)
      if cmp != 0 {
        return if desc { -cmp } else { cmp }
      }
    }
    0
  })
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
fn apply_sets(row : Json, sets : FixedArray[@engine.Set]) -> Json {
  match row {
    Object(obj) => {
      let out = obj.copy()
      for set_ in sets {
        out[set_.col] = param_to_json(set_.value)
      }
      out.to_json()
    }
    _ => row
  }
}

///|
fn run_select(
  engine : MongoDBEngine,
  stmt : @engine.SelectStatement,
) -> @engine.QueryResult {
  let { select, from, joins, where_, order_by, limit, offset } = stmt
  guard joins.is_empty() else {
    return fail_result("mongodb_engine does not support joins")
  }
  let rows = collection_docs(engine, from).filter(row => {
    matches_where(row, where_)
  })
  sort_rows(rows, order_by)
  let start = offset.unwrap_or(0)
  let start = if start < 0 { 0 } else { start }
  let stop = match limit {
    Some(v) if v >= 0 => start + v
    _ => rows.length()
  }
  let projection = parse_projection(select)
  let out : Array[Json] = []
  let mut i = start
  while i < rows.length() && i < stop {
    out.push(project_doc(rows[i], projection))
    i = i + 1
  }
  ok_result(out.length(), FixedArray::from_array(out))
}

///|
fn run_insert(
  engine : MongoDBEngine,
  stmt : @engine.InsertStatement,
) -> @engine.QueryResult {
  let doc = document_from_insert(stmt.columns, stmt.values)
  let docs = collection_docs(engine, stmt.into)
  docs.push(doc)
  set_collection(engine, stmt.into, docs)
  ok_result(1, [doc])
}

///|
fn run_upsert(
  engine : MongoDBEngine,
  stmt : @engine.UpsertStatement,
) -> @engine.QueryResult {
  let docs = collection_docs(engine, stmt.table)
  let base = apply_sets({}, stmt.sets)
  let mut hit = None
  if !stmt.conflict_target.is_empty() {
    let mut i = 0
    while i < docs.length() {
      let row = docs[i]
      let mut matched = true
      for key in stmt.conflict_target {
        let expected = doc_field(base, key).unwrap_or(Json::null())
        let actual = doc_field(row, key).unwrap_or(Json::null())
        if actual != expected {
          matched = false
          break
        }
      }
      if matched {
        hit = Some(i)
        break
      }
      i = i + 1
    }
  }
  match hit {
    Some(idx) => {
      let next = if stmt.update_sets.is_empty() {
        apply_sets(docs[idx], stmt.sets)
      } else {
        apply_sets(docs[idx], stmt.update_sets)
      }
      docs[idx] = next
      set_collection(engine, stmt.table, docs)
      ok_result(1, [next])
    }
    None => {
      docs.push(base)
      set_collection(engine, stmt.table, docs)
      ok_result(1, [base])
    }
  }
}

///|
fn run_update(
  engine : MongoDBEngine,
  stmt : @engine.UpdateStatement,
) -> @engine.QueryResult {
  let docs = collection_docs(engine, stmt.table)
  let changed : Array[Json] = []
  let mut i = 0
  while i < docs.length() {
    if matches_where(docs[i], stmt.where_) {
      let next = apply_sets(docs[i], stmt.sets)
      docs[i] = next
      changed.push(next)
    }
    i = i + 1
  }
  set_collection(engine, stmt.table, docs)
  ok_result(changed.length(), FixedArray::from_array(changed))
}

///|
fn run_delete(
  engine : MongoDBEngine,
  stmt : @engine.DeleteStatement,
) -> @engine.QueryResult {
  let docs = collection_docs(engine, stmt.from)
  let kept : Array[Json] = []
  let removed : Array[Json] = []
  for row in docs {
    if matches_where(row, stmt.where_) {
      removed.push(row)
    } else {
      kept.push(row)
    }
  }
  set_collection(engine, stmt.from, kept)
  ok_result(removed.length(), FixedArray::from_array(removed))
}

///|
fn parse_command(sql : String) -> Json? {
  Some(@json5.parse(sql)) catch {
    _ => None
  }
}

///|
fn run_preload_in(
  engine : MongoDBEngine,
  cmd : Map[String, Json],
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  guard cmd.get("table") is Some(String(table)) else {
    return fail_result("mongodb preload_in missing table")
  }
  guard cmd.get("key_col") is Some(String(key_col)) else {
    return fail_result("mongodb preload_in missing key_col")
  }
  let keys = params.map(param_to_json)
  let out : Array[Json] = []
  for row in collection_docs(engine, table) {
    let value = doc_field(row, key_col).unwrap_or(Json::null())
    if keys.contains(value) {
      out.push(row)
    }
  }
  ok_result(out.length(), FixedArray::from_array(out))
}

///|
fn run_preload_many_to_many(
  engine : MongoDBEngine,
  cmd : Map[String, Json],
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  guard cmd
    is {
      "target_table": String(target_table),
      "target_key": String(target_key),
      "join_table": String(join_table),
      "join_owner_key": String(join_owner_key),
      "join_target_key": String(join_target_key),
      ..
    } else {
    return fail_result("mongodb preload_many_to_many command is invalid")
  }
  let owner_keys = params.map(param_to_json)
  let target_rows = collection_docs(engine, target_table)
  let target_index : Map[String, Json] = {}
  for row in target_rows {
    let key = doc_field(row, target_key).unwrap_or(Json::null()).stringify()
    target_index[key] = row
  }
  let out : Array[Json] = []
  for join_row in collection_docs(engine, join_table) {
    let owner_value = doc_field(join_row, join_owner_key).unwrap_or(
      Json::null(),
    )
    if !owner_keys.contains(owner_value) {
      continue
    }
    let target_value = doc_field(join_row, join_target_key).unwrap_or(
      Json::null(),
    )
    if target_index.get(target_value.stringify()) is Some(target_row) {
      let merged = match target_row {
        Object(obj) => obj.copy()
        _ => Map::new()
      }
      merged["__morm_owner_key"] = owner_value
      out.push(merged.to_json())
    }
  }
  ok_result(out.length(), FixedArray::from_array(out))
}

///|
impl @engine.Engine for MongoDBEngine with render(_self, stmt) {
  (stmt.to_json().stringify(), [])
}

///|
impl @engine.Engine for MongoDBEngine with tx_begin_sql(_self) -> String {
  "__morm_mongo_tx_begin__"
}

///|
impl @engine.Engine for MongoDBEngine with tx_commit_sql(_self) -> String {
  "__morm_mongo_tx_commit__"
}

///|
impl @engine.Engine for MongoDBEngine with tx_rollback_sql(_self) -> String {
  "__morm_mongo_tx_rollback__"
}

///|
impl @engine.Engine for MongoDBEngine with tx_savepoint_sql(
  _self,
  _name : String,
) -> String {
  ""
}

///|
impl @engine.Engine for MongoDBEngine with tx_rollback_to_savepoint_sql(
  _self,
  _name : String,
) -> String {
  ""
}

///|
impl @engine.Engine for MongoDBEngine with migrate_table(self, table_schema) {
  if table_schema is { "name": String(name), .. } {
    if self.state.val.get(name) is None {
      self.state.val.set(name, [])
    }
    ok_result(0, [])
  } else {
    fail_result("invalid table schema")
  }
}

///|
impl @engine.Engine for MongoDBEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) {
  if sql == "__morm_mongo_tx_begin__" {
    self.tx_snapshot.val = Some(clone_state(self.state.val))
    return ok_result(0, [])
  }
  if sql == "__morm_mongo_tx_commit__" {
    self.tx_snapshot.val = None
    return ok_result(0, [])
  }
  if sql == "__morm_mongo_tx_rollback__" {
    if self.tx_snapshot.val is Some(snapshot) {
      self.state.val = clone_state(snapshot)
      self.tx_snapshot.val = None
    }
    return ok_result(0, [])
  }
  guard parse_command(sql) is Some(cmd) else {
    return fail_result("mongodb_engine expects JSON commands")
  }
  match cmd {
    Object(obj) =>
      match obj {
        { "op": "preload_in", .. } => run_preload_in(self, obj, params)
        { "op": "preload_many_to_many", .. } =>
          run_preload_many_to_many(self, obj, params)
        _ => {
          let stmt : @engine.Statement = @json.from_json(obj.to_json()) catch {
            _ => return fail_result("mongodb_engine command decode failed")
          }
          match stmt {
            Select(select_stmt) => run_select(self, select_stmt)
            Insert(insert_stmt) => run_insert(self, insert_stmt)
            Upsert(upsert_stmt) => run_upsert(self, upsert_stmt)
            Update(update_stmt) => run_update(self, update_stmt)
            Delete(delete_stmt) => run_delete(self, delete_stmt)
          }
        }
      }
    _ => {
      let stmt : @engine.Statement = @json.from_json(cmd) catch {
        _ => return fail_result("mongodb_engine command decode failed")
      }
      match stmt {
        Select(select_stmt) => run_select(self, select_stmt)
        Insert(insert_stmt) => run_insert(self, insert_stmt)
        Upsert(upsert_stmt) => run_upsert(self, upsert_stmt)
        Update(update_stmt) => run_update(self, update_stmt)
        Delete(delete_stmt) => run_delete(self, delete_stmt)
      }
    }
  }
}

///|
impl @engine.Engine for MongoDBEngine with preload_belongs_to_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  let out : Map[String, Json] = Map::new()
  let keys = key_params.map(param_to_json)
  for row in collection_docs(self, target_table) {
    let value = doc_field(row, target_key).unwrap_or(Json::null())
    if keys.contains(value) {
      out.set(value.stringify(), row)
    }
  }
  out
}

///|
impl @engine.Engine for MongoDBEngine with preload_has_one_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Json] {
  self.preload_belongs_to_json(target_table, target_key, key_params)
}

///|
impl @engine.Engine for MongoDBEngine with preload_has_many_json(
  self,
  target_table : String,
  target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let out : Map[String, Array[Json]] = Map::new()
  let keys = key_params.map(param_to_json)
  for row in collection_docs(self, target_table) {
    let value = doc_field(row, target_key).unwrap_or(Json::null())
    if !keys.contains(value) {
      continue
    }
    let key = value.stringify()
    if out.get(key) is Some(items) {
      items.push(row)
      out.set(key, items)
    } else {
      out.set(key, [row])
    }
  }
  out
}

///|
impl @engine.Engine for MongoDBEngine with preload_many_to_many_json(
  self,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  key_params : FixedArray[@engine.Param],
) -> Map[String, Array[Json]] {
  let owner_keys = key_params.map(param_to_json)
  let target_rows = collection_docs(self, target_table)
  let target_index : Map[String, Json] = {}
  for row in target_rows {
    let key = doc_field(row, target_key).unwrap_or(Json::null()).stringify()
    target_index[key] = row
  }
  let out : Map[String, Array[Json]] = Map::new()
  for join_row in collection_docs(self, join_table) {
    let owner_value = doc_field(join_row, join_owner_key).unwrap_or(
      Json::null(),
    )
    if !owner_keys.contains(owner_value) {
      continue
    }
    let target_value = doc_field(join_row, join_target_key).unwrap_or(
      Json::null(),
    )
    if target_index.get(target_value.stringify()) is Some(target_row) {
      let merged = match target_row {
        Object(obj) => obj.copy()
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
  out
}

///|
impl @engine.Engine for MongoDBEngine with close(_self) -> Unit {
  ()
}
