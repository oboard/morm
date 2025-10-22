///|
test "generated entity" {
  let student = Student::{
    id: 1,
    name: "Alice",
    age: 20,
    birth_date: "2003-01-01",
  }
  let table = student.table()

  // 验证表名
  assert_eq(table.name, "Student")

  // 验证列数量
  assert_eq(table.columns.length(), 4)

  // 验证 id 列
  let id_col = table.columns[0]
  assert_eq(id_col.name, "id")
  assert_eq(id_col.column_type, Int)
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
