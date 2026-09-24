///|
test "duckdb driver scheme" {
  inspect(
    resolve_driver_name("duckdb://:memory:") == Some("duckdb"),
    content="true",
  )
  inspect(
    resolve_driver_name("jdbc:duckdb:///tmp/app.duckdb") == Some("duckdb"),
    content="true",
  )
}
