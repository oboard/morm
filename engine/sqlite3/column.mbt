///|
trait Column {
  column(Statement, Int) -> Self
}

///|
extern "c" fn sqlite3_column_int(stmt : Statement, col_index : Int) -> Int = "sqlite3_column_int"

///|
extern "c" fn sqlite3_column_int64(stmt : Statement, col_index : Int) -> Int64 = "sqlite3_column_int64"

///|
extern "c" fn sqlite3_column_bytes(stmt : Statement, col_index : Int) -> Bytes = "moonbit_sqlite3_column_bytes"

///|
extern "c" fn sqlite3_column_text(stmt : Statement, col_index : Int) -> String = "moonbit_sqlite3_column_text"

///|
extern "c" fn sqlite3_column_string(
  stmt : Statement,
  col_index : Int,
) -> String = "moonbit_sqlite3_column_string"

///|
extern "c" fn sqlite3_column_double(
  stmt : Statement,
  col_index : Int,
) -> Double = "sqlite3_column_double"

///|
/// Column metadata
extern "c" fn sqlite3_column_count(stmt : Statement) -> Int = "moonbit_sqlite3_column_count"

///|
extern "c" fn sqlite3_column_type(stmt : Statement, col_index : Int) -> Int = "moonbit_sqlite3_column_type"

///|
extern "c" fn sqlite3_column_name_bytes(
  stmt : Statement,
  col_index : Int,
) -> Bytes = "moonbit_sqlite3_column_name"

///|
pub impl Column for Int with column(stmt, index) {
  sqlite3_column_int(stmt, index)
}

///|
pub impl Column for Int64 with column(stmt, index) {
  sqlite3_column_int64(stmt, index)
}

///|
pub impl Column for Double with column(stmt, index) {
  sqlite3_column_double(stmt, index)
}

///|
pub impl Column for Bytes with column(stmt, index) {
  sqlite3_column_bytes(stmt, index)
}

///|
pub impl Column for String with column(stmt, index) {
  sqlite3_column_text(stmt, index)
}
