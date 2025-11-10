///|
// 数据库列类型枚举
pub(all) enum ColumnType {
  // 整数类型
  TinyInt
  SmallInt
  MediumInt
  Int
  BigInt
  // 浮点类型
  Float
  Double
  Decimal(Int, Int) // precision, scale
  // 字符串类型
  Char(Int) // length
  VarChar(Int) // length
  Text
  MediumText
  LongText
  // 二进制类型
  Binary(Int) // length
  VarBinary(Int) // length
  Blob
  MediumBlob
  LongBlob
  // 日期时间类型
  Date
  Time
  DateTime
  Timestamp
  Year
  // JSON 类型
  Json
  JsonB
  // 布尔类型
  Boolean
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// 数据库列定义
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
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// ---- 列构建器函数 ----
pub fn Column::new(name : String, column_type : ColumnType) -> Column {
  {
    name,
    column_type,
    size: match column_type {
      VarChar(len) => len
      Char(len) => len
      Binary(len) => len
      VarBinary(len) => len
      _ => 0
    },
    nullable: true,
    default_value: None,
    auto_increment: false,
    primary_key: false,
    unique: false,
    comment: "",
    charset: None,
    collation: None,
  }
}
