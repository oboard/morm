///|
test "query-sql-oracle" {
  let q = @morm.select_from("students").order_by(Desc("id")).page(2, 5)
  let sql = q.to(Oracle)
  inspect(
    sql,
    content=(
      #|SELECT * FROM students ORDER BY id DESC OFFSET 5 ROWS FETCH NEXT 5 ROWS ONLY
    ),
  )
}
