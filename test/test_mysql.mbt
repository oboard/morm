///|
test "query-sql" {
  let q1 = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .page(2, 5)
  let (sql, params) = q1.to(MySQL)
  inspect(
    sql,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}

///|
test "insert-sql" {
  let vals : FixedArray[Json] = [1, "Alice", 20, "2000-01-01"]
  let (sql, params) = @morm.insert_into("students")
    .columns(["id", "name", "age", "birth_date"])
    .values(vals)
    .to(MySQL)
  inspect(
    sql,
    content=(
      #|INSERT INTO students (id, name, age, birth_date) VALUES (?, ?, ?, ?)
    ),
  )
}

///|
test "update-sql" {
  let (sql, params) = @morm.update("students")
    .set("name", "Bob")
    .set("age", 21)
    .where_eq("id", 1)
    .to(MySQL)
  inspect(
    sql,
    content="UPDATE students SET name = ?, age = ? WHERE id = ?",
  )
}

///|
test "delete-sql" {
  let (sql, params) = @morm.delete_from("students").where_eq("id", 1).to(MySQL)
  inspect(
    sql,
    content=(
      #|DELETE FROM students WHERE id = ?
    ),
  )
}
