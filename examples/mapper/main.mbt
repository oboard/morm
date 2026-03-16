///|
fn must_ok(res : @engine.QueryResult, step : String) -> Unit {
  if !res.ok {
    let msg = match res.error {
      Some(err) => err
      None => "unknown"
    }
    println("step=\{step}, error=\{msg}")
    panic()
  }
}

///|
async fn main {
  // This table schema comes from mormgen output: `User::table()`.
  let engine = @sqlite3.SQLiteEngine::open(":memory:")
  must_ok(engine.migrate_table(User::table()), "migrate user table")

  let seed = @morm.insert_into("user")
    .columns(["email", "active"])
    .values([String("alice@example.com"), Int(1)])
  let seed2 = @morm.insert_into("user")
    .columns(["email", "active"])
    .values([String("bob@example.com"), Int(0)])
  let seed3 = @morm.insert_into("user")
    .columns(["email", "active"])
    .values([String("carol@example.com"), Int(1)])
  must_ok(@engine.exec_query(engine, seed), "seed user alice")
  must_ok(@engine.exec_query(engine, seed2), "seed user bob")
  must_ok(@engine.exec_query(engine, seed3), "seed user carol")

  // Runtime usage through generated mapper impl.
  let mapper = UserMapperImpl::new(engine)

  if mapper.find_user_by_id(1) is Some(user) {
    println("mapper: user#1 email=\{user.email}")
  } else {
    println("mapper: user#1 not found")
  }

  let active = mapper.find_users_by_active(1)
  println("mapper: active_count=\{active.length()}")
  for user in active {
    println(user.to_json().stringify())
  }

  engine.close()
}
