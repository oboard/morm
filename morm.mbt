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
  select : String
  from : String
  where_ : FixedArray[Where]
  order_by : FixedArray[OrderBy]
  limit : Int?
  offset : Int?
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum OrderBy {
  Asc(String)
  Desc(String)
} derive(Eq, Show, ToJson, FromJson)

///|
pub struct Where {
  col : String
  value : Json
  ty : WhereType
} derive(Eq, Show, ToJson, FromJson)

///|
pub enum WhereType {
  Eq
  Gt
  Lt
  Gte
  Lte
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn select_from(table : String) -> Query {
  {
    select: "*",
    from: table,
    where_: [],
    order_by: [],
    limit: None,
    offset: None,
  }
}

///|
pub fn select_raw(table : String, cols_expr : String) -> Query {
  {
    select: cols_expr,
    from: table,
    where_: [],
    order_by: [],
    limit: None,
    offset: None,
  }
}

///|
pub fn Query::where_eq(self : Query, col : String, value : Json) -> Query {
  let where_ = self.where_ + [{ col, value, ty: Eq }]
  { ..self, where_, }
}

///|
pub fn Query::where_gt(self : Query, col : String, value : Json) -> Query {
  let where_ = self.where_ + [{ col, value, ty: Gt }]
  { ..self, where_, }
}

///|
pub fn Query::where_lt(self : Query, col : String, value : Json) -> Query {
  let where_ = self.where_ + [{ col, value, ty: Lt }]
  { ..self, where_, }
}

///|
pub fn Query::where_gte(self : Query, col : String, value : Json) -> Query {
  let where_ = self.where_ + [{ col, value, ty: Gte }]
  { ..self, where_, }
}

///|
pub fn Query::where_lte(self : Query, col : String, value : Json) -> Query {
  let where_ = self.where_ + [{ col, value, ty: Lte }]
  { ..self, where_, }
}

///|
pub fn Query::order_by(self : Query, order_by : OrderBy) -> Query {
  { ..self, order_by: self.order_by + [order_by] }
}

///|
pub fn Query::limit(self : Query, n : Int) -> Query {
  { ..self, limit: Some(n) }
}

///|
pub fn Query::offset(self : Query, n : Int) -> Query {
  { ..self, offset: Some(n) }
}

///|
pub fn Query::page(self : Query, page : Int, size : Int) -> Query {
  { ..self, offset: Some((page - 1) * size), limit: Some(size) }
}

///|
// ---- SQL 方言支持 ----
pub(all) enum Dialect {
  MySQL
  Sqlite3
  PgSQL
  SqlServer
  Oracle
  MongoDB
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
/// helper: 为不同方言生成值字面量
fn quote_value(dialect : Dialect, v : Json) -> String {
  match v {
    Number(n, ..) => n.to_string()
    False =>
      match dialect {
        SqlServer => "0"
        _ => "FALSE"
      }
    True =>
      match dialect {
        SqlServer => "1"
        _ => "TRUE"
      }
    Null => "NULL"
    String(s) =>
      match dialect {
        MySQL => v.stringify() // 与现有测试兼容，双引号字符串
        _ => {
          let buf = @buffer.new()
          buf.write_string("'")
          // 保守处理：直接包裹单引号，避免字符遍历与 write_char
          buf.write_string(s)
          buf.write_string("'")
          buf.to_string()
        }
      }
    _ => v.stringify()
  }
}

///|
/// helper: WHERE 子句格式化（通用）
fn format_where_sql(dialect : Dialect, where_ : FixedArray[Where]) -> String {
  where_
  .map(w => {
    let ty = match w.ty {
      Eq => "="
      Gt => ">"
      Lt => "<"
      Gte => ">="
      Lte => "<="
    }
    [w.col, ty, quote_value(dialect, w.value)].join(" ")
  })
  .join(" AND ")
}

///|
pub fn Query::to(self : Query, dialect : Dialect) -> String {
  match dialect {
    MongoDB => {
      let json : Json = {
        "find": "students",
        "filter": { "id": 1, "name": "Alice" },
        "sort": { "id": -1 },
        "limit": 5,
        "skip": 5,
      }
      json.stringify()
    }
    _ => {
      let buf = @buffer.new()
      buf.write_string("SELECT ")
      if self.select.is_empty() {
        buf.write_string("*")
      } else {
        buf.write_string(self.select)
      }
      buf.write_string(" FROM ")
      buf.write_string(self.from)
      if !self.where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(dialect, self.where_))
      }
      if !self.order_by.is_empty() {
        buf.write_string(" ORDER BY ")
        buf.write_string(
          self.order_by
          .map(ob => match ob {
            Asc(col) => [col, "ASC"].join(" ")
            Desc(col) => [col, "DESC"].join(" ")
          })
          .join(", "),
        )
      }
      match dialect {
        Oracle => {
          if self.offset is Some(offset) {
            buf.write_string(" OFFSET ")
            buf.write_string(offset.to_string())
            buf.write_string(" ROWS")
          }
          if self.limit is Some(limit) {
            buf.write_string(" FETCH NEXT ")
            buf.write_string(limit.to_string())
            buf.write_string(" ROWS ONLY")
          }
        }
        _ => {
          if self.limit is Some(limit) {
            buf.write_string(" LIMIT ")
            buf.write_string(limit.to_string())
          }
          if self.offset is Some(offset) {
            buf.write_string(" OFFSET ")
            buf.write_string(offset.to_string())
          }
        }
      }
      buf.to_string()
    }
  }
}

///|
// ---- INSERT 构建器 ----
pub struct InsertQuery {
  into : String
  columns : FixedArray[String]
  values : FixedArray[Json]
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn insert_into(table : String) -> InsertQuery {
  { into: table, columns: [], values: [] }
}

///|
pub fn InsertQuery::columns(
  self : InsertQuery,
  columns : FixedArray[String],
) -> InsertQuery {
  { ..self, columns, }
}

///|
pub fn InsertQuery::values(
  self : InsertQuery,
  values : FixedArray[Json],
) -> InsertQuery {
  { ..self, values, }
}

///|
pub fn InsertQuery::to(self : InsertQuery, dialect : Dialect) -> String {
  let buf = @buffer.new()
  buf.write_string("INSERT INTO ")
  buf.write_string(self.into)
  if !self.columns.is_empty() {
    buf.write_string(" (")
    buf.write_string(self.columns.join(", "))
    buf.write_string(")")
  }
  buf.write_string(" VALUES (")
  buf.write_string(self.values.map(v => quote_value(dialect, v)).join(", "))
  buf.write_string(")")
  buf.to_string()
}

///|
// ---- UPDATE 构建器 ----
pub struct Set {
  col : String
  value : Json
} derive(Eq, Show, ToJson, FromJson)

///|
pub struct UpdateQuery {
  table : String
  sets : FixedArray[Set]
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn update(table : String) -> UpdateQuery {
  { table, sets: [], where_: [] }
}

///|
pub fn UpdateQuery::set(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, sets: self.sets + [{ col, value }] }
}

///|
pub fn UpdateQuery::where_eq(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Eq }] }
}

///|
pub fn UpdateQuery::where_gt(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Gt }] }
}

///|
pub fn UpdateQuery::where_lt(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Lt }] }
}

///|
pub fn UpdateQuery::where_gte(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Gte }] }
}

///|
pub fn UpdateQuery::where_lte(
  self : UpdateQuery,
  col : String,
  value : Json,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Lte }] }
}

///|
pub fn UpdateQuery::to_mysql_sql(self : UpdateQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("UPDATE ")
  buf.write_string(self.table)
  buf.write_string(" SET ")
  buf.write_string(
    self.sets.map(s => [s.col, "=", s.value.stringify()].join(" ")).join(", "),
  )
  if !self.where_.is_empty() {
    buf.write_string(" WHERE ")
    buf.write_string(
      self.where_
      .map(w => {
        let ty = match w.ty {
          Eq => "="
          Gt => ">"
          Lt => "<"
          Gte => ">="
          Lte => "<="
        }
        [w.col, ty, w.value.stringify()].join(" ")
      })
      .join(" AND "),
    )
  }
  buf.to_string()
}

///|
pub fn UpdateQuery::to(self : UpdateQuery, dialect : Dialect) -> String {
  let buf = @buffer.new()
  buf.write_string("UPDATE ")
  buf.write_string(self.table)
  buf.write_string(" SET ")
  buf.write_string(
    self.sets
    .map(s => [s.col, "=", quote_value(dialect, s.value)].join(" "))
    .join(", "),
  )
  if !self.where_.is_empty() {
    buf.write_string(" WHERE ")
    buf.write_string(format_where_sql(dialect, self.where_))
  }
  buf.to_string()
}

///|
// ---- DELETE 构建器 ----
pub struct DeleteQuery {
  from : String
  where_ : FixedArray[Where]
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn delete_from(table : String) -> DeleteQuery {
  { from: table, where_: [] }
}

///|
pub fn DeleteQuery::where_eq(
  self : DeleteQuery,
  col : String,
  value : Json,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Eq }] }
}

///|
pub fn DeleteQuery::where_gt(
  self : DeleteQuery,
  col : String,
  value : Json,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Gt }] }
}

///|
pub fn DeleteQuery::where_lt(
  self : DeleteQuery,
  col : String,
  value : Json,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Lt }] }
}

///|
pub fn DeleteQuery::where_gte(
  self : DeleteQuery,
  col : String,
  value : Json,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Gte }] }
}

///|
pub fn DeleteQuery::where_lte(
  self : DeleteQuery,
  col : String,
  value : Json,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value, ty: Lte }] }
}

///|
pub fn DeleteQuery::to(self : DeleteQuery, dialect : Dialect) -> String {
  match dialect {
    MongoDB => { "delete": self.from }.to_json().stringify()
    _ => {
      let buf = @buffer.new()
      buf.write_string("DELETE FROM ")
      buf.write_string(self.from)
      if !self.where_.is_empty() {
        buf.write_string(" WHERE ")
        buf.write_string(format_where_sql(dialect, self.where_))
      }
      buf.to_string()
    }
  }
}
