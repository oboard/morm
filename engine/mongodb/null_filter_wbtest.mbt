///|
fn where_clause(
  ty : @engine.WhereType,
  value : @engine.Param,
) -> FixedArray[@engine.Where] {
  [{ col: "status", value, ty }]
}

///|
test "mongodb null where builds expected filters" {
  let eq_filter = where_to_filter(where_clause(@engine.Eq, @engine.Null))
  json_inspect(eq_filter, content={ "status": Json::null() })

  let ne_filter = where_to_filter(
    where_clause(@engine.Ne, @engine.Json(Json::null())),
  )
  json_inspect(ne_filter, content={ "status": { "$ne": Json::null() } })
}
