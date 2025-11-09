///|
pub fn @morm.Query::to_sqlite_sql(self : @morm.Query) -> String {
  self.to_sql(Sqlite3)
}

///|
pub fn @morm.InsertQuery::to_sqlite_sql(self : @morm.InsertQuery) -> String {
  self.to_sql(Sqlite3)
}

///|
pub fn @morm.UpdateQuery::to_sqlite_sql(self : @morm.UpdateQuery) -> String {
  self.to_sql(Sqlite3)
}

///|
pub fn @morm.DeleteQuery::to_sqlite_sql(self : @morm.DeleteQuery) -> String {
  self.to_sql(Sqlite3)
}