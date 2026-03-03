///|
async test "mongodb auth manual verify" {
  let engine = match
    @mongodb.MongoDBEngine::open(
      "mongodb://root:secret@127.0.0.1:27018/morm_auth_test?authSource=admin",
    ) {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(@engine.exec_query(engine, @morm.delete_from("auth_test_docs")))

  let ins = @morm.insert_into("auth_test_docs")
    .columns(["id", "name"])
    .values([@engine.Int(1), @engine.String("secure")])
  let ins_res = @engine.exec_query(engine, ins)
  inspect(ins_res.to_json())

  engine.close()
}
