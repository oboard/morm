///|
pub(all) struct TableEngineOption {
  key : String
  value : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// 数据库表定义
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

///|
// ---- 表构建器函数 ----
pub fn Table::new(
  name : String,
  columns? : FixedArray[Column],
  engine? : String,
) -> Table {
  {
    name,
    schema: None,
    catalog: None,
    columns: columns.unwrap_or([]),
    indexes: [],
    foreign_keys: [],
    temporary: false,
    if_not_exists: true,
    engine,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: [],
  }
}

///|
pub fn Table::primary_key(self : Table) -> String? {
  self.columns.fold(init=None, (acc, col) => {
    if col.primary_key {
      Some(col.name)
    } else {
      acc
    }
  })
}

///|
pub fn Table::has_primary_key(self : Table) -> Bool {
  self.primary_key() is Some(_)
}
