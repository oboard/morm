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
  "SELECT * FROM \{table} WHERE \{key_col} IN (\{placeholders_with("?", count)})"
}

///|
pub fn preload_in_sql_dollar(
  table : String,
  key_col : String,
  count : Int,
) -> String {
  "SELECT * FROM \{table} WHERE \{key_col} IN (\{placeholders_with("$", count)})"
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
  "SELECT t.*, j.\{join_owner_key} AS __morm_owner_key FROM \{target_table} t INNER JOIN \{join_table} j ON j.\{join_target_key} = t.\{target_key} WHERE j.\{join_owner_key} IN (\{placeholders_with("?", count)})"
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
  "SELECT t.*, j.\{join_owner_key} AS __morm_owner_key FROM \{target_table} t INNER JOIN \{join_table} j ON j.\{join_target_key} = t.\{target_key} WHERE j.\{join_owner_key} IN (\{placeholders_with("$", count)})"
}

///|
fn row_object_key(row : Map[String, Param], key : String) -> String? {
  if row.get(key) is Some(v) {
    return Some(v.to_json().stringify())
  }
  None
}

///|
fn query_result_row_json(row : Map[String, Param]) -> Json {
  row.to_json()
}

///|
fn map_push_row_json_array(
  out : Map[String, Array[Json]],
  key : String,
  row : Map[String, Param],
) -> Unit {
  let row_json = query_result_row_json(row)
  if out.get(key) is Some(items) {
    items.push(row_json)
    out.set(key, items)
  } else {
    out.set(key, [row_json])
  }
}

///|
pub async fn[E : Engine] preload_belongs_to_default(
  engine : E,
  sql : String,
  target_key : String,
  key_params : FixedArray[Param],
) -> Map[String, Json] {
  let out : Map[String, Json] = Map([])
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec(Raw(sql, key_params))
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row_object_key(row, target_key) is Some(key) {
      out.set(key, query_result_row_json(row))
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
  let out : Map[String, Array[Json]] = Map([])
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec(Raw(sql, key_params))
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row_object_key(row, target_key) is Some(key) {
      map_push_row_json_array(out, key, row)
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
  let out : Map[String, Array[Json]] = Map([])
  if key_params.is_empty() {
    return out
  }
  let res = engine.exec(Raw(sql, key_params))
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row_object_key(row, "__morm_owner_key") is Some(owner_key) {
      map_push_row_json_array(out, owner_key, row)
    }
  }
  out
}

///|
fn format_where_sql(where_ : FixedArray[Where]) -> String {
  where_
  .map(w => {
    match (w.ty, w.value) {
      (Eq, Null | Json(Null)) => "\{w.col} IS NULL"
      (Ne, Null | Json(Null)) => "\{w.col} IS NOT NULL"
      _ => {
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
      }
    }
  })
  .join(" AND ")
}

///|
fn where_params(where_ : FixedArray[Where]) -> FixedArray[Param] {
  let out : Array[Param] = []
  for w in where_ {
    if w.ty is (Eq | Ne) && w.value is (Null | Json(Null)) {
      continue
    }
    out.push(w.value)
  }
  FixedArray::from_array(out)
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
      let buf = StringBuilder()
      buf <+
        "SELECT \{if select.is_empty() { "*" } else { select }} FROM \{from}"
      if !joins.is_empty() {
        buf <+ " \{joins.join(" ")}"
      }
      if !where_.is_empty() {
        buf <+ " WHERE \{format_where_sql(where_)}"
      }
      if !order_by.is_empty() {
        let order_sql = order_by
          .map(ob => {
            match ob {
              Asc(col) => "\{col} ASC"
              Desc(col) => "\{col} DESC"
            }
          })
          .join(", ")
        buf <+ " ORDER BY \{order_sql}"
      }
      if limit is Some(v) {
        buf <+ " LIMIT \{v}"
      }
      if offset is Some(v) {
        buf <+ " OFFSET \{v}"
      }
      (buf.to_string(), where_params(where_))
    }
    Insert(insert_stmt) => {
      let { into, columns, values, rows } = insert_stmt
      let buf = StringBuilder()
      buf <+ "INSERT INTO \{into}"
      if !columns.is_empty() {
        buf <+ " (\{columns.join(", ")})"
      }
      let effective_rows = if !rows.is_empty() { rows } else { [values] }
      let row_sql = effective_rows.map(row => {
        "(" + placeholders(row.length()) + ")"
      })
      buf <+ " VALUES \{row_sql.join(", ")}"
      let out_params : Array[Param] = []
      for row in effective_rows {
        for value in row {
          out_params.push(value)
        }
      }
      (buf.to_string(), FixedArray::from_array(out_params))
    }
    Upsert(upsert_stmt) => {
      let { table, sets, conflict_target: _, update_sets } = upsert_stmt
      let buf = StringBuilder()
      buf <+
        "INSERT INTO \{table} (\{sets.map(s => s.col).join(", ")}) VALUES (\{placeholders(sets.length())})"
      if !update_sets.is_empty() {
        buf <+ " ON DUPLICATE KEY UPDATE \{format_set_sql(update_sets)}"
      }
      let mut args = sets.map(s => s.value)
      if !update_sets.is_empty() {
        args = args + update_sets.map(s => s.value)
      }
      (buf.to_string(), args)
    }
    Update(update_stmt) => {
      let { table, sets, where_ } = update_stmt
      let buf = StringBuilder()
      buf <+ "UPDATE \{table} SET \{format_set_sql(sets)}"
      if !where_.is_empty() {
        buf <+ " WHERE \{format_where_sql(where_)}"
      }
      (buf.to_string(), sets.map(s => s.value) + where_params(where_))
    }
    Delete(delete_stmt) => {
      let { from, where_ } = delete_stmt
      let buf = StringBuilder()
      buf <+ "DELETE FROM \{from}"
      if !where_.is_empty() {
        buf <+ " WHERE \{format_where_sql(where_)}"
      }
      (buf.to_string(), where_params(where_))
    }
  }
}

///|
fn tx_sql(op : TxOp) -> String {
  match op {
    Begin => "BEGIN"
    Commit => "COMMIT"
    Rollback => "ROLLBACK"
    Savepoint(name) => "SAVEPOINT " + name
    RollbackToSavepoint(name) => "ROLLBACK TO SAVEPOINT " + name
  }
}

///|
pub fn render_query_sql(query : &QueryBuilder) -> (String, FixedArray[Param]) {
  match query.to_query() {
    Statement(stmt) => render_default_sql(stmt)
    Raw(sql, params) => (sql, params)
    Tx(op) => (tx_sql(op), [])
  }
}

///|
pub(all) struct QueryResult {
  ok : Bool
  rows_affected : Int
  rows : FixedArray[Map[String, Param]]
  error : String?
} derive(ToJson, FromJson, Eq)

///|
pub impl Show for QueryResult with fn output(
  self : QueryResult,
  logger : &Logger,
) {
  write_json_show(self, logger)
}
