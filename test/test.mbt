///|
test "query" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .offset(5)
    .limit(5)
  inspect(
    q.to(PgSQL),
    content=(
      #|SELECT * FROM students WHERE id = 1 AND name = 'Alice' ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  inspect(
    q.to(MySQL),
    content=(
      #|SELECT * FROM students WHERE id = 1 AND name = "Alice" ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  inspect(
    q.to(Oracle),
    content="SELECT * FROM students WHERE id = 1 AND name = 'Alice' ORDER BY id DESC OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY",
  )
  inspect(
    q.to(SqlServer),
    content="SELECT * FROM students WHERE id = 1 AND name = 'Alice' ORDER BY id DESC OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY",
  )
  inspect(
    q.to(Sqlite3),
    content=(
      #|SELECT * FROM students WHERE id = 1 AND name = 'Alice' ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}
