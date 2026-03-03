///|
pub async fn manual_verify_mongodb_auth(dsn : String) -> Bool {
  let engine = match @mongodb.MongoDBEngine::open(dsn) {
    Ok(e) => e
    Err(_) => return false
  }

  ignore(@engine.exec_query(engine, @morm.delete_from("auth_test_docs")))

  let ins = @morm.insert_into("auth_test_docs")
    .columns(["id", "name"])
    .values([@engine.Int(1), @engine.String("secure")])
  if !@engine.exec_query(engine, ins).ok {
    engine.close()
    return false
  }

  let sel = @morm.select_from("auth_test_docs").where_eq("id", 1)
  let res = @engine.exec_query(engine, sel)
  engine.close()
  res.ok && res.rows.length() == 1
}
