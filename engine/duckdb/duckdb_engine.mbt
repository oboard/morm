///|
pub struct DuckDBEngine {
  conn : @driver.Connection
  mut closed : Bool
}

///|
fn[T] native_callback(
  action : ((Result[T, @driver.DuckDBError]) -> Unit) -> Unit,
) -> Result[T, String] {
  let mut outcome : Result[T, String] = Err("DuckDB operation did not complete")
  action(fn(result) {
    outcome = match result {
      Ok(value) => Ok(value)
      Err(@driver.DuckDBError::Message(message)) => Err(message)
    }
  })
  outcome
}

///|
/// Open a native DuckDB database at a file path or `:memory:`.
pub fn DuckDBEngine::open(path : String) -> Result[DuckDBEngine, String] {
  let dsn = match path.strip_prefix("jdbc:") {
    Some(rest) => rest.to_owned()
    None => path
  }
  let database_path = match dsn.strip_prefix("duckdb://") {
    Some(rest) => rest.to_owned()
    None => dsn
  }
  match
    native_callback(fn(complete) {
      @driver.connect(path=database_path, on_ready=complete)
    }) {
    Ok(conn) => Ok({ conn, closed: false })
    Err(error) => Err(error)
  }
}

///|
fn duckdb_placeholders(count : Int) -> String {
  let parts : Array[String] = []
  for _ in 0..<count {
    parts.push("?")
  }
  parts.join(", ")
}

///|
fn render_duckdb(
  query : &@morm/engine.QueryBuilder,
) -> (String, FixedArray[@morm/engine.Param]) {
  match query.to_query() {
    Statement(Insert(statement)) => {
      let (sql, params) = @morm/engine.render_default_sql(Insert(statement))
      (sql + " RETURNING *", params)
    }
    Statement(Upsert(statement)) => {
      let { table, sets, conflict_target, update_sets } = statement
      let columns = sets.map(set => set.col).join(", ")
      let mut sql = "INSERT INTO \{table} (\{columns}) VALUES (\{duckdb_placeholders(sets.length())}) ON CONFLICT"
      if !conflict_target.is_empty() {
        sql += " (\{conflict_target.join(", ")})"
      }
      if update_sets.is_empty() {
        sql += " DO NOTHING"
      } else {
        let assignments = update_sets.map(set => "\{set.col} = ?").join(", ")
        sql += " DO UPDATE SET \{assignments}"
      }
      sql += " RETURNING *"
      (sql, sets.map(set => set.value) + update_sets.map(set => set.value))
    }
    _ => @morm/engine.render_query_sql(query)
  }
}

///|
fn bind_duckdb_param(
  statement : @driver.PreparedStatement,
  index : Int,
  value : @morm/engine.Param,
) -> Result[Unit, String] {
  let result = match value {
    Null | Json(Null) => statement.bind_null(index)
    Bool(value) => statement.bind_bool(index, value)
    Byte(value) => statement.bind_int(index, value.to_int())
    Int(value) => statement.bind_int(index, value)
    Int16(value) => statement.bind_int(index, value.to_int())
    UInt16(value) => statement.bind_int(index, value.to_int())
    UInt(value) => statement.bind_varchar(index, value.to_string())
    UInt64(value) => statement.bind_varchar(index, value.to_string())
    Int64(value) => statement.bind_varchar(index, value.to_string())
    BigInt(value) => statement.bind_varchar(index, value.to_string())
    Float(value) => statement.bind_double(index, value.to_double())
    Double(value) => statement.bind_double(index, value)
    Decimal(value) => statement.bind_varchar(index, value)
    Date(value, format) =>
      statement.bind_varchar(
        index,
        @morm/engine.format_plain_date(value, format),
      )
    Time(value, format) =>
      statement.bind_varchar(
        index,
        @morm/engine.format_plain_time(value, format),
      )
    DateTime(value, format) =>
      statement.bind_varchar(
        index,
        @morm/engine.format_plain_date_time(value, format),
      )
    Timestamp(value, format) =>
      statement.bind_varchar(
        index,
        @morm/engine.format_zoned_date_time(value, format),
      )
    Uuid(value) => statement.bind_varchar(index, value)
    Object(value) => statement.bind_varchar(index, value.to_json().stringify())
    Json(value) => statement.bind_varchar(index, value.stringify())
    String(value) => statement.bind_varchar(index, value)
    Bytes(value) => statement.bind_blob(index, value)
  }
  match result {
    Ok(_) => Ok(())
    Err(@driver.DuckDBError::Message(message)) => Err(message)
  }
}

///|
fn duckdb_hex_digit(value : Byte) -> Int? {
  let code = value.to_int()
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 65 && code <= 70 {
    Some(code - 55)
  } else if code >= 97 && code <= 102 {
    Some(code - 87)
  } else {
    None
  }
}

///|
fn duckdb_blob_from_text(value : String) -> Bytes {
  let input = @utf8.encode(value)
  let output : Array[Byte] = []
  let mut offset = 0
  while offset < input.length() {
    if offset + 3 < input.length() &&
      input[offset] == 92 &&
      input[offset + 1] == 120 {
      match
        (
          duckdb_hex_digit(input[offset + 2]),
          duckdb_hex_digit(input[offset + 3]),
        ) {
        (Some(high), Some(low)) => {
          output.push((high * 16 + low).to_byte())
          offset += 4
          continue
        }
        _ => ()
      }
    }
    output.push(input[offset])
    offset += 1
  }
  Bytes::from_array(output)
}

///|
fn duckdb_timestamp_text(value : String, with_timezone : Bool) -> String {
  let text = if value.length() > 10 && value[10] == ' ' {
    value[:10].to_owned() + "T" + value[11:].to_owned()
  } else {
    value
  }
  if with_timezone {
    for index in 10..<text.length() {
      if text[index] is ('+' | '-') {
        let offset = text[index:].to_owned()
        if offset.length() == 3 {
          return text + ":00"
        }
        break
      }
    }
  }
  text
}

///|
fn duckdb_param_from_cell(
  value : String,
  column_type : @driver.ColumnType,
) -> @morm/engine.Param {
  match column_type {
    Boolean => Bool(value == "true")
    TinyInt | SmallInt | Integer | UTinyInt | USmallInt | IntegerLiteral =>
      Int(@string.parse_int(value)) catch {
        _ => String(value)
      }
    UInteger => UInt(@string.parse_uint(value)) catch { _ => String(value) }
    BigInt => Int64(@string.parse_int64(value)) catch { _ => String(value) }
    UBigInt => UInt64(@string.parse_uint64(value)) catch { _ => String(value) }
    HugeInt | UHugeInt => BigInt(BigInt::from_string(value))
    Float | Double =>
      Double(@string.parse_double(value)) catch {
        _ => String(value)
      }
    Decimal => Decimal(value)
    Blob => Bytes(duckdb_blob_from_text(value))
    Timestamp | TimestampS | TimestampMs | TimestampNs =>
      String(duckdb_timestamp_text(value, false))
    TimestampTz => String(duckdb_timestamp_text(value, true))
    _ => String(value)
  }
}

///|
fn duckdb_failed(message : String) -> @morm/engine.QueryResult {
  { ok: false, rows_affected: 0, rows: [], error: Some(message) }
}

///|
fn duckdb_result(
  sql : String,
  result : @driver.QueryResult,
) -> @morm/engine.QueryResult {
  let command = sql.trim().to_upper()
  let is_write = command.has_prefix("INSERT ") ||
    command.has_prefix("UPDATE ") ||
    command.has_prefix("DELETE ") ||
    command.has_prefix("MERGE ")
  if is_write &&
    !command.contains(" RETURNING ") &&
    result.columns.length() == 1 &&
    result.columns[0] == "Count" &&
    result.rows.length() == 1 {
    let affected = @string.parse_int(result.rows[0][0]) catch { _ => 0 }
    return { ok: true, rows_affected: affected, rows: [], error: None }
  }
  let rows : Array[Map[String, @morm/engine.Param]] = []
  for row_index in 0..<result.rows.length() {
    let row : Map[String, @morm/engine.Param] = Map([])
    for column_index in 0..<result.columns.length() {
      if result.column_types[column_index] is TimestampTz &&
        !result.nulls[row_index][column_index] &&
        result.rows[row_index][column_index] == "" {
        return duckdb_failed(
          "DuckDB binding cannot decode TIMESTAMPTZ; cast the column to VARCHAR when selecting it",
        )
      }
      row[result.columns[column_index]] = if result.nulls[row_index][column_index] {
        Null
      } else {
        duckdb_param_from_cell(
          result.rows[row_index][column_index],
          result.column_types[column_index],
        )
      }
    }
    rows.push(row)
  }
  {
    ok: true,
    rows_affected: if is_write {
      rows.length()
    } else {
      0
    },
    rows: FixedArray::from_array(rows),
    error: None,
  }
}

///|
fn DuckDBEngine::exec_sql(
  self : DuckDBEngine,
  sql : String,
  params : FixedArray[@morm/engine.Param],
) -> @morm/engine.QueryResult {
  if self.closed {
    return duckdb_failed("DuckDB connection is closed")
  }
  let response : Result[@driver.QueryResult, String] = if params.is_empty() {
    native_callback(fn(complete) { self.conn.query(sql, on_done=complete) })
  } else {
    let statement = match
      native_callback(fn(complete) { self.conn.prepare(sql, on_done=complete) }) {
      Ok(statement) => statement
      Err(message) => return duckdb_failed(message)
    }
    for index in 0..<params.length() {
      if bind_duckdb_param(statement, index + 1, params[index]) is Err(message) {
        ignore(
          native_callback(fn(complete) { statement.close(on_done=complete) }),
        )
        return duckdb_failed(message)
      }
    }
    let executed = native_callback(fn(complete) {
      statement.execute(on_done=complete)
    })
    let closed = native_callback(fn(complete) {
      statement.close(on_done=complete)
    })
    match (executed, closed) {
      (Err(message), _) | (_, Err(message)) => Err(message)
      (Ok(result), Ok(_)) => Ok(result)
    }
  }
  match response {
    Ok(result) => duckdb_result(sql, result)
    Err(message) => duckdb_failed(message)
  }
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn exec(
  self,
  query : &@morm/engine.QueryBuilder,
) -> @morm/engine.QueryResult {
  let (sql, params) = render_duckdb(query)
  self.exec_sql(sql, params)
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn exec_raw(
  self,
  sql : String,
  params : FixedArray[@morm/engine.Param],
) -> @morm/engine.QueryResult {
  self.exec(@morm/engine.Raw(sql, params))
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn page(
  self,
  query : &@morm/engine.QueryBuilder,
  pageable : @morm/engine.Pageable,
) -> @morm/engine.QueryResult {
  let normalized_page = if pageable.page < 1 { 1 } else { pageable.page }
  let offset = (normalized_page - 1) * pageable.size
  let page_query = match query.to_query() {
    Statement(Select(statement)) => {
      let order_by = match pageable.sort {
        Some(sort) =>
          statement.order_by +
          [
            match sort.direction {
              Asc => Asc(sort.property)
              Desc => Desc(sort.property)
            },
          ]
        None => statement.order_by
      }
      @morm/engine.Statement(
        Select({
          ..statement,
          order_by,
          limit: Some(pageable.size),
          offset: Some(offset),
        }),
      )
    }
    Raw(sql, params) =>
      Raw(sql + " LIMIT \{pageable.size} OFFSET \{offset}", params)
    other => other
  }
  self.exec(page_query)
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn page_raw(
  self,
  sql : String,
  params : FixedArray[@morm/engine.Param],
  pageable : @morm/engine.Pageable,
) -> @morm/engine.QueryResult {
  self.page(@morm/engine.Raw(sql, params), pageable)
}

///|
pub impl @morm/engine.Engine for DuckDBEngine with fn close(self) -> Unit {
  if !self.closed {
    self.closed = true
    ignore(native_callback(fn(complete) { self.conn.close(on_done=complete) }))
  }
}
