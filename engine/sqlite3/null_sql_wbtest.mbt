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
test "sqlite null where renders is null/is not null" {
  let (sql_eq, params_eq) = render_sqlite(select_stmt_with_null(Eq, Null))
  assert_eq(sql_eq, "SELECT * FROM users WHERE status IS NULL")
  assert_eq(params_eq.length(), 0)

  let (sql_ne, params_ne) = render_sqlite(
    select_stmt_with_null(Ne, Json(Json::null())),
  )
  assert_eq(sql_ne, "SELECT * FROM users WHERE status IS NOT NULL")
  assert_eq(params_ne.length(), 0)
}
