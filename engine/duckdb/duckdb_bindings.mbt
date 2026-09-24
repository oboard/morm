///|
#borrow(path)
extern "C" fn native_connect(path : Bytes) -> Connection = "duckdb_mb_connect"

///|
#borrow(conn)
extern "C" fn native_disconnect(conn : Connection) = "duckdb_mb_disconnect"

///|
#borrow(conn, sql)
extern "C" fn native_query(conn : Connection, sql : Bytes) -> NativeResult = "duckdb_mb_query"

///|
#borrow(result)
extern "C" fn native_result_destroy(result : NativeResult) = "duckdb_mb_result_destroy"

///|
#borrow(result)
extern "C" fn native_result_column_count(result : NativeResult) -> Int = "duckdb_mb_result_column_count"

///|
#borrow(result)
extern "C" fn native_result_row_count(result : NativeResult) -> Int = "duckdb_mb_result_row_count"

///|
#borrow(result)
extern "C" fn native_result_column_name(
  result : NativeResult,
  col : Int,
) -> Bytes = "duckdb_mb_result_column_name"

///|
#borrow(result)
extern "C" fn native_result_column_type(
  result : NativeResult,
  col : Int,
) -> Int = "duckdb_mb_result_column_type"

///|
#borrow(result)
extern "C" fn native_result_is_null(
  result : NativeResult,
  col : Int,
  row : Int,
) -> Bool = "duckdb_mb_result_is_null"

///|
#borrow(result)
extern "C" fn native_result_value(
  result : NativeResult,
  col : Int,
  row : Int,
) -> Bytes = "duckdb_mb_result_value"

///|
extern "C" fn native_last_error() -> Bytes = "duckdb_mb_last_error"

///|
#borrow(conn)
extern "C" fn native_is_null_conn(conn : Connection) -> Bool = "duckdb_mb_is_null_conn"

///|
#borrow(result)
extern "C" fn native_is_null_result(result : NativeResult) -> Bool = "duckdb_mb_is_null_result"

///|
#borrow(conn, sql)
extern "C" fn native_prepare(
  conn : Connection,
  sql : Bytes,
) -> PreparedStatement = "duckdb_mb_prepare"

///|
#borrow(stmt)
extern "C" fn native_statement_destroy(stmt : PreparedStatement) = "duckdb_mb_statement_destroy"

///|
#borrow(stmt)
extern "C" fn native_statement_error(stmt : PreparedStatement) -> Bytes = "duckdb_mb_statement_error"

///|
#borrow(stmt)
extern "C" fn native_is_null_statement(stmt : PreparedStatement) -> Bool = "duckdb_mb_is_null_statement"

///|
#borrow(stmt)
extern "C" fn native_bind_int(
  stmt : PreparedStatement,
  index : Int,
  value : Int,
) -> Bool = "duckdb_mb_bind_int"

///|
#borrow(stmt)
extern "C" fn native_bind_double(
  stmt : PreparedStatement,
  index : Int,
  value : Double,
) -> Bool = "duckdb_mb_bind_double"

///|
#borrow(stmt, value)
extern "C" fn native_bind_varchar(
  stmt : PreparedStatement,
  index : Int,
  value : Bytes,
) -> Bool = "duckdb_mb_bind_varchar"

///|
#borrow(stmt)
extern "C" fn native_bind_bool(
  stmt : PreparedStatement,
  index : Int,
  value : Bool,
) -> Bool = "duckdb_mb_bind_bool"

///|
#borrow(stmt)
extern "C" fn native_bind_null(stmt : PreparedStatement, index : Int) -> Bool = "duckdb_mb_bind_null"

///|
#borrow(stmt, value)
extern "C" fn native_bind_blob(
  stmt : PreparedStatement,
  index : Int,
  value : Bytes,
  length : Int,
) -> Bool = "duckdb_mb_bind_blob"

///|
#borrow(stmt)
extern "C" fn native_execute_prepared(stmt : PreparedStatement) -> NativeResult = "duckdb_mb_execute_prepared"

///|
fn bytes_to_string(bytes : Bytes) -> String {
  @encoding/utf8.decode_lossy(bytes)
}

///|
fn last_error(fallback : String) -> String {
  let message = bytes_to_string(native_last_error())
  if message is "" {
    fallback
  } else {
    message
  }
}

///|
fn statement_error(statement : PreparedStatement, fallback : String) -> String {
  let message = bytes_to_string(native_statement_error(statement))
  if message is "" {
    fallback
  } else {
    message
  }
}

///|
fn read_native_result(result : NativeResult) -> QueryResult {
  let column_count = native_result_column_count(result)
  let row_count = native_result_row_count(result)
  let columns : Array[String] = []
  let column_types : Array[ColumnType] = []
  for column in 0..<column_count {
    columns.push(bytes_to_string(native_result_column_name(result, column)))
    column_types.push(
      column_type_from_id(native_result_column_type(result, column)),
    )
  }
  let rows : Array[Array[String]] = []
  let nulls : Array[Array[Bool]] = []
  for row in 0..<row_count {
    let row_values : Array[String] = []
    let row_nulls : Array[Bool] = []
    for column in 0..<column_count {
      let is_null = native_result_is_null(result, column, row)
      row_nulls.push(is_null)
      row_values.push(
        if is_null {
          ""
        } else {
          bytes_to_string(native_result_value(result, column, row))
        },
      )
    }
    rows.push(row_values)
    nulls.push(row_nulls)
  }
  native_result_destroy(result)
  { columns, column_types, rows, nulls, }
}

///|
fn connect(
  on_ready~ : (Result[Connection, DuckDBError]) -> Unit,
  path? : String = ":memory:",
) -> Unit {
  let connection = native_connect(@encoding/utf8.encode(path))
  if native_is_null_conn(connection) {
    on_ready(Err(DuckDBError::Message(last_error("duckdb_open failed"))))
  } else {
    on_ready(Ok(connection))
  }
}

///|
fn Connection::close(
  self : Connection,
  on_done~ : (Result[Unit, DuckDBError]) -> Unit,
) -> Unit {
  native_disconnect(self)
  on_done(Ok(()))
}

///|
fn Connection::query(
  self : Connection,
  sql : String,
  on_done~ : (Result[QueryResult, DuckDBError]) -> Unit,
) -> Unit {
  let result = native_query(self, @encoding/utf8.encode(sql))
  if native_is_null_result(result) {
    on_done(Err(DuckDBError::Message(last_error("duckdb_query failed"))))
  } else {
    on_done(Ok(read_native_result(result)))
  }
}

///|
fn Connection::prepare(
  self : Connection,
  sql : String,
  on_done~ : (Result[PreparedStatement, DuckDBError]) -> Unit,
) -> Unit {
  let statement = native_prepare(self, @encoding/utf8.encode(sql))
  if native_is_null_statement(statement) {
    on_done(
      Err(
        DuckDBError::Message(
          statement_error(statement, "duckdb_prepare failed"),
        ),
      ),
    )
  } else {
    on_done(Ok(statement))
  }
}

///|
fn PreparedStatement::bind_int(
  self : PreparedStatement,
  index : Int,
  value : Int,
) -> Result[Unit, DuckDBError] {
  if native_bind_int(self, index, value) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_int failed")))
  }
}

///|
fn PreparedStatement::bind_double(
  self : PreparedStatement,
  index : Int,
  value : Double,
) -> Result[Unit, DuckDBError] {
  if native_bind_double(self, index, value) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_double failed")))
  }
}

///|
fn PreparedStatement::bind_varchar(
  self : PreparedStatement,
  index : Int,
  value : String,
) -> Result[Unit, DuckDBError] {
  if native_bind_varchar(self, index, @encoding/utf8.encode(value)) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_varchar failed")))
  }
}

///|
fn PreparedStatement::bind_bool(
  self : PreparedStatement,
  index : Int,
  value : Bool,
) -> Result[Unit, DuckDBError] {
  if native_bind_bool(self, index, value) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_bool failed")))
  }
}

///|
fn PreparedStatement::bind_null(
  self : PreparedStatement,
  index : Int,
) -> Result[Unit, DuckDBError] {
  if native_bind_null(self, index) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_null failed")))
  }
}

///|
fn PreparedStatement::bind_blob(
  self : PreparedStatement,
  index : Int,
  value : Bytes,
) -> Result[Unit, DuckDBError] {
  if native_bind_blob(self, index, value, value.length()) {
    Ok(())
  } else {
    Err(DuckDBError::Message(statement_error(self, "bind_blob failed")))
  }
}

///|
fn PreparedStatement::execute(
  self : PreparedStatement,
  on_done~ : (Result[QueryResult, DuckDBError]) -> Unit,
) -> Unit {
  let result = native_execute_prepared(self)
  if native_is_null_result(result) {
    on_done(
      Err(
        DuckDBError::Message(statement_error(self, "execute_prepared failed")),
      ),
    )
  } else {
    on_done(Ok(read_native_result(result)))
  }
}

///|
fn PreparedStatement::close(
  self : PreparedStatement,
  on_done~ : (Result[Unit, DuckDBError]) -> Unit,
) -> Unit {
  native_statement_destroy(self)
  on_done(Ok(()))
}
