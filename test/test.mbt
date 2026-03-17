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
test "param temporal format annotation" {
  let date = @time.PlainDate::from_string("2026-01-02") catch { _ => panic() }
  let time = @time.PlainTime::from_string("12:34:56") catch { _ => panic() }
  let timestamp = @time.ZonedDateTime::from_string("2026-01-02T12:34:56Z") catch {
    _ => panic()
  }
  inspect(
    @engine.Date(date, Some("yyyy/MM/dd")).to_json().stringify(),
    content="\"2026/01/02\"",
  )
  inspect(
    @engine.Time(time, Some("HH-mm-ss")).to_json().stringify(),
    content="\"12-34-56\"",
  )
  inspect(
    @engine.Timestamp(timestamp, Some("yyyy-MM-dd HH:mm:ss Z"))
    .to_json()
    .stringify(),
    content="\"2026-01-02 12:34:56 Z\"",
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

///|
test "from_param decodes scalar values" {
  let id : Int64 = try! @engine.from_param(
    @engine.param_from_json_value("42".to_json()),
  )
  let name : String = try! @engine.from_param(
    @engine.param_from_json_value("alice".to_json()),
  )
  let created_at : @time.PlainDateTime = try! @engine.from_param(
    @engine.param_from_json_value("2026-01-02T12:34:56".to_json()),
  )
  inspect(id.to_string(), content="42")
  inspect(name, content="alice")
  inspect(created_at.to_string(), content="2026-01-02T12:34:56")
}

///|
pub(all) struct BsonDoc {
  id : Int64
  payload : Json
} derive(ToJson, FromJson)

///|
pub(all) struct UpdateFromEntity {
  id : Int
  name : String
  display_name : String?
} derive(ToJson, FromJson)

///|
pub impl @morm.Entity for BsonDoc with table(_self) -> @morm.Table {
  @morm.new_table("bson_doc", columns=[
    @morm.new_column("id", BigInt),
    {
      ..@morm.new_column("payload", Json),
      engine_options: [{ key: "json.storage", value: "bson" }],
    },
  ])
}

///|
pub impl @morm.Entity for UpdateFromEntity with table(_self) -> @morm.Table {
  @morm.new_table("update_from_entity", columns=[
    @morm.new_column("id", Int),
    @morm.new_column("name", VarChar(255)),
  ])
}

///|
test "bson roundtrip" {
  let value : Json = {
    "name": "alice",
    "active": true,
    "ids": [1, 2, 3],
    "meta": { "score": 7, "ok": false, "note": Json::null() },
  }
  let bytes = @bson.to_bytes(value)
  let decoded = try! @bson.from_bytes(bytes)
  if decoded
    is {
      "name": "alice",
      "active": True,
      "ids": [1, 2, 3],
      "meta": { "score": 7, "ok": False, "note": Null, .. },
      ..
    } {
    inspect(true, content="true")
  } else {
    fail("unexpected bson decode result")
  }
}

///|
test "update from entity only uses physical table columns" {
  let q = @morm.update("update_from_entity").from(UpdateFromEntity::{
    id: 1,
    name: "alice",
    display_name: Some("Alice"),
  })
  let (sql, params) = @engine.render_default_sql(q.to_statement())
  inspect(sql, content="UPDATE update_from_entity SET id = ?, name = ?")
  inspect(params.to_json().stringify(), content="[1,\"alice\"]")
}

///|
test "insert from entity encodes bson column as bytes" {
  let value : Json = { "kind": "doc", "n": 3 }
  let q = @morm.insert_into("bson_doc").from(BsonDoc::{ id: 1, payload: value })
  let (_, params) = @engine.render_default_sql(q.to_statement())
  match params[1] {
    @engine.Bytes(bytes) => {
      let decoded = try! @bson.from_bytes(bytes)
      inspect(decoded.stringify(), content="{\"kind\":\"doc\",\"n\":3}")
    }
    _ => fail("expected BSON bytes")
  }
}

///|
test "insert values_many renders single multi-row sql" {
  let q = @morm.insert_into("students")
    .columns(["id", "name"])
    .values_many([
      [@engine.Int(1), @engine.String("Alice")],
      [@engine.Int(2), @engine.String("Bob")],
    ])
  let (sql, params) = @engine.render_default_sql(q.to_statement())
  inspect(sql, content="INSERT INTO students (id, name) VALUES (?, ?), (?, ?)")
  inspect(params.to_json().stringify(), content="[1,\"Alice\",2,\"Bob\"]")
}
