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
