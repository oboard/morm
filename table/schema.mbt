///|
fn[T : ToJson] write_json_show(value : T, logger : &Logger) -> Unit {
  logger.write_string(value.to_json().stringify())
}

///|
pub(all) enum ColumnType {
  TinyInt
  SmallInt
  MediumInt
  Int
  BigInt
  Float
  Double
  Decimal(Int, Int)
  Char(Int)
  VarChar(Int)
  Text
  MediumText
  LongText
  Binary(Int)
  VarBinary(Int)
  Blob
  MediumBlob
  LongBlob
  Date
  Time
  DateTime
  Timestamp
  Year
  Json
  JsonB
  Enum(String, FixedArray[String])
  Boolean
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for ColumnType with output(self : ColumnType, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) struct ColumnEngineOption {
  key : String
  value : String
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for ColumnEngineOption with output(
  self : ColumnEngineOption,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct Column {
  name : String
  column_type : ColumnType
  size : Int
  nullable : Bool
  default_value : String?
  auto_increment : Bool
  primary_key : Bool
  unique : Bool
  comment : String
  charset : String?
  collation : String?
  engine_options : FixedArray[ColumnEngineOption]
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for Column with output(self : Column, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) enum IndexType {
  Primary
  Unique
  Index
  FullText
  Spatial
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for IndexType with output(self : IndexType, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) struct Index {
  name : String
  index_type : IndexType
  columns : FixedArray[String]
  comment : String
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for Index with output(self : Index, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) struct ForeignKey {
  name : String
  column : String
  referenced_table : String
  referenced_column : String
  on_delete : String
  on_update : String
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for ForeignKey with output(self : ForeignKey, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) struct TableEngineOption {
  key : String
  value : String
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for TableEngineOption with output(
  self : TableEngineOption,
  logger : &Logger,
) {
  write_json_show(self, logger)
}

///|
pub(all) struct Table {
  name : String
  schema : String?
  catalog : String?
  columns : FixedArray[Column]
  indexes : FixedArray[Index]
  foreign_keys : FixedArray[ForeignKey]
  temporary : Bool
  if_not_exists : Bool
  engine : String?
  charset : String?
  collation : String?
  tablespace : String?
  comment : String
  auto_increment : Int?
  engine_options : FixedArray[TableEngineOption]
} derive(ToJson, FromJson, Eq, Compare, Hash)

///|
pub impl Show for Table with output(self : Table, logger : &Logger) {
  write_json_show(self, logger)
}
