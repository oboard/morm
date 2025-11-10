///|
pub(open) trait Entity: ToJson + @json.FromJson {
  table(Self) -> Table
}

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
        Asc(col) => "\{col} ASC"
        Desc(col) => "\{col} DESC"
      })
      .join(", "),
    )
  }
  match dialect {
    Oracle | SqlServer => {
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

///|
// ---- 事务语句（BEGIN/COMMIT/ROLLBACK） ----
pub fn begin_tx(dialect : Dialect) -> String {
  match dialect {
    MySQL => "START TRANSACTION"
    PgSQL => "BEGIN"
    Sqlite3 => "BEGIN"
    SqlServer => "BEGIN TRANSACTION"
    Oracle => "" // Oracle 事务隐式开始：在首个 DML 执行时开始
  }
}

///|
pub fn commit_tx(dialect : Dialect) -> String {
  match dialect {
    _ => "COMMIT"
  }
}

///|
pub fn rollback_tx(dialect : Dialect) -> String {
  match dialect {
    _ => "ROLLBACK"
  }
}

///|
// ---- DDL 类型与列定义映射 ----
fn map_column_type(dialect : Dialect, ct : ColumnType) -> String {
  match ct {
    TinyInt =>
      match dialect {
        PgSQL => "SMALLINT"
        SqlServer => "TINYINT"
        Oracle => "NUMBER(3)"
        _ => "TINYINT"
      }
    SmallInt =>
      match dialect {
        Oracle => "NUMBER(5)"
        PgSQL => "SMALLINT"
        _ => "SMALLINT"
      }
    MediumInt =>
      match dialect {
        MySQL => "MEDIUMINT"
        Oracle => "NUMBER(7)"
        _ => "INT"
      }
    Int =>
      match dialect {
        PgSQL => "INTEGER"
        Oracle => "NUMBER(10)"
        _ => "INT"
      }
    BigInt =>
      match dialect {
        Oracle => "NUMBER(19)"
        _ => "BIGINT"
      }
    Float =>
      match dialect {
        Oracle => "BINARY_FLOAT"
        _ => "FLOAT"
      }
    Double =>
      match dialect {
        PgSQL => "DOUBLE PRECISION"
        Oracle => "BINARY_DOUBLE"
        _ => "DOUBLE"
      }
    Decimal(p, s) =>
      match dialect {
        Oracle => "NUMBER(\{p}, \{s})"
        _ => "DECIMAL(\{p}, \{s})"
      }
    Char(len) => "CHAR(\{len})"
    VarChar(len) =>
      match dialect {
        PgSQL | MySQL | SqlServer => "VARCHAR(\{len})"
        Sqlite3 => "TEXT"
        Oracle => "VARCHAR2(\{len})"
      }
    Text =>
      match dialect {
        Oracle => "CLOB"
        PgSQL => "TEXT"
        SqlServer => "NVARCHAR(MAX)"
        _ => "TEXT"
      }
    MediumText =>
      match dialect {
        MySQL => "MEDIUMTEXT"
        _ => "TEXT"
      }
    LongText =>
      match dialect {
        MySQL => "LONGTEXT"
        Oracle => "CLOB"
        _ => "TEXT"
      }
    Binary(len) =>
      match dialect {
        MySQL => "BINARY(\{len})"
        SqlServer => "BINARY(\{len})"
        Oracle => "RAW(\{len})"
        PgSQL => "BYTEA"
        _ => "BLOB"
      }
    VarBinary(len) =>
      match dialect {
        MySQL => "VARBINARY(\{len})"
        SqlServer => "VARBINARY(\{len})"
        PgSQL => "BYTEA"
        Oracle => "RAW(\{len})"
        _ => "BLOB"
      }
    Blob =>
      match dialect {
        PgSQL => "BYTEA"
        SqlServer => "VARBINARY(MAX)"
        Oracle => "BLOB"
        _ => "BLOB"
      }
    MediumBlob =>
      match dialect {
        MySQL => "MEDIUMBLOB"
        Oracle => "BLOB"
        _ => "BLOB"
      }
    LongBlob =>
      match dialect {
        MySQL => "LONGBLOB"
        Oracle => "BLOB"
        _ => "BLOB"
      }
    Date => "DATE"
    Time =>
      match dialect {
        SqlServer => "TIME"
        Oracle => "DATE"
        _ => "TIME"
      }
    DateTime =>
      match dialect {
        PgSQL => "TIMESTAMP"
        SqlServer => "DATETIME2"
        Oracle => "TIMESTAMP"
        _ => "DATETIME"
      }
    Timestamp =>
      match dialect {
        PgSQL => "TIMESTAMP"
        SqlServer => "DATETIME2"
        Oracle => "TIMESTAMP"
        _ => "TIMESTAMP"
      }
    Year =>
      match dialect {
        MySQL => "YEAR"
        Oracle => "NUMBER(4)"
        _ => "INT"
      }
    Json =>
      match dialect {
        PgSQL => "JSON"
        MySQL => "JSON"
        SqlServer => "NVARCHAR(MAX)"
        Oracle => "CLOB"
        _ => "TEXT"
      }
    JsonB =>
      match dialect {
        PgSQL => "JSONB"
        _ => "JSON"
      }
    Boolean =>
      match dialect {
        PgSQL => "BOOLEAN"
        MySQL => "TINYINT(1)"
        Sqlite3 => "INTEGER"
        SqlServer => "BIT"
        Oracle => "NUMBER(1)"
      }
  }
}

///|
fn format_column_def(dialect : Dialect, col : Column) -> String {
  let ty = map_column_type(dialect, col.column_type)
  let buf = @buffer.new()

  // PostgreSQL 的自增类型用 SERIAL/BIGSERIAL
  let ty_final = if col.auto_increment {
    match dialect {
      PgSQL =>
        match col.column_type {
          BigInt => "BIGSERIAL"
          _ => "SERIAL"
        }
      _ => ty
    }
  } else {
    ty
  }
  buf.write_string(col.name)
  buf.write_string(" ")
  buf.write_string(ty_final)

  // SQL Server/Oracle/SQLite 的自增修饰
  if col.auto_increment {
    match dialect {
      MySQL => buf.write_string(" AUTO_INCREMENT")
      SqlServer => buf.write_string(" IDENTITY(1,1)")
      Oracle => buf.write_string(" GENERATED BY DEFAULT AS IDENTITY")
      Sqlite3 => () // SQLite: 需要 INTEGER PRIMARY KEY AUTOINCREMENT */ }
      _ => ()
    }
  }
  if !col.nullable {
    buf.write_string(" NOT NULL")
  }
  if col.primary_key {
    match dialect {
      Sqlite3 => buf.write_string(" PRIMARY KEY") // SQLite 允许内联主键
      _ => buf.write_string(" PRIMARY KEY")
    }
  }
  if col.unique {
    buf.write_string(" UNIQUE")
  }
  if col.default_value is Some(d) {
    // 保守策略：默认值按原样拼接，避免误加引号破坏表达式
    buf.write_string(" DEFAULT ")
    buf.write_string(d)
  }

  // MySQL 列注释
  if col.comment != "" {
    match dialect {
      MySQL => {
        buf.write_string(" COMMENT ")
        buf.write_string("'\{col.comment}'")
      }
      _ => ()
    }
  }

  // SQLite 的 AUTOINCREMENT 必须与 INTEGER PRIMARY KEY 联用
  if col.auto_increment && dialect == Sqlite3 {
    buf.write_string(" AUTOINCREMENT")
  }
  buf.to_string()
}

///|
// ---- CREATE TABLE 生成 ----
pub fn Table::to_create_sql(self : Table, dialect : Dialect) -> String {
  let buf = @buffer.new()
  buf.write_string("CREATE TABLE ")
  buf.write_string(self.name)
  buf.write_string(" (\n  ")

  // 列定义
  let col_sqls = self.columns.map(c => format_column_def(dialect, c))
  buf.write_string(col_sqls.join(",\n  "))

  // 表级索引/约束
  for idx in self.indexes {
    match idx.index_type {
      Primary => {
        buf.write_string(",\n  PRIMARY KEY (")
        buf.write_string(idx.columns.join(", "))
        buf.write_string(")")
      }
      Unique =>
        match dialect {
          MySQL => {
            buf.write_string(",\n  UNIQUE KEY ")
            buf.write_string(idx.name)
            buf.write_string(" (")
            buf.write_string(idx.columns.join(", "))
            buf.write_string(")")
          }
          _ => {
            buf.write_string(",\n  UNIQUE (")
            buf.write_string(idx.columns.join(", "))
            buf.write_string(")")
          }
        }
      Index | FullText | Spatial => ()
      // 普通索引/全文/空间索引：部分方言不支持在 CREATE TABLE 中声明
      // 这里保守不在表定义中加入，交由后续 ALTER/CREATE INDEX 完成

    }
  }

  // 外键
  for fk in self.foreign_keys {
    buf.write_string(",\n  CONSTRAINT ")
    buf.write_string(fk.name)
    buf.write_string(" FOREIGN KEY (")
    buf.write_string(fk.column)
    buf.write_string(") REFERENCES ")
    buf.write_string(fk.referenced_table)
    buf.write_string(" (")
    buf.write_string(fk.referenced_column)
    buf.write_string(")")
    if fk.on_delete != "" {
      buf.write_string(" ON DELETE ")
      buf.write_string(fk.on_delete)
    }
    if fk.on_update != "" {
      buf.write_string(" ON UPDATE ")
      buf.write_string(fk.on_update)
    }
  }
  buf.write_string("\n)")

  // MySQL 表选项
  match dialect {
    MySQL => {
      buf.write_string(" ENGINE=")
      buf.write_string(self.engine)
      buf.write_string(" DEFAULT CHARSET=")
      buf.write_string(self.charset)
      buf.write_string(" COLLATE=")
      buf.write_string(self.collation)
      if self.comment != "" {
        buf.write_string(" COMMENT=")
        buf.write_string(["'", self.comment, "'"].join(""))
      }
      if self.auto_increment > 1 {
        buf.write_string(" AUTO_INCREMENT=")
        buf.write_string(self.auto_increment.to_string())
      }
    }
    _ => ()
  }
  buf.to_string()
}

///|
// ---- ALTER TABLE 构建器 ----
pub enum AlterOp {
  AddColumn(Column)
  DropColumn(String)
  ModifyColumn(Column)
  AddIndex(Index)
  DropIndex(String)
  AddForeignKey(ForeignKey)
  DropForeignKey(String)
  RenameTable(String)
  TableComment(String)
} derive(Show, ToJson, FromJson)

///|
pub struct AlterTable {
  table : String
  ops : FixedArray[AlterOp]
} derive(Show, ToJson, FromJson)

///|
pub fn alter_table(name : String) -> AlterTable {
  { table: name, ops: [] }
}

///|
pub fn AlterTable::add_column(self : AlterTable, col : Column) -> AlterTable {
  { ..self, ops: self.ops + [AddColumn(col)] }
}

///|
pub fn AlterTable::drop_column(self : AlterTable, name : String) -> AlterTable {
  { ..self, ops: self.ops + [DropColumn(name)] }
}

///|
pub fn AlterTable::modify_column(self : AlterTable, col : Column) -> AlterTable {
  { ..self, ops: self.ops + [ModifyColumn(col)] }
}

///|
pub fn AlterTable::add_index(self : AlterTable, idx : Index) -> AlterTable {
  { ..self, ops: self.ops + [AddIndex(idx)] }
}

///|
pub fn AlterTable::drop_index(self : AlterTable, name : String) -> AlterTable {
  { ..self, ops: self.ops + [DropIndex(name)] }
}

///|
pub fn AlterTable::add_foreign_key(
  self : AlterTable,
  fk : ForeignKey,
) -> AlterTable {
  { ..self, ops: self.ops + [AddForeignKey(fk)] }
}

///|
pub fn AlterTable::drop_foreign_key(
  self : AlterTable,
  name : String,
) -> AlterTable {
  { ..self, ops: self.ops + [DropForeignKey(name)] }
}

///|
pub fn AlterTable::rename(self : AlterTable, new_name : String) -> AlterTable {
  { ..self, ops: self.ops + [RenameTable(new_name)] }
}

///|
pub fn AlterTable::comment(self : AlterTable, text : String) -> AlterTable {
  { ..self, ops: self.ops + [TableComment(text)] }
}

///|
pub fn AlterTable::to(self : AlterTable, dialect : Dialect) -> String {
  let stmts = Array::new()
  for op in self.ops {
    match op {
      AddColumn(col) =>
        stmts.push(
          "ALTER TABLE \{self.table} ADD COLUMN \{format_column_def(dialect, col)}",
        )
      DropColumn(name) => {
        let s = match dialect {
          SqlServer => "ALTER TABLE \{self.table} DROP COLUMN \{name}"
          _ => "ALTER TABLE \{self.table} DROP COLUMN \{name}"
        }
        stmts.push(s)
      }
      ModifyColumn(col) => {
        let s = match dialect {
          MySQL =>
            [
              "ALTER TABLE ",
              self.table,
              " MODIFY COLUMN ",
              format_column_def(dialect, col),
            ].join("")
          PgSQL =>
            [
              "ALTER TABLE ",
              self.table,
              " ALTER COLUMN ",
              col.name,
              " TYPE ",
              map_column_type(dialect, col.column_type),
            ].join("")
          SqlServer =>
            [
              "ALTER TABLE ",
              self.table,
              " ALTER COLUMN ",
              format_column_def(dialect, col),
            ].join("")
          Oracle =>
            [
              "ALTER TABLE ",
              self.table,
              " MODIFY (",
              format_column_def(dialect, col),
              ")",
            ].join("")
          Sqlite3 =>
            [
              "ALTER TABLE ",
              self.table,
              " RENAME COLUMN ",
              col.name,
              " TO ",
              col.name,
            ].join("") // SQLite 对修改列类型支持有限
        }
        stmts.push(s)
      }
      AddIndex(idx) => {
        let cols = ["(", idx.columns.join(", "), ")"].join("")
        let s = match dialect {
          MySQL =>
            match idx.index_type {
              Unique =>
                "ALTER TABLE \{self.table} ADD UNIQUE INDEX \{idx.name} \{cols}"
              _ => "ALTER TABLE \{self.table} ADD INDEX \{idx.name} \{cols}"
            }
          PgSQL =>
            match idx.index_type {
              Unique =>
                "CREATE UNIQUE INDEX \{idx.name} ON \{self.table} \{cols}"
              _ => "CREATE INDEX \{idx.name} ON \{self.table} \{cols}"
            }
          Sqlite3 =>
            match idx.index_type {
              Primary | Index | FullText | Spatial =>
                abort(
                  "Sqlite3 does not support primary, index, fulltext, or spatial indexes",
                )
              Unique =>
                if idx.index_type == Unique {
                  "CREATE UNIQUE INDEX \{idx.name} ON \{self.table} \{cols}"
                } else {
                  "CREATE INDEX \{idx.name} ON \{self.table} \{cols}"
                }
            }
          SqlServer =>
            match idx.index_type {
              Unique =>
                "CREATE UNIQUE INDEX \{idx.name} ON \{self.table} \{cols}"
              _ => "CREATE INDEX \{idx.name} ON \{self.table} \{cols}"
            }
          Oracle =>
            match idx.index_type {
              Unique =>
                "CREATE UNIQUE INDEX \{idx.name} ON \{self.table} \{cols}"
              _ => "CREATE INDEX \{idx.name} ON \{self.table} \{cols}"
            }
        }
        stmts.push(s)
      }
      DropIndex(name) => {
        let s = match dialect {
          MySQL => "ALTER TABLE \{self.table} DROP INDEX \{name}"
          SqlServer => "DROP INDEX \{name} ON \{self.table}"
          Oracle | Sqlite3 | PgSQL => "DROP INDEX \{name}"
        }
        stmts.push(s)
      }
      AddForeignKey(fk) => {
        let s = @buffer.new()
        s.write_string("ALTER TABLE ")
        s.write_string(self.table)
        s.write_string(" ADD CONSTRAINT ")
        s.write_string(fk.name)
        s.write_string(" FOREIGN KEY (")
        s.write_string(fk.column)
        s.write_string(") REFERENCES ")
        s.write_string(fk.referenced_table)
        s.write_string(" (")
        s.write_string(fk.referenced_column)
        s.write_string(")")
        if fk.on_delete != "" {
          s.write_string([" ON DELETE ", fk.on_delete].join(""))
        }
        if fk.on_update != "" {
          s.write_string([" ON UPDATE ", fk.on_update].join(""))
        }
        stmts.push(s.to_string())
      }
      DropForeignKey(name) => {
        let s = match dialect {
          MySQL => "ALTER TABLE \{self.table} DROP FOREIGN KEY \{name}"
          PgSQL => "ALTER TABLE \{self.table} DROP CONSTRAINT \{name}"
          _ => "ALTER TABLE \{self.table} DROP CONSTRAINT \{name}"
        }
        stmts.push(s)
      }
      RenameTable(new_name) => {
        let s = match dialect {
          MySQL => "RENAME TABLE \{self.table} TO \{new_name}"
          PgSQL => "ALTER TABLE \{self.table} RENAME TO \{new_name}"
          _ => "ALTER TABLE \{self.table} RENAME TO \{new_name}"
        }
        stmts.push(s)
      }
      TableComment(text) => {
        let s = match dialect {
          MySQL => "ALTER TABLE \{self.table} COMMENT = '\{text}'"
          PgSQL => "COMMENT ON TABLE \{self.table} IS '\{text}'"
          Oracle => "COMMENT ON TABLE \{self.table} IS '\{text}'"
          _ => ""
        }
        if !s.is_empty() {
          stmts.push(s)
        }
      }
    }
  }
  stmts.join("; ")
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
pub fn[E : Entity] InsertQuery::from(
  self : InsertQuery,
  entity : E,
) -> InsertQuery {
  let json = entity.to_json()
  let columns = entity.table().columns.map(c => c.name)
  let values = FixedArray::from_iter(json.as_object().unwrap().values())
  { ..self, columns, values }
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
  let buf = @buffer.new()
  buf.write_string("DELETE FROM ")
  buf.write_string(self.from)
  if !self.where_.is_empty() {
    buf.write_string(" WHERE ")
    buf.write_string(format_where_sql(dialect, self.where_))
  }
  buf.to_string()
}

// ///|
// pub fn[E : Entity] from_result(
//   entity : E,
//   result : @engine.QueryResult,
// ) -> Array[E] {
//   let res = FixedArray::make(result.rows.length(), entity)
//   result.rows.each(row => res.append(entity.from_json(row)) catch { _ => () })
//   res
// }
