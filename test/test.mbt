///|
test "query" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .offset(5)
    .limit(5)
  let (sql_pg, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_pg,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_my, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_my,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_ora, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_ora,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_ss, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_ss,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
  let (sql_sqlite, _) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql_sqlite,
    content=(
      #|SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}

///|
test "query where ne like" {
  let q = @morm.select_from("students")
    .where_ne("status", "deleted")
    .where_like("name", "%Ali%")
  let (sql, params) = @engine.render_default_sql(q.to_statement())
  inspect(
    sql,
    content=(
      #|SELECT * FROM students WHERE status != ? AND name LIKE ?
    ),
  )
  inspect(params.to_json().stringify(), content="[\"deleted\",\"%Ali%\"]")
}

///|
test "param extended types to_json" {
  let date = @time.PlainDate::from_string("2026-01-02") catch { _ => panic() }
  let time = @time.PlainTime::from_string("12:34:56") catch { _ => panic() }
  let date_time = @time.PlainDateTime::from_string("2026-01-02T12:34:56") catch {
    _ => panic()
  }
  let timestamp = @time.ZonedDateTime::from_string("2026-01-02T12:34:56Z") catch {
    _ => panic()
  }
  inspect(@engine.Decimal("12.34").to_json().stringify(), content="\"12.34\"")
  inspect(
    @engine.to_param(date).to_json().stringify(),
    content="\"2026-01-02\"",
  )
  inspect(@engine.to_param(time).to_json().stringify(), content="\"12:34:56\"")
  inspect(
    @engine.to_param(date_time).to_json().stringify(),
    content="\"2026-01-02T12:34:56\"",
  )
  inspect(
    @engine.to_param(timestamp).to_json().stringify(),
    content="\"2026-01-02T12:34:56Z\"",
  )
  inspect(
    @engine.Uuid("550e8400-e29b-41d4-a716-446655440000").to_json().stringify(),
    content="\"550e8400-e29b-41d4-a716-446655440000\"",
  )
  inspect(
    @engine.Json({ "a": 1, "b": true }).to_json().stringify(),
    content="{\"a\":1,\"b\":true}",
  )
}

///|
test "time types json roundtrip" {
  let date : @time.PlainDate = @json.from_json("2026-01-02".to_json()) catch {
    _ => panic()
  }
  let time : @time.PlainTime = @json.from_json("12:34:56".to_json()) catch {
    _ => panic()
  }
  let date_time : @time.PlainDateTime = @json.from_json(
    "2026-01-02T12:34:56".to_json(),
  ) catch {
    _ => panic()
  }
  let timestamp : @time.ZonedDateTime = @json.from_json(
    "2026-01-02T12:34:56Z".to_json(),
  ) catch {
    _ => panic()
  }
  inspect(date.to_string(), content="2026-01-02")
  inspect(time.to_string(), content="12:34:56")
  inspect(date_time.to_string(), content="2026-01-02T12:34:56")
  inspect(timestamp.to_string(), content="2026-01-02T12:34:56Z")
}
