///|
pub(open) trait Entity: ToJson {
  table(Self) -> Table
}

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
// 索引类型
pub(all) enum IndexType {
  Primary
  Unique
  Index
  FullText
  Spatial
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// 索引定义
pub(all) struct Index {
  name : String
  index_type : IndexType
  columns : FixedArray[String]
  comment : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// 外键约束
pub(all) struct ForeignKey {
  name : String
  column : String
  referenced_table : String
  referenced_column : String
  on_delete : String // CASCADE, SET NULL, RESTRICT, NO ACTION
  on_update : String // CASCADE, SET NULL, RESTRICT, NO ACTION
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

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

///|
pub fn not_null(col : Column) -> Column {
  { ..col, nullable: false }
}

///|
pub fn primary_key(col : Column) -> Column {
  { ..col, nullable: false, primary_key: true }
}

///|
pub fn auto_increment(col : Column) -> Column {
  { ..col, nullable: false, auto_increment: true, primary_key: true }
}

///|
pub fn unique(col : Column) -> Column {
  { ..col, unique: true }
}

///|
pub fn default_value(col : Column, value : String) -> Column {
  { ..col, default_value: Some(value) }
}

///|
pub fn comment(col : Column, text : String) -> Column {
  { ..col, comment: text }
}

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

///|
pub fn add_column(table : Table, col : Column) -> Table {
  let new_columns = Array::new()
  for column in table.columns {
    new_columns.push(column)
  }
  new_columns.push(col)
  { ..table, columns: FixedArray::from_array(new_columns) }
}

///|
pub fn add_index(table : Table, idx : Index) -> Table {
  let new_indexes = Array::new()
  for index in table.indexes {
    new_indexes.push(index)
  }
  new_indexes.push(idx)
  { ..table, indexes: FixedArray::from_array(new_indexes) }
}

///|
pub fn add_foreign_key(table : Table, fk : ForeignKey) -> Table {
  let new_fks = Array::new()
  for foreign_key in table.foreign_keys {
    new_fks.push(foreign_key)
  }
  new_fks.push(fk)
  { ..table, foreign_keys: FixedArray::from_array(new_fks) }
}

///|
pub fn table_comment(table : Table, text : String) -> Table {
  { ..table, comment: text }
}

///|
pub fn table_engine(table : Table, engine : String) -> Table {
  { ..table, engine, }
}

///|
// ---- 索引构建器函数 ----
pub fn Index::new(name : String, columns : FixedArray[String]) -> Index {
  { name, index_type: Index, columns, comment: "" }
}

///|
pub fn Index::new_unique(name : String, columns : FixedArray[String]) -> Index {
  { name, index_type: Unique, columns, comment: "" }
}

///|
pub fn Index::new_primary(columns : FixedArray[String]) -> Index {
  { name: "PRIMARY", index_type: Primary, columns, comment: "" }
}

///|
// ---- 外键构建器函数 ----
pub fn ForeignKey::new(
  name : String,
  column : String,
  referenced_table : String,
  referenced_column : String,
) -> ForeignKey {
  {
    name,
    column,
    referenced_table,
    referenced_column,
    on_delete: "RESTRICT",
    on_update: "RESTRICT",
  }
}

///|
pub fn on_delete_cascade(fk : ForeignKey) -> ForeignKey {
  {
    name: fk.name,
    column: fk.column,
    referenced_table: fk.referenced_table,
    referenced_column: fk.referenced_column,
    on_delete: "CASCADE",
    on_update: fk.on_update,
  }
}

///|
pub fn on_update_cascade(fk : ForeignKey) -> ForeignKey {
  {
    name: fk.name,
    column: fk.column,
    referenced_table: fk.referenced_table,
    referenced_column: fk.referenced_column,
    on_delete: fk.on_delete,
    on_update: "CASCADE",
  }
}

///|
// ---- 类型推断辅助函数 ----
pub fn infer_column_type(value : Json) -> ColumnType {
  match value {
    Number(n, ..) => if n.to_int().to_double() == n { Int } else { Double }
    String(_) => VarChar(255)
    _ => Text
  }
}

///|
// ---- DB/Driver error & result types ----
pub(all) struct DbError {
  message : String
} derive(Show, ToJson)

///|
pub type DbResult[T] = Result[T, DbError]

///|
// ---- Driver 接口定义 ----
pub(open) trait Driver {
  open(Self, dsn : String) -> DbResult[Self]
  close(Self) -> DbResult[Self]
  ping(Self) -> DbResult[Unit]
  exec(Self, sql : String, args : FixedArray[Json]) -> DbResult[Unit]
  query(Self, sql : String, args : FixedArray[Json]) -> DbResult[
    FixedArray[Json],
  ]
}

///|
// ---- 简易查询构建器 ----
pub struct Query {
  sql : String
  has_where : Bool
} derive(Show, ToJson)

///|
pub fn select_from(table : String) -> Query {
  { sql: "SELECT * FROM " + table, has_where: false }
}

///|
pub fn select_raw(table : String, cols_expr : String) -> Query {
  { sql: "SELECT " + cols_expr + " FROM " + table, has_where: false }
}

///|
pub fn where_eq(q : Query, col : String) -> Query {
  let prefix = if q.has_where { " AND " } else { " WHERE " }
  { sql: q.sql + prefix + col + " = ?", has_where: true }
}

///|
pub fn order_by(q : Query, expr : String) -> Query {
  { sql: q.sql + " ORDER BY " + expr, has_where: q.has_where }
}

///|
pub fn limit(q : Query, n : Int) -> Query {
  { sql: q.sql + " LIMIT " + n.to_string(), has_where: q.has_where }
}

///|
pub fn offset(q : Query, n : Int) -> Query {
  { sql: q.sql + " OFFSET " + n.to_string(), has_where: q.has_where }
}

///|
pub fn to_mysql_sql(q : Query) -> (String, FixedArray[Json]) {
  (q.sql, [])
}
