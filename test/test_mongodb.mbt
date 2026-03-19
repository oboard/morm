///|
async test "mongodb basic ops" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec(@morm.delete_from("morm_engine_test")))

  let ins1 = @morm.insert_into("morm_engine_test")
    .columns(["id", "name", "age"])
    .values([@engine.Int(1), @engine.String("Alice"), @engine.Int(20)])
  inspect(engine.exec(ins1).ok, content="true")

  let ins2 = @morm.insert_into("morm_engine_test")
    .columns(["id", "name", "age"])
    .values([@engine.Int(2), @engine.String("Bob"), @engine.Int(21)])
  inspect(engine.exec(ins2).ok, content="true")

  let sel = @morm.select_from("morm_engine_test").order_by(Asc("id"))
  let res = engine.exec(sel)
  inspect(res.ok, content="true")
  inspect(res.rows.length(), content="2")
  json_inspect(res.rows[0], content={ "id": 1, "name": "Alice", "age": 20 })
  json_inspect(res.rows[1], content={ "id": 2, "name": "Bob", "age": 21 })

  let upd = @morm.update("morm_engine_test")
    .set("name", "Bobby")
    .where_eq("id", 2)
  inspect(engine.exec(upd).ok, content="true")

  let sel2 = @morm.select_from("morm_engine_test").where_eq("id", 2)
  let res2 = engine.exec(sel2)
  json_inspect(res2.rows[0], content={ "id": 2, "name": "Bobby", "age": 21 })

  let del = @morm.delete_from("morm_engine_test").where_eq("id", 1)
  inspect(engine.exec(del).ok, content="true")

  let sel3 = @morm.select_from("morm_engine_test").order_by(Asc("id"))
  let res3 = engine.exec(sel3)
  inspect(res3.rows.length(), content="1")

  engine.close()
}

///|
async test "mongodb bson bytes roundtrip" {
  let engine = match
    @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec(@morm.delete_from("bson_test")))

  let payload : Json = { "kind": "doc", "n": 3 }
  let bytes = @bson.to_bytes(payload)
  let ins = @morm.insert_into("bson_test")
    .columns(["id", "payload"])
    .values([@engine.Int(1), @engine.Bytes(bytes)])
  inspect(engine.exec(ins).ok, content="true")

  let sel = @morm.select_from("bson_test").where_eq("id", 1)
  let res = engine.exec(sel)
  json_inspect(res.rows[0], content={
    "id": 1,
    "payload": { "kind": "doc", "n": 3 },
  })

  engine.close()
}
