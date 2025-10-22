///|
// test "json" {
//   let student = { id: 1, name: "Alice", age: 20, birth_date: "2000-01-01" }
//   @json.inspect(student.table(), content={
//     "name": "Student",
//     "columns": [
//       {
//         "name": "id",
//         "column_type": "Int",
//         "size": 0,
//         "nullable": true,
//         "auto_increment": false,
//         "primary_key": false,
//         "unique": false,
//         "comment": "",
//       },
//       {
//         "name": "name",
//         "column_type": ["VarChar", 255],
//         "size": 255,
//         "nullable": true,
//         "auto_increment": false,
//         "primary_key": false,
//         "unique": false,
//         "comment": "",
//       },
//       {
//         "name": "age",
//         "column_type": "Int",
//         "size": 0,
//         "nullable": true,
//         "auto_increment": false,
//         "primary_key": false,
//         "unique": false,
//         "comment": "",
//       },
//       {
//         "name": "birth_date",
//         "column_type": ["VarChar", 255],
//         "size": 255,
//         "nullable": true,
//         "auto_increment": false,
//         "primary_key": false,
//         "unique": false,
//         "comment": "",
//       },
//     ],
//     "indexes": [],
//     "foreign_keys": [],
//     "engine": "InnoDB",
//     "charset": "utf8mb4",
//     "collation": "utf8mb4_unicode_ci",
//     "comment": "",
//     "auto_increment": 1,
//   })
// }

///|
// removed flaky driver test

///|
test "query-sql" {
  let q1 = @morm.where_eq(@morm.select_from("students"), "id")
  let q2 = @morm.order_by(q1, "id DESC")
  let q3 = @morm.limit(q2, 10)
  let q4 = @morm.offset(q3, 5)
  let (sql, _) = @morm.to_mysql_sql(q4)
  assert_eq(
    sql, "SELECT * FROM students WHERE id = ? ORDER BY id DESC LIMIT 10 OFFSET 5",
  )
}
