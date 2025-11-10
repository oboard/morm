///|
// 数据库表定义
pub(all) struct Table {
  name : String
  columns : FixedArray[Column]
  indexes : FixedArray[Index]
  foreign_keys : FixedArray[ForeignKey]
  engine : String
  charset : String
  collation : String
  comment : String
  auto_increment : Int
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// ---- 表构建器函数 ----
pub fn Table::new(name : String, columns? : FixedArray[Column]) -> Table {
  {
    name,
    columns: columns.unwrap_or([]),
    indexes: [],
    foreign_keys: [],
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
  }
}
