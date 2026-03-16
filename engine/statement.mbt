///|
pub(all) struct SelectStatement {
  select : String
  from : String
  joins : FixedArray[String]
  where_ : FixedArray[Where]
  order_by : FixedArray[OrderBy]
  limit : Int?
  offset : Int?
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct InsertStatement {
  into : String
  columns : FixedArray[String]
  values : FixedArray[Param]
  rows : FixedArray[FixedArray[Param]]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct UpsertStatement {
  table : String
  sets : FixedArray[Set]
  conflict_target : FixedArray[String]
  update_sets : FixedArray[Set]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct UpdateStatement {
  table : String
  sets : FixedArray[Set]
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct DeleteStatement {
  from : String
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum Statement {
  Select(SelectStatement)
  Insert(InsertStatement)
  Upsert(UpsertStatement)
  Update(UpdateStatement)
  Delete(DeleteStatement)
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum TxOp {
  Begin
  Commit
  Rollback
  Savepoint(String)
  RollbackToSavepoint(String)
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum Query {
  Statement(Statement)
  Raw(String, FixedArray[Param])
  Tx(TxOp)
} derive(Eq, Show, ToJson, FromJson)
