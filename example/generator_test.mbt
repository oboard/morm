///|
priv struct MySQLEngine {}

///|
fn MySQLEngine::open(_url : String) -> MySQLEngine {
  MySQLEngine::{  }
}

///|
impl @engine.Engine for MySQLEngine with close(_self) -> Unit {

}

///|
impl @engine.Engine for MySQLEngine with render(_self, stmt : @engine.Statement) -> (
  String,
  FixedArray[@engine.Param],
) {
  @engine.render_default_sql(stmt)
}

///|
impl @engine.Engine for MySQLEngine with tx_begin_sql(_self) -> String {
  "START TRANSACTION"
}

///|
impl @engine.Engine for MySQLEngine with tx_commit_sql(_self) -> String {
  "COMMIT"
}

///|
impl @engine.Engine for MySQLEngine with tx_rollback_sql(_self) -> String {
  "ROLLBACK"
}

///|
impl @engine.Engine for MySQLEngine with tx_savepoint_sql(_self, name : String) -> String {
  "SAVEPOINT " + name
}

///|
impl @engine.Engine for MySQLEngine with tx_rollback_to_savepoint_sql(
  _self,
  name : String,
) -> String {
  "ROLLBACK TO SAVEPOINT " + name
}

///|
impl @engine.Engine for MySQLEngine with migrate_table(
  _self,
  table_schema : Json,
) -> @engine.QueryResult {
  println("migrate table: " + table_schema.stringify())
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
impl @engine.Engine for MySQLEngine with exec_raw(
  _self,
  sql : String,
  params : FixedArray[@engine.Param],
) -> @engine.QueryResult {
  println(sql)
  println(params.to_json().stringify())
  { ok: true, rows_affected: 0, rows: [], error: None }
}

///|
impl @engine.Engine for MySQLEngine with preload_in_sql(
  _self,
  table : String,
  key_col : String,
  count : Int,
) -> String {
  @engine.preload_in_sql_qmark(table, key_col, count)
}

///|
impl @engine.Engine for MySQLEngine with preload_many_to_many_sql(
  _self,
  target_table : String,
  target_key : String,
  join_table : String,
  join_owner_key : String,
  join_target_key : String,
  count : Int,
) -> String {
  @engine.preload_many_to_many_sql_qmark(
    target_table, target_key, join_table, join_owner_key, join_target_key, count,
  )
}

///|
async test "auto migrate" {
  let engine = MySQLEngine::open("mysql://root:123456@localhost:3306/test")
  @morm.auto_migrate(engine, [Student::table()])
  engine.close()
}

///|
async test "mapper" {
  let engine = MySQLEngine::open("mysql://root:123456@localhost:3306/test")
  let studentMapper = StudentMapperImpl::new(engine)
  let student = studentMapper.find_student_by_name("Alice")
  inspect(student.to_json(), content="Null")
}

///|
async test "mapper relation annotations" {
  let engine = MySQLEngine::open("mysql://root:123456@localhost:3306/test")
  let enrollment_mapper = EnrollmentMapperImpl::new(engine)
  let rows = enrollment_mapper.find_enrollments_by_student_id(1)
  inspect(rows.length(), content="0")
  let raw_rows = enrollment_mapper.find_by_class_raw(2)
  inspect(raw_rows.length(), content="0")
  let with_student = enrollment_mapper.find_with_student_by_id(1)
  inspect(with_student.to_json(), content="Null")
  let with_class = enrollment_mapper.find_with_class_by_id(1)
  inspect(with_class.to_json(), content="Null")
}

///|
test "generated entity" {
  let birth_date = @time.ZonedDateTime::from_string("2003-01-01T00:00:00Z") catch {
    _ => panic()
  }
  let student = Student::{ id: 1, name: "Alice", age: 20, birth_date }
  let q1 = @morm.insert_into("students").from(student)
  let (sql1, params1) = @engine.render_default_sql(q1.to_statement())
  inspect(
    sql1,
    content=(
      #|INSERT INTO students (id, name, age, birth_date) VALUES (?, ?, ?, ?)
    ),
  )
  inspect(
    params1.to_json().stringify(),
    content="[\"1\",\"Alice\",20,\"2003-01-01T00:00:00Z\"]",
  )
  let table = Student::table()

  // 验证表名
  assert_eq(table.name, "student")

  // 验证列数量
  assert_eq(table.columns.length(), 4)

  // 验证 id 列
  let id_col = table.columns[0]
  assert_eq(id_col.name, "id")
  assert_eq(id_col.column_type, BigInt)
  assert_eq(id_col.primary_key, true)
  assert_eq(id_col.auto_increment, true)
  assert_eq(id_col.nullable, false)

  // 验证 name 列
  let name_col = table.columns[1]
  assert_eq(name_col.name, "name")
  assert_eq(name_col.column_type, VarChar(255))
  assert_eq(name_col.primary_key, false)

  // 验证 age 列
  let age_col = table.columns[2]
  assert_eq(age_col.name, "age")
  assert_eq(age_col.column_type, Int)

  // 验证 birth_date 列
  let birth_date_col = table.columns[3]
  assert_eq(birth_date_col.name, "birth_date")
  assert_eq(birth_date_col.column_type, DateTime)
}

///|
test "generated class with foreign key" {
  let class_obj = Class::{ id: 10, name: "Math 101", teacher_id: 1 }
  let q2 = @morm.insert_into("classes").from(class_obj)
  let (sql2, params2) = @engine.render_default_sql(q2.to_statement())
  inspect(
    sql2,
    content=(
      #|INSERT INTO classes (id, name, teacher_id) VALUES (?, ?, ?)
    ),
  )
  inspect(params2.to_json().stringify(), content="[\"10\",\"Math 101\",1]")
  let table = Class::table()

  // 表名
  assert_eq(table.name, "class")

  // 列数量（id, name, teacher_id）
  assert_eq(table.columns.length(), 3)

  // teacher_id 列存在
  let teacher_id_col = table.columns[2]
  assert_eq(teacher_id_col.name, "teacher_id")
  assert_eq(teacher_id_col.column_type, Int)
  assert_eq(teacher_id_col.nullable, false)

  // 外键约束存在
  assert_eq(table.foreign_keys.length(), 1)
  let fk = table.foreign_keys[0]
  assert_eq(fk.name, "fk_Class_teacher_id")
  assert_eq(fk.column, "teacher_id")
  assert_eq(fk.referenced_table, "teacher")
  assert_eq(fk.referenced_column, "id")
  assert_eq(fk.on_delete, "CASCADE")
}

///|
test {
  let teacher = Teacher::{
    id: 1,
    name: "666",
    age: 12,
    major: "English",
    birth_date: None,
  }
  json_inspect(teacher, content={
    "id": "1",
    "name": "666",
    "major": "English",
    "age": 12,
  })
  let teacher_birth = @time.ZonedDateTime::from_string("2022-03-04T00:00:00Z") catch {
    _ => panic()
  }
  let teacher = Teacher::{
    id: 1,
    name: "666",
    age: 12,
    major: "English",
    birth_date: Some(teacher_birth),
  }
  json_inspect(teacher, content={
    "id": "1",
    "name": "666",
    "major": "English",
    "age": 12,
    "birth_date": "2022-03-04T00:00:00Z",
  })
}

///|
test "generated enrollment relation table" {
  let table = Enrollment::table()
  assert_eq(table.name, "enrollment")
  assert_eq(table.columns.length(), 4)
  assert_eq(table.columns[1].name, "student_id")
  assert_eq(table.columns[2].name, "class_id")
  assert_eq(table.foreign_keys.length(), 2)
  let fk1 = table.foreign_keys[0]
  assert_eq(fk1.column, "student_id")
  assert_eq(fk1.referenced_table, "student")
  assert_eq(fk1.referenced_column, "id")
  assert_eq(fk1.on_delete, "CASCADE")
  let fk2 = table.foreign_keys[1]
  assert_eq(fk2.column, "class_id")
  assert_eq(fk2.referenced_table, "class")
  assert_eq(fk2.referenced_column, "id")
}

///|
test "generated one_to_many is skipped from columns" {
  let table = StudentAggregate::table()
  assert_eq(table.columns.length(), 1)
  assert_eq(table.columns[0].name, "id")
}
