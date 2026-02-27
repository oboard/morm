///|
test "update-sqlserver-bool" {
  let (sql, _) = @engine.render_default_sql(
    @morm.update("students").set("active", true).to_statement(),
  )
  inspect(
    sql,
    content=(
      #|UPDATE students SET active = ?
    ),
  )
}
