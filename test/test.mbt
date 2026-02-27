///|
test "query" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .offset(5)
    .limit(5)
  let (sql_pg, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_pg,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_my, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_my,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_ora, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_ora,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_ss, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_ss,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_sqlite, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_sqlite,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}
