///|

///|
fn has_string(values : FixedArray[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn is_search_index_unsupported(err : String) -> Bool {
  err.contains("no such command") ||
  err.contains("CommandNotFound") ||
  err.contains("$listSearchIndexes is not allowed") ||
  err.contains("requires Atlas")
}

///|
async test "mongodb render exec_raw roundtrip" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(@engine.exec_query(engine, @morm.delete_from("roundtrip_test")))

  let insert_stmt = @morm.insert_into("roundtrip_test")
    .columns(["id", "name", "age"])
    .values([@engine.Int(7), @engine.String("Eve"), @engine.Int(25)])
    .to_statement()
  let (insert_sql, insert_params) = engine.render(insert_stmt)
  inspect(insert_params.length(), content="0")
  inspect(engine.exec_raw(insert_sql, insert_params).ok, content="true")

  let select_stmt = @morm.select_from("roundtrip_test")
    .where_eq("id", 7)
    .to_statement()
  let (select_sql, select_params) = engine.render(select_stmt)
  let result = engine.exec_raw(select_sql, select_params)
  inspect(result.ok, content="true")
  inspect(result.rows.length(), content="1")
  json_inspect(result.rows[0], content={ "id": 7, "name": "Eve", "age": 25 })

  engine.close()
}

///|
async test "mongodb cursor getMore" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(@engine.exec_query(engine, @morm.delete_from("cursor_test")))

  let mut i = 0
  while i < 130 {
    let res = @engine.exec_query(
      engine,
      @morm.insert_into("cursor_test")
      .columns(["id", "name"])
      .values([@engine.Int(i), @engine.String("u" + i.to_string())]),
    )
    assert_true(res.ok)
    i = i + 1
  }

  let result = @engine.exec_query(
    engine,
    @morm.select_from("cursor_test").order_by(Asc("id")),
  )
  inspect(result.ok, content="true")
  inspect(result.rows.length(), content="130")
  json_inspect(result.rows[0], content={ "id": 0, "name": "u0" })
  json_inspect(result.rows[129], content={ "id": 129, "name": "u129" })

  engine.close()
}

///|
async test "mongodb client helpers" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  let clear = engine.run_command_json({
    "delete": "client_api_test",
    "deletes": [{ "q": {}, "limit": 0 }],
  })
  assert_true(clear is Ok(_))

  let ins = engine.insert_one("client_api_test", {
    "id": 1,
    "name": "doc",
    "tags": ["a", "b"],
  })
  assert_true(ins is Ok(_))
  let many = engine.insert_many("client_api_test", [
    { "id": 2, "name": "bulk" },
    { "id": 3, "name": "bulk" },
  ])
  assert_true(many is Ok(_))

  let one = match engine.find_one("client_api_test", { "id": 1 }) {
    Ok(Some(doc)) => doc
    _ => panic()
  }
  inspect(
    one is { "_id": _, "id": 1, "name": "doc", "tags": ["a", "b"], .. },
    content="true",
  )

  let upd = engine.update_one("client_api_test", { "id": 1 }, {
    "$set": { "name": "renamed" },
  })
  assert_true(upd is Ok(_))

  let rows = match
    engine.find("client_api_test", {}, sort=Some({ "id": 1 }), limit=Some(10)) {
    Ok(rows) => rows
    Err(_) => panic()
  }
  inspect(rows.length(), content="3")
  inspect(
    rows[0] is { "_id": _, "id": 1, "name": "renamed", .. },
    content="true",
  )

  let count = match engine.count_documents("client_api_test", filter={}) {
    Ok(n) => n
    Err(_) => panic()
  }
  inspect(count, content="3")

  let distinct = match engine.distinct("client_api_test", "name", filter={}) {
    Ok(values) => values
    Err(_) => panic()
  }
  inspect(distinct.length(), content="2")

  let modified = match
    engine.find_one_and_update("client_api_test", { "id": 1 }, {
      "$set": { "name": "final" },
    }) {
    Ok(Some(doc)) => doc
    _ => panic()
  }
  inspect(
    modified is { "_id": _, "id": 1, "name": "final", .. },
    content="true",
  )
  let replaced = engine.replace_one("client_api_test", { "id": 2 }, {
    "id": 2,
    "name": "replaced",
    "flag": true,
  })
  assert_true(replaced is Ok(_))
  let updated_many = engine.update_many("client_api_test", { "name": "bulk" }, {
    "$set": { "grouped": true },
  })
  assert_true(updated_many is Ok(_))

  let grouped = match
    engine.aggregate("client_api_test", [
      { "$match": { "id": { "$gte": 2 } } },
      { "$group": { "_id": "$grouped", "count": { "$sum": 1 } } },
      { "$sort": { "_id": 1 } },
    ]) {
    Ok(rows) => rows
    Err(_) => panic()
  }
  inspect(grouped.length(), content="2")
  inspect(grouped[0] is { "_id": Null, "count": 1, .. }, content="true")
  inspect(grouped[1] is { "_id": true, "count": 1, .. }, content="true")

  let estimated = match engine.estimated_document_count("client_api_test") {
    Ok(n) => n
    Err(_) => panic()
  }
  inspect(estimated, content="3")

  let replaced_doc = match
    engine.find_one_and_replace("client_api_test", { "id": 3 }, {
      "id": 3,
      "name": "swap",
      "kind": "replaced",
    }) {
    Ok(Some(doc)) => doc
    _ => panic()
  }
  inspect(
    replaced_doc
    is { "_id": _, "id": 3, "name": "swap", "kind": "replaced", .. },
    content="true",
  )

  let removed = match
    engine.find_one_and_delete("client_api_test", { "id": 3 }) {
    Ok(Some(doc)) => doc
    _ => panic()
  }
  inspect(
    removed is { "_id": _, "id": 3, "name": "swap", "kind": "replaced", .. },
    content="true",
  )

  let create_one = engine.create_index(
    "client_api_test",
    { "name": 1 },
    name=Some("idx_client_name"),
  )
  assert_true(create_one is Ok(_))
  let create_many = engine.create_indexes("client_api_test", [
    { "key": { "id": 1, "name": -1 }, "name": "idx_client_compound" },
  ])
  assert_true(create_many is Ok(_))

  let index_names = match engine.list_index_names("client_api_test") {
    Ok(names) => names
    Err(_) => panic()
  }
  inspect(has_string(index_names, "_id_"), content="true")
  inspect(has_string(index_names, "idx_client_name"), content="true")
  inspect(has_string(index_names, "idx_client_compound"), content="true")

  let indexes = match engine.list_indexes("client_api_test") {
    Ok(rows) => rows
    Err(_) => panic()
  }
  inspect(indexes.length() >= 3, content="true")

  let drop_one = engine.drop_index("client_api_test", "idx_client_name")
  assert_true(drop_one is Ok(_))
  let drop_all = engine.drop_indexes("client_api_test")
  assert_true(drop_all is Ok(_))
  let final_names = match engine.list_index_names("client_api_test") {
    Ok(names) => names
    Err(_) => panic()
  }
  inspect(final_names.length(), content="1")
  inspect(final_names[0], content="_id_")

  ignore(
    engine.run_command_json({
      "delete": "bulk_write_test",
      "deletes": [{ "q": {}, "limit": 0 }],
    }),
  )
  let bulk = match
    engine.bulk_write("bulk_write_test", [
      { "insertOne": { "document": { "id": 1, "name": "a" } } },
      { "insertOne": { "document": { "id": 2, "name": "b" } } },
      { "updateMany": { "filter": {}, "update": { "$set": { "bulk": true } } } },
      {
        "replaceOne": {
          "filter": { "id": 1 },
          "replacement": { "id": 1, "name": "x" },
        },
      },
      { "deleteOne": { "filter": { "id": 2 } } },
    ]) {
    Ok(replies) => replies
    Err(_) => panic()
  }
  inspect(bulk.length(), content="5")
  let bulk_rows = match engine.find("bulk_write_test", {}, limit=Some(10)) {
    Ok(rows) => rows
    Err(_) => panic()
  }
  inspect(bulk_rows.length(), content="1")
  inspect(bulk_rows[0] is { "id": 1, "name": "x", .. }, content="true")

  let bulk_unordered = match
    engine.bulk_write(
      "bulk_write_test",
      [
        { "insertOne": { "document": { "id": 10 } } },
        { "unknown": {} },
        { "insertOne": { "document": { "id": 11 } } },
      ],
      ordered=false,
    ) {
    Ok(replies) => replies
    Err(_) => panic()
  }
  inspect(bulk_unordered.length(), content="3")
  let bulk_count = match
    engine.count_documents("bulk_write_test", filter={ "id": { "$gte": 10 } }) {
    Ok(n) => n
    Err(_) => panic()
  }
  inspect(bulk_count, content="2")

  let del = engine.delete_one("client_api_test", { "id": 1 })
  assert_true(del is Ok(_))
  let del_many = engine.delete_many("client_api_test", { "id": { "$gte": 2 } })
  assert_true(del_many is Ok(_))
  inspect(
    match engine.find("client_api_test", {}, limit=Some(10)) {
      Ok(rows) => rows.length()
      Err(_) => -1
    },
    content="0",
  )

  let dropped = engine.drop("client_api_test")
  assert_true(dropped is Ok(_))

  engine.close()
}

///|
async test "mongodb dsn srv and failover seeds" {
  let failover = match
    @mongodb.MongoDBEngine::open(
      "mongodb://127.0.0.1:27099,127.0.0.1:27017/morm_test",
    ) {
    Ok(e) => e
    Err(_) => panic()
  }
  let ping1 = failover.run_command_json({ "ping": 1 })
  assert_true(ping1 is Ok(_))
  failover.close()

  let srv = match
    @mongodb.MongoDBEngine::open("mongodb+srv://127.0.0.1/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }
  let ping2 = srv.run_command_json({ "ping": 1 })
  assert_true(ping2 is Ok(_))
  srv.close()
}

///|
async test "mongodb search index helpers" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(
    engine.run_command_json({
      "delete": "search_test",
      "deletes": [{ "q": {}, "limit": 0 }],
    }),
  )
  ignore(
    engine.insert_one("search_test", {
      "title": "hello mongodb",
      "body": "search index smoke test",
    }),
  )

  let create = engine.create_search_index("search_test", "idx_search_text", {
    "mappings": {
      "dynamic": false,
      "fields": { "title": { "type": "string" }, "body": { "type": "string" } },
    },
  })
  match create {
    Ok(_) => {
      let listed = match
        engine.list_search_indexes("search_test", name=Some("idx_search_text")) {
        Ok(rows) => rows
        Err(_) => panic()
      }
      inspect(listed.length() >= 1, content="true")
      let upd = engine.update_search_index("search_test", "idx_search_text", {
        "mappings": { "dynamic": true },
      })
      assert_true(upd is Ok(_))
      let drop = engine.drop_search_index("search_test", "idx_search_text")
      assert_true(drop is Ok(_))
    }
    Err(err) => inspect(is_search_index_unsupported(err), content="true")
  }

  engine.close()
}
