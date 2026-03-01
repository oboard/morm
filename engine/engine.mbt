///|
pub(all) enum Param {
  Null
  Bool(Bool)
  Byte(Byte)
  Int(Int)
  Int16(Int16)
  UInt16(UInt16)
  UInt(UInt)
  UInt64(UInt64)
  Int64(Int64)
  BigInt(BigInt)
  Float(Float)
  Double(Double)
  Decimal(String)
  Date(@time.PlainDate)
  Time(@time.PlainTime)
  DateTime(@time.PlainDateTime)
  Timestamp(@time.ZonedDateTime)
  Uuid(String)
  Json(Json)
  String(String)
  Bytes(Bytes)
} derive(Show)

///|
pub impl Eq for Param with equal(self, other) {
  match (self, other) {
    (Null, Null) => true
    (Bool(a), Bool(b)) => a == b
    (Byte(a), Byte(b)) => a == b
    (Int(a), Int(b)) => a == b
    (Int16(a), Int16(b)) => a == b
    (UInt16(a), UInt16(b)) => a == b
    (UInt(a), UInt(b)) => a == b
    (UInt64(a), UInt64(b)) => a == b
    (Int64(a), Int64(b)) => a == b
    (BigInt(a), BigInt(b)) => a == b
    (Float(a), Float(b)) => a == b
    (Double(a), Double(b)) => a == b
    (Decimal(a), Decimal(b)) => a == b
    (Date(a), Date(b)) => a == b
    (Time(a), Time(b)) => a == b
    (DateTime(a), DateTime(b)) => a == b
    (Timestamp(a), Timestamp(b)) => a.to_string() == b.to_string()
    (Uuid(a), Uuid(b)) => a == b
    (Json(a), Json(b)) => a == b
    (String(a), String(b)) => a == b
    (Bytes(a), Bytes(b)) => a == b
    _ => false
  }
}

///|
pub impl ToJson for Param with to_json(self) -> Json {
  match self {
    Null => Json::null()
    Bool(v) => Json::boolean(v)
    Byte(v) => Json::number(v.to_int().to_double())
    Int(v) => v.to_json()
    Int16(v) => v.to_json()
    UInt16(v) => v.to_json()
    UInt(v) => v.to_json()
    UInt64(v) => v.to_json()
    Int64(v) => v.to_json()
    BigInt(v) => v.to_json()
    Float(v) => v.to_json()
    Double(v) => v.to_json()
    Decimal(v) => Json::string(v)
    Date(v) => Json::string(v.to_string())
    Time(v) => Json::string(v.to_string())
    DateTime(v) => Json::string(v.to_string())
    Timestamp(v) => Json::string(v.to_string())
    Uuid(v) => Json::string(v)
    Json(v) => v
    String(v) => v.to_json()
    Bytes(v) => v.to_json()
  }
}

///|
pub impl @json.FromJson for Param with from_json(json, _path) {
  match json {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Int(n.to_int())
      } else {
        Double(n)
      }
    String(s) => String(s)
    Array(_) | Object(_) => Json(json)
  }
}

///|
pub(all) suberror ParamDecodeError {
  ParamDecodeError(String)
} derive(Eq, Show, ToJson)

///|
pub fn param_from_json_value(json : Json) -> Param {
  match json {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Int(n.to_int())
      } else {
        Double(n)
      }
    String(s) => String(s)
    Array(_) | Object(_) => Json(json)
  }
}

///|
fn[T] param_decode_error(msg : String) -> T raise ParamDecodeError {
  raise ParamDecodeError(msg)
}

///|
pub(open) trait FromParam {
  from_param(Param) -> Self raise ParamDecodeError
}

///|
pub fn[T : FromParam] from_param(value : Param) -> T raise ParamDecodeError {
  FromParam::from_param(value)
}

///|
pub impl FromParam for Param with from_param(self) {
  self
}

///|
pub impl FromParam for Unit with from_param(value) {
  match value {
    Null => ()
    _ => param_decode_error("Unit::from_param: expected Null")
  }
}

///|
pub impl FromParam for Bool with from_param(value) {
  match value {
    Bool(v) => v
    _ => param_decode_error("Bool::from_param: expected Bool")
  }
}

///|
pub impl FromParam for Byte with from_param(value) {
  match value {
    Byte(v) => v
    Int(v) if v >= 0 && v <= 255 => v.to_byte()
    _ => param_decode_error("Byte::from_param: expected Byte-compatible value")
  }
}

///|
pub impl FromParam for Int with from_param(value) {
  match value {
    Int(v) => v
    Int16(v) => v.to_int()
    UInt16(v) => v.to_int()
    Byte(v) => v.to_int()
    _ => param_decode_error("Int::from_param: expected Int-compatible value")
  }
}

///|
pub impl FromParam for Int16 with from_param(value) {
  match value {
    Int16(v) => v
    Int(v) if v >= -32768 && v <= 32767 => Int16::from_int(v)
    _ =>
      param_decode_error("Int16::from_param: expected Int16-compatible value")
  }
}

///|
pub impl FromParam for UInt16 with from_param(value) {
  match value {
    UInt16(v) => v
    Int(v) if v >= 0 && v <= 65535 => v.to_uint16()
    _ =>
      param_decode_error("UInt16::from_param: expected UInt16-compatible value")
  }
}

///|
pub impl FromParam for UInt with from_param(value) {
  match value {
    UInt(v) => v
    UInt16(v) => v.to_uint()
    Byte(v) => v.to_uint()
    Int(v) if v >= 0 => v.reinterpret_as_uint()
    String(s) =>
      @strconv.parse_uint(s) catch {
        _ => param_decode_error("UInt::from_param: invalid UInt string")
      }
    _ => param_decode_error("UInt::from_param: expected UInt-compatible value")
  }
}

///|
pub impl FromParam for UInt64 with from_param(value) {
  match value {
    UInt64(v) => v
    UInt(v) => v.to_uint64()
    UInt16(v) => v.to_uint64()
    Byte(v) => v.to_uint64()
    Int(v) if v >= 0 => v.to_uint64()
    String(s) =>
      @strconv.parse_uint64(s) catch {
        _ => param_decode_error("UInt64::from_param: invalid UInt64 string")
      }
    _ =>
      param_decode_error("UInt64::from_param: expected UInt64-compatible value")
  }
}

///|
pub impl FromParam for Int64 with from_param(value) {
  match value {
    Int64(v) => v
    Int(v) => v.to_int64()
    Int16(v) => v.to_int64()
    UInt16(v) => v.to_int64()
    Byte(v) => v.to_int64()
    String(s) =>
      @strconv.parse_int64(s) catch {
        _ => param_decode_error("Int64::from_param: invalid Int64 string")
      }
    _ =>
      param_decode_error("Int64::from_param: expected Int64-compatible value")
  }
}

///|
pub impl FromParam for BigInt with from_param(value) {
  match value {
    BigInt(v) => v
    Int(v) => BigInt::from_int(v)
    Int64(v) => BigInt::from_int64(v)
    String(s) => BigInt::from_string(s)
    _ =>
      param_decode_error("BigInt::from_param: expected BigInt-compatible value")
  }
}

///|
pub impl FromParam for Float with from_param(value) {
  match value {
    Float(v) => v
    Double(v) => Float::from_double(v)
    Int(v) => Float::from_int(v)
    String(s) =>
      Float::from_double(@strconv.parse_double(s)) catch {
        _ => param_decode_error("Float::from_param: invalid Float string")
      }
    _ =>
      param_decode_error("Float::from_param: expected Float-compatible value")
  }
}

///|
pub impl FromParam for Double with from_param(value) {
  match value {
    Double(v) => v
    Float(v) => v.to_double()
    Int(v) => v.to_double()
    String(s) =>
      @strconv.parse_double(s) catch {
        _ => param_decode_error("Double::from_param: invalid Double string")
      }
    _ =>
      param_decode_error("Double::from_param: expected Double-compatible value")
  }
}

///|
pub impl FromParam for String with from_param(value) {
  match value {
    String(v) => v
    Decimal(v) => v
    Uuid(v) => v
    Date(v) => v.to_string()
    Time(v) => v.to_string()
    DateTime(v) => v.to_string()
    Timestamp(v) => v.to_string()
    _ =>
      param_decode_error("String::from_param: expected String-compatible value")
  }
}

///|
pub impl FromParam for Bytes with from_param(value) {
  match value {
    Bytes(v) => v
    _ => param_decode_error("Bytes::from_param: expected Bytes")
  }
}

///|
pub impl FromParam for Json with from_param(value) {
  match value {
    Json(v) => v
    _ => value.to_json()
  }
}

///|
pub impl FromParam for @time.PlainDate with from_param(value) {
  match value {
    Date(v) => v
    String(v) =>
      @time.PlainDate::from_string(v) catch {
        _ => param_decode_error("PlainDate::from_param: invalid date string")
      }
    _ =>
      param_decode_error(
        "PlainDate::from_param: expected date-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.PlainTime with from_param(value) {
  match value {
    Time(v) => v
    String(v) =>
      @time.PlainTime::from_string(v) catch {
        _ => param_decode_error("PlainTime::from_param: invalid time string")
      }
    _ =>
      param_decode_error(
        "PlainTime::from_param: expected time-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.PlainDateTime with from_param(value) {
  match value {
    DateTime(v) => v
    String(v) =>
      @time.PlainDateTime::from_string(v) catch {
        _ =>
          param_decode_error(
            "PlainDateTime::from_param: invalid datetime string",
          )
      }
    _ =>
      param_decode_error(
        "PlainDateTime::from_param: expected datetime-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.ZonedDateTime with from_param(value) {
  match value {
    Timestamp(v) => v
    String(v) =>
      @time.ZonedDateTime::from_string(v) catch {
        _ =>
          param_decode_error(
            "ZonedDateTime::from_param: invalid timestamp string",
          )
      }
    _ =>
      param_decode_error(
        "ZonedDateTime::from_param: expected timestamp-compatible value",
      )
  }
}

///|
pub impl[T : FromParam] FromParam for T? with from_param(value) {
  match value {
    Null => None
    _ => Some(try! FromParam::from_param(value))
  }
}

///|
pub(open) trait ToParam {
  to_param(Self) -> Param
}

///|
pub fn[T : ToParam] to_param(value : T) -> Param {
  value.to_param()
}

///|
pub impl ToParam for Param with to_param(self) -> Param {
  self
}

///|
pub impl ToParam for Unit with to_param(_self) -> Param {
  Null
}

///|
pub impl ToParam for Bool with to_param(self) -> Param {
  Bool(self)
}

///|
pub impl ToParam for Byte with to_param(self) -> Param {
  Byte(self)
}

///|
pub impl ToParam for Int with to_param(self) -> Param {
  Int(self)
}

///|
pub impl ToParam for Int16 with to_param(self) -> Param {
  Int16(self)
}

///|
pub impl ToParam for UInt16 with to_param(self) -> Param {
  UInt16(self)
}

///|
pub impl ToParam for UInt with to_param(self) -> Param {
  UInt(self)
}

///|
pub impl ToParam for UInt64 with to_param(self) -> Param {
  UInt64(self)
}

///|
pub impl ToParam for Int64 with to_param(self) -> Param {
  Int64(self)
}

///|
pub impl ToParam for BigInt with to_param(self) -> Param {
  BigInt(self)
}

///|
pub impl ToParam for Double with to_param(self) -> Param {
  Double(self)
}

///|
pub impl ToParam for Float with to_param(self) -> Param {
  Float(self)
}

///|
pub impl ToParam for @time.PlainDate with to_param(self) -> Param {
  Date(self)
}

///|
pub impl ToParam for @time.PlainTime with to_param(self) -> Param {
  Time(self)
}

///|
pub impl ToParam for @time.PlainDateTime with to_param(self) -> Param {
  DateTime(self)
}

///|
pub impl ToParam for @time.ZonedDateTime with to_param(self) -> Param {
  Timestamp(self)
}

///|
pub impl ToParam for String with to_param(self) -> Param {
  String(self)
}

///|
pub impl ToParam for Bytes with to_param(self) -> Param {
  Bytes(self)
}

///|
pub impl ToParam for Json with to_param(self) -> Param {
  Json(self)
}

///|
pub(all) enum WhereType {
  Eq
  Ne
  Gt
  Lt
  Gte
  Lte
  Like
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Where {
  col : String
  value : Param
  ty : WhereType
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum OrderBy {
  Asc(String)
  Desc(String)
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Set {
  col : String
  value : Param
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct SelectStatement {
  select : String
  from : String
  joins : FixedArray[String]
  where_ : FixedArray[Where]
  order_by : FixedArray[OrderBy]
  limit : Int?
  offset : Int?
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct InsertStatement {
  into : String
  columns : FixedArray[String]
  values : FixedArray[Param]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct UpsertStatement {
  table : String
  sets : FixedArray[Set]
  conflict_target : FixedArray[String]
  update_sets : FixedArray[Set]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct UpdateStatement {
  table : String
  sets : FixedArray[Set]
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct DeleteStatement {
  from : String
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum Statement {
  Select(SelectStatement)
  Insert(InsertStatement)
  Upsert(UpsertStatement)
  Update(UpdateStatement)
  Delete(DeleteStatement)
} derive(Eq, Show, ToJson, FromJson)

///|
pub(open) trait QueryBuilder {
  to_statement(Self) -> Statement
}

///|
pub(open) trait Engine {
  /// Render SQL and params from query builder statement.
  render(Self, stmt : Statement) -> (String, FixedArray[Param])
  ///|
  /// Transaction begin SQL for current engine.
  tx_begin_sql(Self) -> String
  ///|
  /// Transaction commit SQL for current engine.
  tx_commit_sql(Self) -> String
  ///|
  /// Transaction rollback SQL for current engine.
  tx_rollback_sql(Self) -> String
  ///|
  /// Savepoint SQL for current engine.
  tx_savepoint_sql(Self, name : String) -> String
  ///|
  /// Rollback-to-savepoint SQL for current engine.
  tx_rollback_to_savepoint_sql(Self, name : String) -> String
  ///|
  /// Apply table migration from schema JSON generated by morm.Table::to_json().
  async migrate_table(Self, table_schema : Json) -> QueryResult
  ///|
  /// Execute raw SQL statement directly. Keep this for custom SQL in mapper.
  async exec_raw(Self, sql : String, params : FixedArray[Param]) -> QueryResult
  ///|
  /// Build preload SQL with IN placeholders for current engine style.
  preload_in_sql(Self, table : String, key_col : String, count : Int) -> String
  ///|
  /// Build many-to-many preload SQL for current engine style.
  preload_many_to_many_sql(
    Self,
    target_table : String,
    target_key : String,
    join_table : String,
    join_owner_key : String,
    join_target_key : String,
    count : Int,
  ) -> String
  ///|
  /// Close the database connection.
  close(Self) -> Unit
}

///|
pub async fn[E : Engine, Q : QueryBuilder] exec_query(
  engine : E,
  query : Q,
) -> QueryResult {
  let (sql, params) = engine.render(query.to_statement())
  engine.exec_raw(sql, params)
}

///|
fn tx_noop_ok() -> QueryResult {
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
pub async fn[E : Engine] tx_begin(engine : E) -> QueryResult {
  let sql = engine.tx_begin_sql()
  if sql.trim() == "" {
    tx_noop_ok()
  } else {
    engine.exec_raw(sql, [])
  }
}

///|
pub async fn[E : Engine] tx_commit(engine : E) -> QueryResult {
  let sql = engine.tx_commit_sql()
  if sql.trim() == "" {
    tx_noop_ok()
  } else {
    engine.exec_raw(sql, [])
  }
}

///|
pub async fn[E : Engine] tx_rollback(engine : E) -> QueryResult {
  let sql = engine.tx_rollback_sql()
  if sql.trim() == "" {
    tx_noop_ok()
  } else {
    engine.exec_raw(sql, [])
  }
}

///|
pub async fn[E : Engine] tx_savepoint(engine : E, name : String) -> QueryResult {
  let sql = engine.tx_savepoint_sql(name)
  if sql.trim() == "" {
    tx_noop_ok()
  } else {
    engine.exec_raw(sql, [])
  }
}

///|
pub async fn[E : Engine] tx_rollback_to_savepoint(
  engine : E,
  name : String,
) -> QueryResult {
  let sql = engine.tx_rollback_to_savepoint_sql(name)
  if sql.trim() == "" {
    tx_noop_ok()
  } else {
    engine.exec_raw(sql, [])
  }
}

///|
fn placeholders(count : Int) -> String {
  let parts : Array[String] = []
  let mut i = 0
  while i < count {
    parts.push("?")
    i = i + 1
  }
  parts.join(", ")
}

///|
fn placeholders_with(prefix : String, count : Int) -> String {
  let parts : Array[String] = []
  let mut i = 1
  while i <= count {
    if prefix == "?" {
      parts.push("?")
    } else {
      parts.push(prefix + i.to_string())
    }
    i = i + 1
  }
  parts.join(", ")
}

///|
pub fn preload_in_sql_qmark(
  table : String,
  key_col : String,
  count : Int,
) -> String {
  let marks = placeholders_with("?", count)
  "SELECT * FROM \{table} WHERE \{key_col} IN (\{marks})"
}

///|
pub fn preload_in_sql_dollar(
  table : String,
  key_col : String,
  count : Int,
) -> String {
  let marks = placeholders_with("$", count)
  "SELECT * FROM \{table} WHERE \{key_col} IN (\{marks})"
}

///|
pub fn preload_many_to_many_sql_qmark(
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  count : Int,
) -> String {
  let marks = placeholders_with("?", count)
  "SELECT t.*, j.\{join_owner_key} AS __morm_owner_key FROM \{target_table} t INNER JOIN \{join_table} j ON j.\{join_target_key} = t.\{target_key} WHERE j.\{join_owner_key} IN (\{marks})"
}

///|
pub fn preload_many_to_many_sql_dollar(
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  count : Int,
) -> String {
  let marks = placeholders_with("$", count)
  "SELECT t.*, j.\{join_owner_key} AS __morm_owner_key FROM \{target_table} t INNER JOIN \{join_table} j ON j.\{join_target_key} = t.\{target_key} WHERE j.\{join_owner_key} IN (\{marks})"
}

///|
fn format_where_sql(where_ : FixedArray[Where]) -> String {
  where_
  .map(w => {
    let op = match w.ty {
      Eq => "="
      Ne => "!="
      Gt => ">"
      Lt => "<"
      Gte => ">="
      Lte => "<="
      Like => "LIKE"
    }
    [w.col, op, "?"].join(" ")
  })
  .join(" AND ")
}

///|
fn format_set_sql(sets : FixedArray[Set]) -> String {
  sets.map(s => [s.col, "=", "?"].join(" ")).join(", ")
}

///|
/// Default renderer (MySQL/Sqlite style placeholders and upsert syntax).
pub fn render_default_sql(stmt : Statement) -> (String, FixedArray[Param]) {
  match stmt {
    Select(select_stmt) => {
      let { select, from, joins, where_, order_by, limit, offset } = select_stmt
      let buf = @buffer.new()
      buf.write_string("SELECT ")
      if select.is_empty() {
        buf.write_string("*")
      } else {
        buf.write_string(select)
      }
      buf.write_string(" FROM ")
      buf.write_string(from)
      if !joins.is_empty() {
        buf.write_string(" ")
        buf.write_string(joins.join(" "))
      }
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      if !order_by.is_empty() {
        buf.write_string(" ORDER BY ")
        buf.write_string(
          order_by
          .map(ob => {
            match ob {
              Asc(col) => "\{col} ASC"
              Desc(col) => "\{col} DESC"
            }
          })
          .join(", "),
        )
      }
      if limit is Some(v) {
        buf.write_string(" LIMIT ")
        buf.write_string(v.to_string())
      }
      if offset is Some(v) {
        buf.write_string(" OFFSET ")
        buf.write_string(v.to_string())
      }
      (buf.to_string(), where_.map(w => w.value))
    }
    Insert(insert_stmt) => {
      let { into, columns, values } = insert_stmt
      let buf = @buffer.new()
      buf.write_string("INSERT INTO ")
      buf.write_string(into)
      if !columns.is_empty() {
        buf.write_string(" (")
        buf.write_string(columns.join(", "))
        buf.write_string(")")
      }
      buf.write_string(" VALUES (")
      buf.write_string(placeholders(values.length()))
      buf.write_string(")")
      (buf.to_string(), values)
    }
    Upsert(upsert_stmt) => {
      let { table, sets, conflict_target: _, update_sets } = upsert_stmt
      let buf = @buffer.new()
      buf.write_string("INSERT INTO ")
      buf.write_string(table)
      buf.write_string(" (")
      buf.write_string(sets.map(s => s.col).join(", "))
      buf.write_string(") VALUES (")
      buf.write_string(placeholders(sets.length()))
      buf.write_string(")")
      if !update_sets.is_empty() {
        buf.write_string(" ON DUPLICATE KEY UPDATE ")
        buf.write_string(format_set_sql(update_sets))
      }
      let mut args = sets.map(s => s.value)
      if !update_sets.is_empty() {
        args = args + update_sets.map(s => s.value)
      }
      (buf.to_string(), args)
    }
    Update(update_stmt) => {
      let { table, sets, where_ } = update_stmt
      let buf = @buffer.new()
      buf.write_string("UPDATE ")
      buf.write_string(table)
      buf.write_string(" SET ")
      buf.write_string(format_set_sql(sets))
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      (buf.to_string(), sets.map(s => s.value) + where_.map(w => w.value))
    }
    Delete(delete_stmt) => {
      let { from, where_ } = delete_stmt
      let buf = @buffer.new()
      buf.write_string("DELETE FROM ")
      buf.write_string(from)
      if !where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(where_))
      }
      (buf.to_string(), where_.map(w => w.value))
    }
  }
}

///|
pub(all) struct QueryResult {
  ok : Bool
  rows_affected : Int
  rows : FixedArray[Json]
  error : String?
} derive(Show, ToJson, FromJson, Eq)
