///|
test "query" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .offset(5)
    .limit(5)
  let (sql_pg, params_pg) = q.to(PgSQL)
  inspect(
    sql_pg,
    content=(
      #|SELECT * FROM students WHERE id = $1 AND name = $2 ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_my, params_my) = q.to(MySQL)
  inspect(
    sql_my,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_ora, params_ora) = q.to(Oracle)
  inspect(
    sql_ora,
    content="SELECT * FROM students WHERE id = :1 AND name = :2 ORDER BY id DESC OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY",
  )
  let (sql_ss, params_ss) = q.to(SqlServer)
  inspect(
    sql_ss,
    content="SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY",
  )
  let (sql_sqlite, params_sqlite) = q.to(Sqlite3)
  inspect(
    sql_sqlite,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}
