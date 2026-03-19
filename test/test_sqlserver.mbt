///|
test "update-sqlserver-bool" {
  let (sql, _) = @engine.render_query_sql(
    @morm.update("students").set("active", true),
  )
  inspect(
    sql,
    content=(
      #|UPDATE students SET active = ?
    ),
  )
}
