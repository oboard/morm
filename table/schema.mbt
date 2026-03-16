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
  Boolean
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
pub(all) struct ColumnEngineOption {
  key : String
  value : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

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
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
pub(all) enum IndexType {
  Primary
  Unique
  Index
  FullText
  Spatial
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
pub(all) struct Index {
  name : String
  index_type : IndexType
  columns : FixedArray[String]
  comment : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
pub(all) struct ForeignKey {
  name : String
  column : String
  referenced_table : String
  referenced_column : String
  on_delete : String
  on_update : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
pub(all) struct TableEngineOption {
  key : String
  value : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

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
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)
