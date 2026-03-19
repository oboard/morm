///|
struct MockEngine {
  teachers : FixedArray[Json]
  students : FixedArray[Json]
  teacher_students : FixedArray[Json]
}

///|
fn json_matches_param(v : Json, p : @engine.Param) -> Bool {
  v.stringify() == p.to_json().stringify()
}

///|
fn filter_rows(
  rows : FixedArray[Json],
  key : String,
  param : @engine.Param,
) -> FixedArray[Json] {
  let out : Array[Json] = []
  for row in rows {
    if row is Object(obj) {
      if obj.get(key) is Some(value) && json_matches_param(value, param) {
        out.push(row)
      }
    }
  }
  FixedArray::from_array(out)
}

///|
impl @engine.Engine for MockEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  if sql == "SELECT * FROM teachers WHERE id = ?" && params is [id] {
    let rows = filter_rows(self.teachers, "id", id)
    return { ok: true, rows_affected: rows.length(), rows, error: None }
  }
  if sql == "SELECT * FROM students WHERE teacher_id = ?" &&
    params is [teacher_id] {
    let rows = filter_rows(self.students, "teacher_id", teacher_id)
    return { ok: true, rows_affected: rows.length(), rows, error: None }
  }
  if sql == "SELECT * FROM students WHERE id = ?" && params is [id] {
    let rows = filter_rows(self.students, "id", id)
    return { ok: true, rows_affected: rows.length(), rows, error: None }
  }
  if sql == "SELECT * FROM teacher_students WHERE teacher_id = ?" &&
    params is [teacher_id] {
    let rows = filter_rows(self.teacher_students, "teacher_id", teacher_id)
    return { ok: true, rows_affected: rows.length(), rows, error: None }
  }
  {
    ok: false,
    rows_affected: 0,
    rows: [],
    error: Some("unexpected sql/params"),
  }
}

///|
impl @engine.Engine for MockEngine with exec(
  self,
  query : &@engine.QueryBuilder,
) -> @engine.QueryResult {
  match query.to_query() {
    @engine.Statement(stmt) => {
      let (sql, params) = @engine.render_default_sql(stmt)
      self.exec_raw(sql, params)
    }
    @engine.Raw(sql, params) => self.exec_raw(sql, params)
    @engine.Tx(_) => { ok: true, rows_affected: 0, rows: [], error: None }
  }
}

///|
impl @engine.Engine for MockEngine with migrate_table(
  _self,
  _table_schema : @table.Table,
) -> @engine.QueryResult {
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
impl @engine.Engine for MockEngine with close(_self) -> Unit {
  ()
}

///|
struct OwnerBelongsTo {
  id : Int
  teacher_id : Int
} derive(ToJson, FromJson)

///|
struct Teacher {
  id : Int
  name : String
} derive(ToJson, FromJson)

///|
struct OwnerHasMany {
  id : Int
} derive(ToJson, FromJson)

///|
struct Student {
  id : Int
  teacher_id : Int
  name : String
} derive(ToJson, FromJson)

///|
async test "preload belongs_to map" {
  let owners : FixedArray[OwnerBelongsTo] = [
    OwnerBelongsTo::{ id: 1, teacher_id: 10 },
    OwnerBelongsTo::{ id: 2, teacher_id: 11 },
  ]
  let engine = MockEngine::{
    teachers: [{ "id": 10, "name": "Alice" }, { "id": 11, "name": "Bob" }],
    students: [],
    teacher_students: [],
  }
  let by_key : Map[String, Teacher] = @morm.preload_belongs_to(
    engine, owners, "teacher_id", "teachers", "id",
  )
  inspect(by_key.get("10") is Some(_), content="true")
  inspect(by_key.get("11") is Some(_), content="true")
  if by_key.get("10") is Some(t) {
    inspect(t.name, content="Alice")
  } else {
    fail("missing teacher 10")
  }
}

///|
async test "preload has_many map" {
  let owners : FixedArray[OwnerHasMany] = [
    OwnerHasMany::{ id: 1 },
    OwnerHasMany::{ id: 2 },
  ]
  let engine = MockEngine::{
    teachers: [],
    students: [
      { "id": 100, "teacher_id": 1, "name": "S1" },
      { "id": 101, "teacher_id": 1, "name": "S2" },
      { "id": 102, "teacher_id": 2, "name": "S3" },
    ],
    teacher_students: [],
  }
  let by_key : Map[String, Array[Student]] = @morm.preload_has_many(
    engine, owners, "id", "students", "teacher_id",
  )
  inspect(by_key.get("1") is Some(_), content="true")
  inspect(by_key.get("2") is Some(_), content="true")
  if by_key.get("1") is Some(students) {
    inspect(students.length(), content="2")
  } else {
    fail("missing key 1")
  }
}

///|
async test "preload has_one map" {
  let owners : FixedArray[OwnerBelongsTo] = [
    OwnerBelongsTo::{ id: 1, teacher_id: 10 },
    OwnerBelongsTo::{ id: 2, teacher_id: 11 },
  ]
  let engine = MockEngine::{
    teachers: [{ "id": 10, "name": "Alice" }, { "id": 11, "name": "Bob" }],
    students: [],
    teacher_students: [],
  }
  let by_key : Map[String, Teacher] = @morm.preload_has_one(
    engine, owners, "teacher_id", "teachers", "id",
  )
  inspect(by_key.get("10") is Some(_), content="true")
  inspect(by_key.get("11") is Some(_), content="true")
}

///|
async test "preload many_to_many map" {
  let owners : FixedArray[OwnerHasMany] = [
    OwnerHasMany::{ id: 1 },
    OwnerHasMany::{ id: 2 },
  ]
  let engine = MockEngine::{
    teachers: [],
    students: [
      { "id": 100, "teacher_id": 1, "name": "S1" },
      { "id": 101, "teacher_id": 1, "name": "S2" },
      { "id": 102, "teacher_id": 2, "name": "S3" },
    ],
    teacher_students: [
      { "teacher_id": 1, "student_id": 100 },
      { "teacher_id": 1, "student_id": 101 },
      { "teacher_id": 2, "student_id": 102 },
    ],
  }
  let by_key : Map[String, Array[Student]] = @morm.preload_many_to_many(
    engine, owners, "id", "students", "id", "teacher_students", "teacher_id", "student_id",
  )
  inspect(by_key.get("1") is Some(_), content="true")
  inspect(by_key.get("2") is Some(_), content="true")
  if by_key.get("1") is Some(students) {
    inspect(students.length(), content="2")
  } else {
    fail("missing key 1")
  }
}
