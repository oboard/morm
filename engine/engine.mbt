///|
pub(open) trait Engine {
  dialect(Self) -> @dialect.Dialect
  ///|
  /// Connect to the database.
  /// The database connection string, e.g. "mysql://user:password@localhost:3306/dbname"
  open(url : String) -> Self
  ///|
  /// Execute a SQL statement.
  exec(Self, sql : String, params : Array[Json]) -> QueryResult
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
