///|
pub(open) trait Engine {
  dialect(Self) -> @dialect.Dialect
  ///|
  /// Execute a SQL statement.
  exec(Self, sql : String, params : FixedArray[Json]) -> QueryResult
  ///|
  /// Close the database connection.
  close(Self) -> Unit
}

///|
pub(all) struct QueryResult {
  ok : Bool
  rows_affected : Int
  rows : FixedArray[Json]
  error : String?
} derive(Show, ToJson, FromJson, Eq)
