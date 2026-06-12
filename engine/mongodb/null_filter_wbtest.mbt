///|
fn where_clause(
  ty : @morm/engine.WhereType,
  value : @morm/engine.Param,
) -> FixedArray[@morm/engine.Where] {
  [{ col: "status", value, ty }]
}

///|
test "mongodb null where builds expected filters" {
  let eq_filter = where_to_filter(where_clause(Eq, Null))
  json_inspect(eq_filter, content={ "status": Json::null() })

  let ne_filter = where_to_filter(where_clause(Ne, Json(Json::null())))
  json_inspect(ne_filter, content={ "status": { "$ne": Json::null() } })
}
