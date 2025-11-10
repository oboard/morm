///|
// ---- SQL 方言支持 ----
pub(all) enum Dialect {
  MySQL
  Sqlite3
  PgSQL
  SqlServer
  Oracle
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)
