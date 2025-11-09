///|
pub fn @morm.Query::to_sqlserver_sql(self : @morm.Query) -> String {
  self.to_sql(SqlServer)
}

///|
pub fn @morm.InsertQuery::to_sqlserver_sql(self : @morm.InsertQuery) -> String {
  self.to_sql(SqlServer)
}

///|
pub fn @morm.UpdateQuery::to_sqlserver_sql(self : @morm.UpdateQuery) -> String {
  self.to_sql(SqlServer)
}

///|
pub fn @morm.DeleteQuery::to_sqlserver_sql(self : @morm.DeleteQuery) -> String {
  self.to_sql(SqlServer)
}