///|
test "query-sql-oracle" {
  let q = @morm.select_from("students").order_by(Desc("id")).page(2, 5)
  let (sql, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql,
    content=(
      #|SELECT * FROM students ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}
