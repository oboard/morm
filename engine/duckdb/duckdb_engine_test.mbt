///|
fn open_test_duckdb() -> DuckDBEngine {
  match DuckDBEngine::open(":memory:") {
    Ok(engine) => engine
    Err(message) => abort(message)
  }
}

///|
test "duckdb opens prefixed in-memory paths" {
  let engine = match DuckDBEngine::open("jdbc:duckdb://:memory:") {
    Ok(engine) => engine
    Err(message) => abort(message)
  }
  engine.close()
}

///|
async test "duckdb migrates schema and executes query builders" {
  let engine = open_test_duckdb()
  let table_schema = @morm.add_index(
    @morm.new_table("records", columns=[
      {
        ..@morm.new_column("id", @table.BigInt),
        primary_key: true,
        auto_increment: true,
      },
      { ..@morm.new_column("name", @table.VarChar(80)), nullable: false, },
      @morm.new_column("active", @table.Boolean),
      @morm.new_column("score", @table.Decimal(10, 2)),
      @morm.new_column("payload", @table.Blob),
    ]),
    @morm.new_unique_index("records_name", ["name"]),
  )
  inspect(engine.migrate_table(table_schema).ok, content="true")
  inspect(engine.migrate_table(table_schema).ok, content="true")

  let binary = Bytes::from_array([
    (65).to_byte(),
    (0).to_byte(),
    (92).to_byte(),
    (255).to_byte(),
  ])
  let inserted = engine.exec(
    @morm.insert_into("records")
    .columns(["name", "active", "score", "payload"])
    .values([
      @morm/engine.String("Alice"),
      @morm/engine.Bool(true),
      @morm/engine.Decimal("12.25"),
      @morm/engine.Bytes(binary),
    ]),
  )
  inspect(inserted.ok, content="true")
  inspect(inserted.rows_affected, content="1")
  inspect(inserted.rows.length(), content="1")
  inspect(
    inserted.rows[0].get("id") == Some(@morm/engine.Int64(1L)),
    content="true",
  )
  inspect(
    inserted.rows[0].get("score") == Some(@morm/engine.Decimal("12.25")),
    content="true",
  )
  inspect(
    inserted.rows[0].get("payload") == Some(@morm/engine.Bytes(binary)),
    content="true",
  )

  let second = engine.exec_raw(
    "INSERT INTO records (name, active) VALUES (?, ?)",
    [@morm/engine.String("Bob"), @morm/engine.Null],
  )
  inspect(second.ok, content="true")
  inspect(second.rows_affected, content="1")
  inspect(second.rows.length(), content="0")

  let upserted = engine.exec(
    @morm.upsert_into("records")
    .set("id", @morm/engine.Int64(1L))
    .set("name", @morm/engine.String("Alice"))
    .set("active", @morm/engine.Bool(false))
    .on_conflict(["id"])
    .do_update_set("active", @morm/engine.Bool(false)),
  )
  inspect(upserted.ok, content="true")
  inspect(upserted.rows.length(), content="1")
  inspect(
    upserted.rows[0].get("active") == Some(@morm/engine.Bool(false)),
    content="true",
  )

  let selected = engine.exec(
    @morm.select_from("records").where_eq("name", "Alice"),
  )
  inspect(selected.ok, content="true")
  inspect(selected.rows.length(), content="1")
  inspect(
    selected.rows[0].get("payload") == Some(@morm/engine.Bytes(binary)),
    content="true",
  )

  let nulls = engine.exec(
    @morm.select_from("records").where_eq("active", @morm/engine.Null),
  )
  inspect(nulls.rows.length(), content="1")
  inspect(
    nulls.rows[0].get("active") == Some(@morm/engine.Null),
    content="true",
  )

  let page = engine.page(
    @morm.select_from("records"),
    @morm.pageable_with_sort(1, 1, @morm.desc("id")),
  )
  inspect(page.rows.length(), content="1")
  inspect(
    page.rows[0].get("name") == Some(@morm/engine.String("Bob")),
    content="true",
  )
  let raw_page = engine.page_raw(
    "SELECT name FROM records ORDER BY id",
    [],
    @morm.pageable(2, 1),
  )
  inspect(
    raw_page.rows[0].get("name") == Some(@morm/engine.String("Bob")),
    content="true",
  )

  let updated = engine.exec(
    @morm.update("records").set("name", "Carol").where_eq("id", 2),
  )
  inspect(updated.ok, content="true")
  inspect(updated.rows_affected, content="1")
  let deleted = engine.exec(@morm.delete_from("records").where_eq("id", 2))
  inspect(deleted.ok, content="true")
  inspect(deleted.rows_affected, content="1")

  engine.close()
  inspect(engine.exec_raw("SELECT 1", []).ok, content="false")
  engine.close()
}

///|
async test "duckdb preserves wide values and recovers from bind errors" {
  let engine = open_test_duckdb()
  inspect(
    engine.exec_raw("CREATE TABLE numbers (signed BIGINT, unsigned UBIGINT)", []).ok,
    content="true",
  )
  inspect(
    engine.exec_raw("INSERT INTO numbers VALUES (?, ?)", [
      @morm/engine.Int64(9223372036854775807L),
      @morm/engine.UInt64(18446744073709551615UL),
    ]).ok,
    content="true",
  )
  let numbers = engine.exec_raw("SELECT * FROM numbers", [])
  inspect(
    numbers.rows[0].get("signed") ==
    Some(@morm/engine.Int64(9223372036854775807L)),
    content="true",
  )
  inspect(
    numbers.rows[0].get("unsigned") ==
    Some(@morm/engine.UInt64(18446744073709551615UL)),
    content="true",
  )
  inspect(
    engine.exec_raw("SELECT ?", [@morm/engine.Int(1), @morm/engine.Int(2)]).ok,
    content="false",
  )
  inspect(
    engine.exec_raw("SELECT missing FROM numbers", []).ok,
    content="false",
  )
  inspect(engine.exec_raw("SELECT 42 AS answer", []).ok, content="true")
  engine.close()
}

///|
async test "duckdb keeps returning columns named Count" {
  let engine = open_test_duckdb()
  inspect(
    engine.exec_raw("CREATE TABLE counters (\"Count\" INTEGER)", []).ok,
    content="true",
  )
  let inserted = engine.exec_raw(
    "INSERT INTO counters VALUES (?) RETURNING \"Count\"",
    [@morm/engine.Int(7)],
  )
  inspect(inserted.ok, content="true")
  inspect(inserted.rows_affected, content="1")
  inspect(
    inserted.rows[0].get("Count") == Some(@morm/engine.Int(7)),
    content="true",
  )
  let updated = engine.exec_raw(
    "UPDATE counters SET \"Count\" = 9 RETURNING \"Count\"",
    [],
  )
  inspect(updated.ok, content="true")
  inspect(
    updated.rows[0].get("Count") == Some(@morm/engine.Int(9)),
    content="true",
  )
  let deleted = engine.exec_raw("DELETE FROM counters RETURNING \"Count\"", [])
  inspect(deleted.ok, content="true")
  inspect(
    deleted.rows[0].get("Count") == Some(@morm/engine.Int(9)),
    content="true",
  )
  engine.close()
}

///|
async test "duckdb normalizes timestamps and reports unsupported timestamptz reads" {
  let engine = open_test_duckdb()
  let local_time = try! @time.PlainDateTime::from_string("2026-07-10T12:00:00")
  let zoned = try! @time.ZonedDateTime::from_string("2026-07-10T12:00:00Z")
  inspect(
    engine.exec_raw(
      "CREATE TABLE temporal (local_time TIMESTAMP, zoned_time TIMESTAMPTZ)",
      [],
    ).ok,
    content="true",
  )
  inspect(
    engine.exec_raw("INSERT INTO temporal VALUES (?, ?)", [
      @morm/engine.DateTime(local_time, None),
      @morm/engine.Timestamp(zoned, None),
    ]).ok,
    content="true",
  )
  let row = engine.exec_raw("SELECT local_time FROM temporal", []).rows[0]
  let decoded_local : @time.PlainDateTime = try! @morm/engine.from_param(
    row["local_time"],
  )
  inspect(decoded_local == local_time, content="true")
  let uncast = engine.exec_raw("SELECT zoned_time FROM temporal", [])
  inspect(uncast.ok, content="false")
  inspect(uncast.error is Some(_), content="true")
  let cast = engine.exec_raw(
    "SELECT CAST(zoned_time AS VARCHAR) AS zoned_text FROM temporal",
    [],
  )
  inspect(cast.ok, content="true")
  let cast_text = match cast.rows[0].get("zoned_text") {
    Some(@morm/engine.String(text)) => text
    _ => abort("expected a timestamp string")
  }
  inspect(cast_text != "", content="true")
  engine.close()
}

///|
async test "duckdb transaction and index migration errors" {
  let engine = open_test_duckdb()
  inspect(
    engine.exec_raw("CREATE TABLE items (id INTEGER)", []).ok,
    content="true",
  )
  inspect(engine.exec(@morm/engine.Tx(Begin)).ok, content="true")
  inspect(
    engine.exec_raw("INSERT INTO items VALUES (1)", []).ok,
    content="true",
  )
  inspect(engine.exec(@morm/engine.Tx(Rollback)).ok, content="true")
  inspect(
    engine.exec_raw("SELECT count(*) AS total FROM items", []).rows[0].get(
      "total",
    ) ==
    Some(@morm/engine.Int64(0L)),
    content="true",
  )
  inspect(engine.exec(@morm/engine.Tx(Begin)).ok, content="true")
  inspect(
    engine.exec_raw("INSERT INTO items VALUES (2)", []).ok,
    content="true",
  )
  inspect(engine.exec(@morm/engine.Tx(Commit)).ok, content="true")
  inspect(
    engine.exec_raw("SELECT count(*) AS total FROM items", []).rows[0].get(
      "total",
    ) ==
    Some(@morm/engine.Int64(1L)),
    content="true",
  )

  let unsupported = @morm.add_index(
    @morm.new_table("unsupported", columns=[@morm.new_column("id", @table.Int)]),
    { ..@morm.new_index("unsupported_search", ["id"]), index_type: FullText, },
  )
  inspect(engine.migrate_table(unsupported).ok, content="false")
  inspect(engine.exec_raw("SELECT * FROM unsupported", []).ok, content="false")
  engine.close()
}

///|
async test "duckdb migrates qualified tables, foreign keys, and json" {
  let engine = open_test_duckdb()
  inspect(engine.exec_raw("CREATE SCHEMA analytics", []).ok, content="true")
  let parent = @morm.table_schema(
    @morm.new_table("parents", columns=[
      {
        ..@morm.new_column("id", @table.BigInt),
        primary_key: true,
        auto_increment: true,
      },
    ]),
    "analytics",
  )
  inspect(engine.migrate_table(parent).ok, content="true")
  let child = @morm.add_foreign_key(
    @morm.table_schema(
      @morm.new_table("children", columns=[
        { ..@morm.new_column("id", @table.Int), primary_key: true, },
        @morm.new_column("parent_id", @table.BigInt),
        @morm.new_column("payload", @table.Json),
      ]),
      "analytics",
    ),
    @morm.new_foreign_key(
      "children_parent", "parent_id", "analytics.parents", "id",
    ),
  )
  inspect(engine.migrate_table(child).ok, content="true")
  let inserted = engine.exec_raw(
    "INSERT INTO analytics.parents DEFAULT VALUES RETURNING id",
    [],
  )
  inspect(inserted.ok, content="true")
  inspect(
    inserted.rows[0].get("id") == Some(@morm/engine.Int64(1L)),
    content="true",
  )
  inspect(
    engine.exec_raw("INSERT INTO analytics.children VALUES (?, ?, ?)", [
      @morm/engine.Int(1),
      @morm/engine.Int64(1L),
      @morm/engine.Json(@json.parse("{\"ok\":true}")),
    ]).ok,
    content="true",
  )
  inspect(
    engine.exec_raw("SELECT payload FROM analytics.children", []).rows[0].get(
      "payload",
    ) ==
    Some(@morm/engine.String("{\"ok\":true}")),
    content="true",
  )
  inspect(
    engine.exec_raw("INSERT INTO analytics.children VALUES (2, 99, '{}')", []).ok,
    content="false",
  )
  engine.close()
}
