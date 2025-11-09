///|
pub fn @morm.Query::to_oracle_sql(self : @morm.Query) -> String {
  self.to_sql(Oracle)
}

///|
pub fn @morm.InsertQuery::to_oracle_sql(self : @morm.InsertQuery) -> String {
  self.to_sql(Oracle)
}

///|
pub fn @morm.UpdateQuery::to_oracle_sql(self : @morm.UpdateQuery) -> String {
  self.to_sql(Oracle)
}

///|
pub fn @morm.DeleteQuery::to_oracle_sql(self : @morm.DeleteQuery) -> String {
  self.to_sql(Oracle)
}