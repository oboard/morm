///|
fn select_stmt_with_null(
  where_ty : @engine.WhereType,
  value : @engine.Param,
) -> @engine.Statement {
  @engine.Select({
    select: "*",
    from: "users",
    joins: [],
    where_: [{ col: "status", value, ty: where_ty }],
    order_by: [],
    limit: None,
    offset: None,
  })
}

///|
test "sqlserver null where renders is null/is not null" {
  let (sql_eq, params_eq) = @engine.render_default_sql(
    select_stmt_with_null(@engine.Eq, @engine.Null),
  )
  assert_eq(sql_eq, "SELECT * FROM users WHERE status IS NULL")
  assert_eq(params_eq.length(), 0)
  assert_eq(
    inline_sql(sql_eq, params_eq),
    "SELECT * FROM users WHERE status IS NULL",
  )

  let (sql_ne, params_ne) = @engine.render_default_sql(
    select_stmt_with_null(@engine.Ne, @engine.Json(Json::null())),
  )
  assert_eq(sql_ne, "SELECT * FROM users WHERE status IS NOT NULL")
  assert_eq(params_ne.length(), 0)
  assert_eq(
    inline_sql(sql_ne, params_ne),
    "SELECT * FROM users WHERE status IS NOT NULL",
  )
}
