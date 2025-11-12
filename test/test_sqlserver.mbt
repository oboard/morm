///|
test "update-sqlserver-bool" {
  let (sql, _) = @morm.update("students").set("active", true).to(SqlServer)
  inspect(
    sql,
    content=(
      #|UPDATE students SET active = ?
    ),
  )
}
