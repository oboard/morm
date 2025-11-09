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

///|
test "generated class with foreign key" {
  let class_obj = Class::{ id: 10, name: "Math 101", teacher_id: 1 }
  let table = class_obj.table()

  // 表名
  assert_eq(table.name, "Class")

  // 列数量（id, name, teacher_id）
  assert_eq(table.columns.length(), 3)

  // teacher_id 列存在
  let teacher_id_col = table.columns[2]
  assert_eq(teacher_id_col.name, "teacher_id")
  assert_eq(teacher_id_col.column_type, Int)
  assert_eq(teacher_id_col.nullable, true) // 未标注 not_null

  // 外键约束存在
  assert_eq(table.foreign_keys.length(), 1)
  let fk = table.foreign_keys[0]
  assert_eq(fk.name, "fk_Class_teacher_id")
  assert_eq(fk.column, "teacher_id")
  assert_eq(fk.referenced_table, "teacher")
  assert_eq(fk.referenced_column, "id")
  assert_eq(fk.on_delete, "CASCADE")
}
