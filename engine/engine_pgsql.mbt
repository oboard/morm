///|
pub fn @morm.Query::to_pgsql_sql(self : @morm.Query) -> String {
  self.to_sql(PgSQL)
}

///|
pub fn @morm.InsertQuery::to_pgsql_sql(self : @morm.InsertQuery) -> String {
  self.to_sql(PgSQL)
}

///|
pub fn @morm.UpdateQuery::to_pgsql_sql(self : @morm.UpdateQuery) -> String {
  self.to_sql(PgSQL)
}

///|
pub fn @morm.DeleteQuery::to_pgsql_sql(self : @morm.DeleteQuery) -> String {
  self.to_sql(PgSQL)
}