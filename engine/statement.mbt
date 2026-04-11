///|
pub(all) struct SelectStatement {
  select : String
  from : String
  joins : FixedArray[String]
  where_ : FixedArray[Where]
  order_by : FixedArray[OrderBy]
  limit : Int?
  offset : Int?
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for SelectStatement with output(
  self : SelectStatement,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct InsertStatement {
  into : String
  columns : FixedArray[String]
  values : FixedArray[Param]
  rows : FixedArray[FixedArray[Param]]
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for InsertStatement with output(
  self : InsertStatement,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct UpsertStatement {
  table : String
  sets : FixedArray[Set]
  conflict_target : FixedArray[String]
  update_sets : FixedArray[Set]
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for UpsertStatement with output(
  self : UpsertStatement,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct UpdateStatement {
  table : String
  sets : FixedArray[Set]
  where_ : FixedArray[Where]
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for UpdateStatement with output(
  self : UpdateStatement,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct DeleteStatement {
  from : String
  where_ : FixedArray[Where]
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for DeleteStatement with output(
  self : DeleteStatement,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) enum Statement {
  Select(SelectStatement)
  Insert(InsertStatement)
  Upsert(UpsertStatement)
  Update(UpdateStatement)
  Delete(DeleteStatement)
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Statement with output(self : Statement, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) enum TxOp {
  Begin
  Commit
  Rollback
  Savepoint(String)
  RollbackToSavepoint(String)
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for TxOp with output(self : TxOp, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) enum Query {
  Statement(Statement)
  Raw(String, FixedArray[Param])
  Tx(TxOp)
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Query with output(self : Query, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub impl QueryBuilder for Query with to_query(self) -> Query {
  self
}
