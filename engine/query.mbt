
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
pub async fn[E : Engine] preload_belongs_to_default(
  engine : E,
  sql : String,
  target_key : String,
  key_params : FixedArray[Param],
) -> Map[String, Json] {
  let out : Map[String, Json] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get(target_key) is Some(v) {
        out.set(v.stringify(), row)
      }
    }
  }
  out
}

///|
pub async fn[E : Engine] preload_has_many_default(
  engine : E,
  sql : String,
  target_key : String,
  key_params : FixedArray[Param],
) -> Map[String, Array[Json]] {
  let out : Map[String, Array[Json]] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get(target_key) is Some(v) {
        let key = v.stringify()
        if out.get(key) is Some(items) {
          items.push(row)
          out.set(key, items)
        } else {
          out.set(key, [row])
        }
      }
    }
  }
  out
}

///|
pub async fn[E : Engine] preload_many_to_many_default(
  engine : E,
  sql : String,
  key_params : FixedArray[Param],
) -> Map[String, Array[Json]] {
  let out : Map[String, Array[Json]] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get("__morm_owner_key") is Some(owner_key_value) {
        let owner_key = owner_key_value.stringify()
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