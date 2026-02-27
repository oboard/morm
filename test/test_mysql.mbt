///|
test "query-sql" {
  let q1 = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .page(2, 5)
  let (sql, _) = @engine.render_default_sql(q1.to_statement())
  inspect(
    sql,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}

///|
test "insert-sql" {
  let vals : FixedArray[@engine.Param] = [
    @engine.Int(1),
    @engine.String("Alice"),
    @engine.Int(20),
    @engine.String("2000-01-01"),
  ]
  let q = @morm.insert_into("students")
    .columns(["id", "name", "age", "birth_date"])
    .values(vals)
  let (sql, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql,
    content=(
      #|INSERT INTO students (id, name, age, birth_date) VALUES (?, ?, ?, ?)
    ),
  )
}

///|
test "update-sql" {
  let q = @morm.update("students")
    .set("name", "Bob")
    .set("age", 21)
    .where_eq("id", 1)
  let (sql, _) = @engine.render_default_sql(q.to_statement())
  inspect(sql, content="UPDATE students SET name = ?, age = ? WHERE id = ?")
}

///|
test "delete-sql" {
  let (sql, _) = @engine.render_default_sql(
    @morm.delete_from("students").where_eq("id", 1).to_statement(),
  )
  inspect(
    sql,
    content=(
      #|DELETE FROM students WHERE id = ?
    ),
  )
}
