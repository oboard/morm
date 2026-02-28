///|
struct SQLiteEngine {
  conn : Connection
}

///|
pub fn SQLiteEngine::open(filename : String) -> SQLiteEngine {
  { conn: try! Connection::open(filename) }
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
fn format_where_sql(where_ : FixedArray[@engine.Where]) -> String {
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
fn format_set_sql(sets : FixedArray[@engine.Set]) -> String {
  sets.map(s => [s.col, "=", "?"].join(" ")).join(", ")
}

///|
fn get_string(
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
fn get_bool(obj : Map[String, Json], key : String, default : Bool) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => default
  }
}

///|
fn get_engine_option(
  obj : Map[String, Json],
  key : String,
  default : String,
) -> String {
  match obj.get("engine_options") {
    Some([.. options]) => {
      for option in options {
        if option is Object(option_obj) &&
          get_string(option_obj, "key", "") == key {
          return get_string(option_obj, "value", default)
        }
      }
      default
    }
    _ => default
  }
}

///|
fn sqlite_table_name(obj : Map[String, Json], name : String) -> String {
  let schema = get_string(obj, "schema", "")
  let catalog = get_string(obj, "catalog", "")
  let table_ns = if schema != "" { schema } else { catalog }
  if table_ns != "" {
    "\{table_ns}.\{name}"
  } else {
    name
  }
}

///|
fn json_array_values(v : Json) -> Array[Json] {
  match v {
    Array(arr) => arr
    _ => []
  }
}

///|
fn sqlite_col_type(v : Json) -> String {
  let map_name = fn(name : String) -> String {
    match name {
      "TinyInt" | "SmallInt" | "MediumInt" | "Int" | "BigInt" | "Year" =>
        "INTEGER"
      "Float" | "Double" | "Decimal" => "REAL"
      "Boolean" => "INTEGER"
      "Blob" | "MediumBlob" | "LongBlob" | "Binary" | "VarBinary" => "BLOB"
      "Date" | "Time" | "DateTime" | "Timestamp" => "TEXT"
      "Json" | "JsonB" => "TEXT"
      "Char" | "VarChar" | "Text" | "MediumText" | "LongText" => "TEXT"
      _ => "TEXT"
    }
  }
  match v {
    String(name) => map_name(name)
    Array(arr) =>
      if arr is [String(name), ..] {
        map_name(name)
      } else {
        "TEXT"
      }
    _ => "TEXT"
  }
}

///|
fn render_column_def(col_json : Json) -> String {
  if col_json is Object(obj) {
    let name = get_string(obj, "name", "")
    let primary_key = get_bool(obj, "primary_key", false)
    let auto_increment = get_bool(obj, "auto_increment", false)
    let nullable = get_bool(obj, "nullable", true)
    let unique = get_bool(obj, "unique", false)
    let col_type = match obj.get("column_type") {
      Some(v) => sqlite_col_type(v)
      None => "TEXT"
    }
    let parts : Array[String] = [name]
    if primary_key && auto_increment {
      parts.push("INTEGER")
      parts.push("PRIMARY KEY")
      parts.push("AUTOINCREMENT")
    } else {
      parts.push(col_type)
      if primary_key {
        parts.push("PRIMARY KEY")
      }
      if !nullable {
        parts.push("NOT NULL")
      }
      if unique {
        parts.push("UNIQUE")
      }
    }
    parts.join(" ")
  } else {
    ""
  }
}

///|
fn render_fk_def(fk_json : Json) -> String {
  if fk_json is Object(obj) {
    let col = get_string(obj, "column", "")
    let ref_table = get_string(obj, "referenced_table", "")
    let ref_col = get_string(obj, "referenced_column", "")
    if col == "" || ref_table == "" || ref_col == "" {
      return ""
    }
    let mut s = "FOREIGN KEY (\{col}) REFERENCES \{ref_table}(\{ref_col})"
    let on_delete = get_string(obj, "on_delete", "")
    let on_update = get_string(obj, "on_update", "")
    if on_delete != "" {
      s = s + " ON DELETE " + on_delete
    }
    if on_update != "" {
      s = s + " ON UPDATE " + on_update
    }
    s
  } else {
    ""
  }
}

///|
fn render_create_table_sql(table_schema : Json) -> String {
  if table_schema is Object(obj) {
    let base_name = get_string(obj, "name", "")
    if base_name == "" {
      return ""
    }
    let table_name = sqlite_table_name(obj, base_name)
    let column_defs : Array[String] = []
    match obj.get("columns") {
      Some(v) =>
        for c in json_array_values(v) {
          let def = render_column_def(c)
          if def != "" {
            column_defs.push(def)
          }
        }
      None => ()
    }
    match obj.get("foreign_keys") {
      Some(v) =>
        for fk in json_array_values(v) {
          let fk_def = render_fk_def(fk)
          if fk_def != "" {
            column_defs.push(fk_def)
          }
        }
      None => ()
    }
    let defs = column_defs.join(", ")
    let temporary = get_bool(obj, "temporary", false)
    let if_not_exists = get_bool(obj, "if_not_exists", true)
    let create_prefix = if temporary {
      "CREATE TEMPORARY TABLE"
    } else {
      "CREATE TABLE"
    }
    let mut sql = if if_not_exists {
      "\{create_prefix} IF NOT EXISTS \{table_name} (\{defs})"
    } else {
      "\{create_prefix} \{table_name} (\{defs})"
    }
    let create_suffix = get_engine_option(obj, "create_suffix", "")
    if create_suffix != "" {
      sql = sql + " " + create_suffix
    }
    sql
  } else {
    ""
  }
}

///|
fn render_index_sqls(table_schema : Json) -> Array[String] {
  if table_schema is Object(obj) {
    let base_name = get_string(obj, "name", "")
    if base_name == "" {
      return []
    }
    let table_name = sqlite_table_name(obj, base_name)
    let sqls : Array[String] = []
    match obj.get("indexes") {
      Some(v) =>
        for idx_json in json_array_values(v) {
          if idx_json is Object(idx) {
            let idx_name = get_string(idx, "name", "")
            let idx_type = get_string(idx, "index_type", "")
            if idx_name == "" || idx_name == "PRIMARY" {
              continue
            }
            let cols : Array[String] = []
            match idx.get("columns") {
              Some(cols_json) =>
                for c in json_array_values(cols_json) {
                  match c {
                    String(name) => cols.push(name)
                    _ => ()
                  }
                }
              None => ()
            }
            if cols.length() == 0 {
              continue
            }
            let unique = if idx_type == "Unique" { "UNIQUE " } else { "" }
            let cols_sql = cols.join(", ")
            sqls.push(
              "CREATE \{unique}INDEX IF NOT EXISTS \{idx_name} ON \{table_name} (\{cols_sql})",
            )
          }
        }
      None => ()
    }
    sqls
  } else {
    []
  }
}

///|
fn render_sqlite(
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
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
      let { table, sets, conflict_target, update_sets } = upsert_stmt
      let buf = @buffer.new()
      buf.write_string("INSERT INTO ")
      buf.write_string(table)
      buf.write_string(" (")
      buf.write_string(sets.map(s => s.col).join(", "))
      buf.write_string(") VALUES (")
      buf.write_string(placeholders(sets.length()))
      buf.write_string(")")
      if !conflict_target.is_empty() {
        buf.write_string(" ON CONFLICT (")
        buf.write_string(conflict_target.join(", "))
        buf.write_string(")")
      }
      if !update_sets.is_empty() {
        buf.write_string(" DO UPDATE SET ")
        buf.write_string(format_set_sql(update_sets))
      } else {
        buf.write_string(" DO NOTHING")
      }
      buf.write_string(" RETURNING *")
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
impl @engine.Engine for SQLiteEngine with close(self) -> Unit {
  try! self.conn.close()
}

///|
impl @engine.Engine for SQLiteEngine with render(
  _self,
  stmt : @engine.Statement,
) -> (String, FixedArray[@engine.Param]) {
  render_sqlite(stmt)
}

///|
impl @engine.Engine for SQLiteEngine with tx_begin_sql(_self) -> String {
  "BEGIN"
}

///|
impl @engine.Engine for SQLiteEngine with tx_commit_sql(_self) -> String {
  "COMMIT"
}

///|
impl @engine.Engine for SQLiteEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK"
}

///|
impl @engine.Engine for SQLiteEngine with tx_savepoint_sql(_self, name : String) -> String {
  "SAVEPOINT " + name
}

///|
impl @engine.Engine for SQLiteEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TO SAVEPOINT " + name
}

///|
impl @engine.Engine for SQLiteEngine with migrate_table(
  self,
  table_schema : Json,
) -> @engine.QueryResult {
  let create_sql = render_create_table_sql(table_schema)
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
  for sql in render_index_sqls(table_schema) {
    let res = self.exec_raw(sql, [])
    if !res.ok {
      return res
    }
  }
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
impl @engine.Engine for SQLiteEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  let mut error = None
  let rows = []
  println(sql + ";")
  println(params.to_json().stringify())
  try {
    let stmt = self.conn.prepare(sql + ";")
    params.eachi((index, val) => {
      match val {
        @engine.Double(v) => stmt.bind(index~, val=v)
        @engine.Float(v) => stmt.bind(index~, val=v.to_double())
        @engine.Byte(v) => stmt.bind(index~, val=v.to_int())
        @engine.Int(v) => stmt.bind(index~, val=v)
        @engine.Int16(v) => stmt.bind(index~, val=v.to_int())
        @engine.UInt16(v) => stmt.bind(index~, val=v.to_int())
        @engine.UInt(v) => stmt.bind(index~, val=v.to_string())
        @engine.UInt64(v) => stmt.bind(index~, val=v.to_string())
        @engine.Int64(v) => stmt.bind(index~, val=v)
        @engine.BigInt(v) => stmt.bind(index~, val=v.to_string())
        @engine.Decimal(v) => stmt.bind(index~, val=v)
        @engine.Date(v) => stmt.bind(index~, val=v.to_string())
        @engine.Time(v) => stmt.bind(index~, val=v.to_string())
        @engine.DateTime(v) => stmt.bind(index~, val=v.to_string())
        @engine.Timestamp(v) => stmt.bind(index~, val=v.to_string())
        @engine.Uuid(v) => stmt.bind(index~, val=v)
        @engine.Json(v) => stmt.bind(index~, val=v.stringify())
        @engine.String(v) => stmt.bind(index~, val=v)
        @engine.Bytes(v) => stmt.bind(index~, val=v)
        @engine.Bool(v) => stmt.bind(index~, val=if v { 1 } else { 0 })
        @engine.Null => stmt.bind_null(index~)
      }
    })
    // 构造第一行的 Json（按列名 -> 值）

    while stmt.step() == true {
      let obj : Map[String, Json] = {}
      let col_cnt = stmt.column_count()
      let mut index = 0
      while index < col_cnt {
        let name = stmt.column_name(index~)
        match stmt.column_type(index~) {
          SQLITE_NULL => obj[name] = Json::null()
          SQLITE_INTEGER => {
            let v : Int = stmt.column(index~)
            obj[name] = Json::number(v.to_double())
          }
          SQLITE_FLOAT => {
            let v = stmt.column(index~)
            obj[name] = Json::number(v)
          }
          SQLITE_TEXT => {
            let s = stmt.column(index~)
            obj[name] = Json::string(s)
          }
          SQLITE_BLOB => {
            let b : Bytes = stmt.column(index~)
            obj[name] = b.to_json()
          }
          _ => {
            let s = stmt.column_blob_as_string(index~)
            obj[name] = Json::string(s)
          }
        }
        index = index + 1
      }
      rows.push(obj.to_json())
    }
    stmt.finalize()
  } catch {
    SqliteError(err) => {
      println(err)
      error = Some(err.to_string())
    }
  }
  {
    ok: error is None,
    rows_affected: 0,
    rows: FixedArray::from_array(rows),
    error,
  }
}

///|
impl @engine.Engine for SQLiteEngine with preload_in_sql(
  _self,
  table : String,
  key_col : String,
  count : Int,
) -> String {
  @engine.preload_in_sql_qmark(table, key_col, count)
}

///|
impl @engine.Engine for SQLiteEngine with preload_many_to_many_sql(
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
