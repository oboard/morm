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
  exec(Self, sql : String, args : FixedArray[@engine.Param]) -> DbResult[Unit]
  query(Self, sql : String, args : FixedArray[@engine.Param]) -> DbResult[
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
  value : @engine.Param
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
fn json_to_param(value : Json) -> @engine.Param {
  match value {
    Null => @engine.Null
    True => @engine.Bool(true)
    False => @engine.Bool(false)
    Number(n, ..) => @engine.Double(n)
    String(s) => @engine.String(s)
    _ => @engine.String(value.stringify())
  }
}

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
pub fn[V : @engine.ToParam] Query::where_eq(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Eq }]
  { ..self, where_, }
}

///|
pub fn[V : @engine.ToParam] Query::where_gt(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Gt }]
  { ..self, where_, }
}

///|
pub fn[V : @engine.ToParam] Query::where_lt(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Lt }]
  { ..self, where_, }
}

///|
pub fn[V : @engine.ToParam] Query::where_gte(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Gte }]
  { ..self, where_, }
}

///|
pub fn[V : @engine.ToParam] Query::where_lte(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Lte }]
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
pub impl @engine.QueryBuilder for Query with to_statement(self) -> @engine.Statement {
  let where_ = self.where_.map(w => {
    let ty = match w.ty {
      Eq => @engine.Eq
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
    }
    @engine.Where::{ col: w.col, value: w.value, ty }
  })
  let order_by = self.order_by.map(ob => {
    match ob {
      Asc(col) => @engine.Asc(col)
      Desc(col) => @engine.Desc(col)
    }
  })
  @engine.Select({
    select: self.select,
    from: self.from,
    where_,
    order_by,
    limit: self.limit,
    offset: self.offset,
  })
}

///|
// ---- INSERT 构建器 ----
pub struct InsertQuery {
  into : String
  columns : FixedArray[String]
  values : FixedArray[@engine.Param]
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
  let values = if json is Object(obj) {
    FixedArray::from_iter(obj.values().map(v => json_to_param(v)))
  } else {
    []
  }
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
  values : FixedArray[@engine.Param],
) -> InsertQuery {
  { ..self, values, }
}

///|
pub impl @engine.QueryBuilder for InsertQuery with to_statement(self) -> @engine.Statement {
  @engine.Insert({ into: self.into, columns: self.columns, values: self.values })
}

///|
// ---- UPSERT 构建器 ----
pub struct UpsertQuery {
  table : String
  sets : FixedArray[Set]
  conflict_target : FixedArray[String] // 冲突检测列（主键或唯一索引列）
  update_sets : FixedArray[Set] // 冲突时更新的列
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn upsert_into(table : String) -> UpsertQuery {
  { table, sets: [], conflict_target: [], update_sets: [] }
}

///|
pub fn[E : Entity] UpsertQuery::from(
  self : UpsertQuery,
  entity : E,
) -> UpsertQuery {
  let json = entity.to_json()
  let sets = if json is Object(obj) {
    obj.map((col, value) => { col, value: json_to_param(value) })
  } else {
    {}
  }
  let table = entity.table()
  let mut conflict_cols : FixedArray[String] = []
  match table.primary_key() {
    Some(pk) => conflict_cols = [pk]
    None =>
      for idx in table.indexes {
        match idx.index_type {
          Unique => {
            conflict_cols = idx.columns
            break
          }
          _ => ()
        }
      }
  }
  {
    ..self,
    sets: FixedArray::from_iter(sets.values()),
    conflict_target: conflict_cols,
  }
}

///|
pub fn UpsertQuery::set(
  self : UpsertQuery,
  col : String,
  value : @engine.Param,
) -> UpsertQuery {
  { ..self, sets: self.sets + [{ col, value }] }
}

///|
pub fn UpsertQuery::on_conflict(
  self : UpsertQuery,
  columns : FixedArray[String],
) -> UpsertQuery {
  { ..self, conflict_target: columns }
}

///|
pub fn UpsertQuery::do_update_set(
  self : UpsertQuery,
  col : String,
  value : @engine.Param,
) -> UpsertQuery {
  { ..self, update_sets: self.update_sets + [{ col, value }] }
}

///|
pub impl @engine.QueryBuilder for UpsertQuery with to_statement(self) -> @engine.Statement {
  let sets = self.sets.map(s => @engine.Set::{ col: s.col, value: s.value })
  let update_sets = self.update_sets.map(s => @engine.Set::{
    col: s.col,
    value: s.value,
  })
  @engine.Upsert({
    table: self.table,
    sets,
    conflict_target: self.conflict_target,
    update_sets,
  })
}

///|
// ---- UPDATE 构建器 ----
pub struct Set {
  col : String
  value : @engine.Param
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
pub fn[E : Entity] UpdateQuery::from(
  self : UpdateQuery,
  entity : E,
) -> UpdateQuery {
  let json = entity.to_json()
  let values = FixedArray::from_iter(
    if json is Object(obj) {
      obj.map((k, v) => Set::{ col: k, value: json_to_param(v) }).values()
    } else {
      [].iter()
    },
  )
  { ..self, sets: values }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::set(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, sets: self.sets + [{ col, value: value.to_param() }] }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::where_eq(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Eq }] }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::where_gt(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Gt }] }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::where_lt(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Lt }] }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::where_gte(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Gte }] }
}

///|
pub fn[V : @engine.ToParam] UpdateQuery::where_lte(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Lte }] }
}

///|
pub impl @engine.QueryBuilder for UpdateQuery with to_statement(self) -> @engine.Statement {
  let sets = self.sets.map(s => @engine.Set::{ col: s.col, value: s.value })
  let where_ = self.where_.map(w => {
    let ty = match w.ty {
      Eq => @engine.Eq
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
    }
    @engine.Where::{ col: w.col, value: w.value, ty }
  })
  @engine.Update({ table: self.table, sets, where_ })
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
pub fn[V : @engine.ToParam] DeleteQuery::where_eq(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Eq }] }
}

///|
pub fn[V : @engine.ToParam] DeleteQuery::where_gt(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Gt }] }
}

///|
pub fn[V : @engine.ToParam] DeleteQuery::where_lt(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Lt }] }
}

///|
pub fn[V : @engine.ToParam] DeleteQuery::where_gte(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Gte }] }
}

///|
pub fn[V : @engine.ToParam] DeleteQuery::where_lte(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Lte }] }
}

///|
pub impl @engine.QueryBuilder for DeleteQuery with to_statement(self) -> @engine.Statement {
  let where_ = self.where_.map(w => {
    let ty = match w.ty {
      Eq => @engine.Eq
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
    }
    @engine.Where::{ col: w.col, value: w.value, ty }
  })
  @engine.Delete({ from: self.from, where_ })
}

///|
pub fn[E : Entity] DeleteQuery::from(
  self : DeleteQuery,
  entity : E,
) -> DeleteQuery {
  let table = entity.table()
  let pk_opt = table.primary_key()
  match pk_opt {
    Some(pk) => {
      let obj = if entity.to_json() is Object(obj) { obj } else { {} }
      match obj.get(pk) {
        Some(v) => {
          let pv = json_to_param(v)
          { ..self, where_: self.where_ + [{ col: pk, value: pv, ty: Eq }] }
        }
        None => self
      }
    }
    None => self
  }
}
