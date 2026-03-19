///|
test "query-sql-pgsql" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .page(2, 5)
  let (sql, _) = @engine.render_query_sql(q)
  inspect(
    sql,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}

///|
test "insert-sql-pgsql" {
  let q = @morm.insert_into("students")
    .columns(["id", "name", "age", "birth_date"])
    .values([1, "Alice", 20, "2000-01-01"])
  let (sql, _) = @engine.render_query_sql(q)
  inspect(
    sql,
    content=(
      #|INSERT INTO students (id, name, age, birth_date) VALUES (?, ?, ?, ?)
    ),
  )
}

///|
test "update-sql-pgsql" {
  let q = @morm.update("students")
    .set("name", "Bob")
    .set("age", 21)
    .where_eq("id", 1)
  let (sql, _) = @engine.render_query_sql(q)
  inspect(
    sql,
    content=(
      #|UPDATE students SET name = ?, age = ? WHERE id = ?
    ),
  )
}

///|
test "delete-sql-pgsql" {
  let (sql, _) = @engine.render_query_sql(
    @morm.delete_from("students").where_eq("id", 1),
  )
  inspect(
    sql,
    content=(
      #|DELETE FROM students WHERE id = ?
    ),
  )
}
