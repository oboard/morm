///|
struct MockEngine {
  expected_sql : String
  expected_params : FixedArray[@engine.Param]
  rows : FixedArray[Json]
}

///|
impl @engine.Engine for MockEngine with render(_self, stmt : @engine.Statement) -> (
  String,
  FixedArray[@engine.Param],
) {
  @engine.render_default_sql(stmt)
}

///|
impl @engine.Engine for MockEngine with tx_begin_sql(_self) -> String {
  "BEGIN"
}

///|
impl @engine.Engine for MockEngine with tx_commit_sql(_self) -> String {
  "COMMIT"
}

///|
impl @engine.Engine for MockEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK"
}

///|
impl @engine.Engine for MockEngine with tx_savepoint_sql(_self, name : String) -> String {
  "SAVEPOINT " + name
}

///|
impl @engine.Engine for MockEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TO SAVEPOINT " + name
}

///|
impl @engine.Engine for MockEngine with migrate_table(
  _self,
  _table_schema : Json,
) -> @engine.QueryResult {
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
impl @engine.Engine for MockEngine with exec_raw(
  self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  if sql == self.expected_sql && params == self.expected_params {
    {
      ok: true,
      rows_affected: self.rows.length(),
      rows: self.rows,
      error: None,
    }
  } else {
    {
      ok: false,
      rows_affected: 0,
      rows: [],
      error: Some("unexpected sql/params"),
    }
  }
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
    expected_sql: "SELECT * FROM teachers WHERE id IN (?, ?)",
    expected_params: [@engine.Double(10), @engine.Double(11)],
    rows: [{ "id": 10, "name": "Alice" }, { "id": 11, "name": "Bob" }],
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
    expected_sql: "SELECT * FROM students WHERE teacher_id IN (?, ?)",
    expected_params: [@engine.Double(1), @engine.Double(2)],
    rows: [
      { "id": 100, "teacher_id": 1, "name": "S1" },
      { "id": 101, "teacher_id": 1, "name": "S2" },
      { "id": 102, "teacher_id": 2, "name": "S3" },
    ],
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
