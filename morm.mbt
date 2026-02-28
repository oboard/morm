///|
pub(open) trait Entity: ToJson + @json.FromJson {
  table(Self) -> Table
}

///|
pub fn current_timestamp_utc() -> @time.ZonedDateTime {
  let ms = @env.now()
  let seconds = (ms / 1000UL).reinterpret_as_int64()
  let nanosecond = (ms % 1000UL).to_int() * 1_000_000
  @time.unix(seconds, nanosecond~) catch {
    _ => panic()
  }
}

///|
pub fn current_plain_date_time_utc() -> @time.PlainDateTime {
  current_timestamp_utc().to_plain_date_time()
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
  joins : FixedArray[String]
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
  Ne
  Gt
  Lt
  Gte
  Lte
  Like
} derive(Eq, Show, ToJson, FromJson)

///|
fn json_to_param(value : Json) -> @engine.Param {
  match value {
    Null => @engine.Null
    True => @engine.Bool(true)
    False => @engine.Bool(false)
    Number(n, ..) => @engine.Double(n)
    String(s) => @engine.String(s)
    _ => @engine.Json(value)
  }
}

///|
fn[O : ToJson] collect_owner_key_params(
  owners : FixedArray[O],
  owner_key : String,
) -> FixedArray[@engine.Param] {
  let seen : Map[String, Bool] = Map::new()
  let params : Array[@engine.Param] = []
  for owner in owners {
    if owner.to_json() is Object(obj) {
      if obj.get(owner_key) is Some(v) {
        if v is Null {
          continue
        }
        let key = v.stringify()
        if seen.get(key) is None {
          seen.set(key, true)
          params.push(json_to_param(v))
        }
      }
    }
  }
  FixedArray::from_array(params)
}

///|
pub(all) enum AssociationKind {
  BelongsTo
  HasOne
  HasMany
  ManyToMany
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Association {
  name : String
  kind : AssociationKind
  owner_key : String
  target_table : String
  target_key : String
  join_table : String?
  join_owner_key : String?
  join_target_key : String?
} derive(Eq, Show, ToJson, FromJson)

///|
pub fn belongs_to(
  name : String,
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Association {
  {
    name,
    kind: BelongsTo,
    owner_key,
    target_table,
    target_key,
    join_table: None,
    join_owner_key: None,
    join_target_key: None,
  }
}

///|
pub fn has_one(
  name : String,
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Association {
  {
    name,
    kind: HasOne,
    owner_key,
    target_table,
    target_key,
    join_table: None,
    join_owner_key: None,
    join_target_key: None,
  }
}

///|
pub fn has_many(
  name : String,
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Association {
  {
    name,
    kind: HasMany,
    owner_key,
    target_table,
    target_key,
    join_table: None,
    join_owner_key: None,
    join_target_key: None,
  }
}

///|
pub fn many_to_many(
  name : String,
  owner_key : String,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
) -> Association {
  {
    name,
    kind: ManyToMany,
    owner_key,
    target_table,
    target_key,
    join_table: Some(join_table),
    join_owner_key: Some(join_owner_key),
    join_target_key: Some(join_target_key),
  }
}

///|
pub async fn[E : @engine.Engine, O : ToJson, T : @json.FromJson] preload_belongs_to(
  engine : E,
  owners : FixedArray[O],
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Map[String, T] {
  let key_params = collect_owner_key_params(owners, owner_key)
  let out : Map[String, T] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let sql = engine.preload_in_sql(target_table, target_key, key_params.length())
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get(target_key) is Some(v) {
        let key = v.stringify()
        let entity : T = @json.from_json(row) catch { _ => continue }
        out.set(key, entity)
      }
    }
  }
  out
}

///|
pub async fn[E : @engine.Engine, O : ToJson, T : @json.FromJson] preload_has_one(
  engine : E,
  owners : FixedArray[O],
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Map[String, T] {
  preload_belongs_to(engine, owners, owner_key, target_table, target_key)
}

///|
pub async fn[E : @engine.Engine, O : ToJson, T : @json.FromJson] preload_has_many(
  engine : E,
  owners : FixedArray[O],
  owner_key : String,
  target_table : String,
  target_key : String,
) -> Map[String, Array[T]] {
  let key_params = collect_owner_key_params(owners, owner_key)
  let out : Map[String, Array[T]] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let sql = engine.preload_in_sql(target_table, target_key, key_params.length())
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get(target_key) is Some(v) {
        let key = v.stringify()
        let entity : T = @json.from_json(row) catch { _ => continue }
        if out.get(key) is Some(items) {
          items.push(entity)
          out.set(key, items)
        } else {
          out.set(key, [entity])
        }
      }
    }
  }
  out
}

///|
pub async fn[E : @engine.Engine, O : ToJson, T : @json.FromJson] preload_many_to_many(
  engine : E,
  owners : FixedArray[O],
  owner_key : String,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
) -> Map[String, Array[T]] {
  let key_params = collect_owner_key_params(owners, owner_key)
  let out : Map[String, Array[T]] = Map::new()
  if key_params.is_empty() {
    return out
  }
  let sql = engine.preload_many_to_many_sql(
    target_table,
    target_key,
    join_table,
    join_owner_key,
    join_target_key,
    key_params.length(),
  )
  let res = engine.exec_raw(sql, key_params)
  if !res.ok {
    return out
  }
  for row in res.rows {
    if row is Object(obj) {
      if obj.get("__morm_owner_key") is Some(owner_key_value) {
        let owner_key = owner_key_value.stringify()
        let entity : T = @json.from_json(row) catch { _ => continue }
        if out.get(owner_key) is Some(items) {
          items.push(entity)
          out.set(owner_key, items)
        } else {
          out.set(owner_key, [entity])
        }
      }
    }
  }
  out
}

///|
pub(all) enum PreloadResult[T] {
  One(Map[String, T])
  Many(Map[String, Array[T]])
}

///|
pub async fn[E : @engine.Engine, O : ToJson, T : @json.FromJson] preload(
  engine : E,
  owners : FixedArray[O],
  association : Association,
) -> PreloadResult[T] {
  match association.kind {
    BelongsTo =>
      One(
        preload_belongs_to(
          engine,
          owners,
          association.owner_key,
          association.target_table,
          association.target_key,
        ),
      )
    HasOne =>
      One(
        preload_has_one(
          engine,
          owners,
          association.owner_key,
          association.target_table,
          association.target_key,
        ),
      )
    HasMany =>
      Many(
        preload_has_many(
          engine,
          owners,
          association.owner_key,
          association.target_table,
          association.target_key,
        ),
      )
    ManyToMany =>
      Many(
        preload_many_to_many(
          engine,
          owners,
          association.owner_key,
          association.target_table,
          association.target_key,
          association.join_table.unwrap_or(""),
          association.join_owner_key.unwrap_or(""),
          association.join_target_key.unwrap_or(""),
        ),
      )
  }
}

///|
pub fn select_from(table : String) -> Query {
  {
    select: "*",
    from: table,
    joins: [],
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
    joins: [],
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
pub fn[V : @engine.ToParam] Query::where_ne(
  self : Query,
  col : String,
  value : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: value.to_param(), ty: Ne }]
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
pub fn[V : @engine.ToParam] Query::where_like(
  self : Query,
  col : String,
  pattern : V,
) -> Query {
  let where_ = self.where_ + [{ col, value: pattern.to_param(), ty: Like }]
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
pub fn Query::join(self : Query, join_sql : String) -> Query {
  { ..self, joins: self.joins + [join_sql] }
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
      Ne => @engine.Ne
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
      Like => @engine.Like
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
    joins: self.joins,
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
  let table = entity.table()
  let sets = if json is Object(obj) {
    obj.map((col, value) => { col, value: json_to_param(value) })
  } else {
    {}
  }
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
pub fn[V : @engine.ToParam] UpdateQuery::where_ne(
  self : UpdateQuery,
  col : String,
  value : V,
) -> UpdateQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Ne }] }
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
pub fn[V : @engine.ToParam] UpdateQuery::where_like(
  self : UpdateQuery,
  col : String,
  pattern : V,
) -> UpdateQuery {
  {
    ..self,
    where_: self.where_ + [{ col, value: pattern.to_param(), ty: Like }],
  }
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
      Ne => @engine.Ne
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
      Like => @engine.Like
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
pub fn[V : @engine.ToParam] DeleteQuery::where_ne(
  self : DeleteQuery,
  col : String,
  value : V,
) -> DeleteQuery {
  { ..self, where_: self.where_ + [{ col, value: value.to_param(), ty: Ne }] }
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
pub fn[V : @engine.ToParam] DeleteQuery::where_like(
  self : DeleteQuery,
  col : String,
  pattern : V,
) -> DeleteQuery {
  {
    ..self,
    where_: self.where_ + [{ col, value: pattern.to_param(), ty: Like }],
  }
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
      Ne => @engine.Ne
      Gt => @engine.Gt
      Lt => @engine.Lt
      Gte => @engine.Gte
      Lte => @engine.Lte
      Like => @engine.Like
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

///|
/// Soft delete default scope (boolean convention): deleted = false
pub fn select_from_scoped(table : String, deleted_col? : String) -> Query {
  let col = deleted_col.unwrap_or("deleted")
  select_from(table).where_eq(col, false)
}

///|
pub fn[V : @engine.ToParam] soft_delete_by_id(
  table : String,
  id_col : String,
  id : V,
  deleted_col? : String,
) -> UpdateQuery {
  let col = deleted_col.unwrap_or("deleted")
  update(table).set(col, true).where_eq(id_col, id)
}

///|
pub fn[V : @engine.ToParam] restore_by_id(
  table : String,
  id_col : String,
  id : V,
  deleted_col? : String,
) -> UpdateQuery {
  let col = deleted_col.unwrap_or("deleted")
  update(table).set(col, false).where_eq(id_col, id)
}

///|
/// Hook callbacks helpers.
pub fn[T] before_create(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] after_create(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] before_update(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] after_update(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] before_delete(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] after_delete(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub fn[T] after_find(entity : T, callback : (T) -> T) -> T {
  callback(entity)
}

///|
pub(all) struct ColumnDiff {
  added : FixedArray[Column]
  removed : FixedArray[Column]
  changed : FixedArray[(String, Column, Column)]
} derive(Show, ToJson, FromJson, Eq)

///|
pub(all) struct IndexDiff {
  added : FixedArray[Index]
  removed : FixedArray[Index]
  changed : FixedArray[(String, Index, Index)]
} derive(Show, ToJson, FromJson, Eq)

///|
pub(all) struct ForeignKeyDiff {
  added : FixedArray[ForeignKey]
  removed : FixedArray[ForeignKey]
  changed : FixedArray[(String, ForeignKey, ForeignKey)]
} derive(Show, ToJson, FromJson, Eq)

///|
pub(all) struct TableDiff {
  columns : ColumnDiff
  indexes : IndexDiff
  foreign_keys : ForeignKeyDiff
} derive(Show, ToJson, FromJson, Eq)

///|
fn diff_columns(old_table : Table, new_table : Table) -> ColumnDiff {
  let old_map : Map[String, Column] = Map::new()
  let new_map : Map[String, Column] = Map::new()
  for c in old_table.columns {
    old_map.set(c.name, c)
  }
  for c in new_table.columns {
    new_map.set(c.name, c)
  }
  let added : Array[Column] = []
  let removed : Array[Column] = []
  let changed : Array[(String, Column, Column)] = []
  for c in new_table.columns {
    if old_map.get(c.name) is Some(old_col) {
      if old_col != c {
        changed.push((c.name, old_col, c))
      }
    } else {
      added.push(c)
    }
  }
  for c in old_table.columns {
    if new_map.get(c.name) is None {
      removed.push(c)
    }
  }
  {
    added: FixedArray::from_array(added),
    removed: FixedArray::from_array(removed),
    changed: FixedArray::from_array(changed),
  }
}

///|
fn diff_indexes(old_table : Table, new_table : Table) -> IndexDiff {
  let old_map : Map[String, Index] = Map::new()
  let new_map : Map[String, Index] = Map::new()
  for i in old_table.indexes {
    old_map.set(i.name, i)
  }
  for i in new_table.indexes {
    new_map.set(i.name, i)
  }
  let added : Array[Index] = []
  let removed : Array[Index] = []
  let changed : Array[(String, Index, Index)] = []
  for i in new_table.indexes {
    if old_map.get(i.name) is Some(old_idx) {
      if old_idx != i {
        changed.push((i.name, old_idx, i))
      }
    } else {
      added.push(i)
    }
  }
  for i in old_table.indexes {
    if new_map.get(i.name) is None {
      removed.push(i)
    }
  }
  {
    added: FixedArray::from_array(added),
    removed: FixedArray::from_array(removed),
    changed: FixedArray::from_array(changed),
  }
}

///|
fn diff_foreign_keys(old_table : Table, new_table : Table) -> ForeignKeyDiff {
  let old_map : Map[String, ForeignKey] = Map::new()
  let new_map : Map[String, ForeignKey] = Map::new()
  for fk in old_table.foreign_keys {
    old_map.set(fk.name, fk)
  }
  for fk in new_table.foreign_keys {
    new_map.set(fk.name, fk)
  }
  let added : Array[ForeignKey] = []
  let removed : Array[ForeignKey] = []
  let changed : Array[(String, ForeignKey, ForeignKey)] = []
  for fk in new_table.foreign_keys {
    if old_map.get(fk.name) is Some(old_fk) {
      if old_fk != fk {
        changed.push((fk.name, old_fk, fk))
      }
    } else {
      added.push(fk)
    }
  }
  for fk in old_table.foreign_keys {
    if new_map.get(fk.name) is None {
      removed.push(fk)
    }
  }
  {
    added: FixedArray::from_array(added),
    removed: FixedArray::from_array(removed),
    changed: FixedArray::from_array(changed),
  }
}

///|
pub fn diff_table(old_table : Table, new_table : Table) -> TableDiff {
  {
    columns: diff_columns(old_table, new_table),
    indexes: diff_indexes(old_table, new_table),
    foreign_keys: diff_foreign_keys(old_table, new_table),
  }
}

///|
fn default_driver_registry() -> Map[String, String] {
  let m : Map[String, String] = Map::new()
  m.set("mysql", "mysql")
  m.set("mariadb", "mysql")
  m.set("tidb", "mysql")
  m.set("postgres", "pgsql")
  m.set("postgresql", "pgsql")
  m.set("cockroachdb", "pgsql")
  m.set("gaussdb", "pgsql")
  m.set("sqlserver", "sqlserver")
  m.set("mssql", "sqlserver")
  m.set("oracle", "oracle")
  m.set("sqlite", "sqlite3")
  m
}

///|
let driver_registry : Map[String, String] = default_driver_registry()

///|
fn dsn_scheme(dsn : String) -> String? {
  let core = if dsn.strip_prefix("jdbc:") is Some(rest) {
    rest.to_string()
  } else {
    dsn
  }
  if core.find("://") is Some(i) {
    let scheme = core[:i].to_string() catch { _ => "" }
    Some(scheme.to_lower())
  } else {
    None
  }
}

///|
pub fn register_driver_scheme(scheme : String, driver_name : String) -> Unit {
  driver_registry.set(scheme.to_lower(), driver_name)
}

///|
pub fn unregister_driver_scheme(scheme : String) -> Unit {
  ignore(driver_registry.remove(scheme.to_lower()))
}

///|
pub fn resolve_driver_name(dsn : String) -> String? {
  if dsn_scheme(dsn) is Some(scheme) {
    driver_registry.get(scheme)
  } else {
    None
  }
}
