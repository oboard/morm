///|
async fn main {
  // This table schema comes from mormgen output: `User::table()`.
  let engine = @sqlite3.SQLiteEngine::open(":memory:")
  let migrate_res = engine.migrate_table(User::table())
  if !migrate_res.ok {
    println("migrate user table failed")
    return
  }

  let seed = @morm.insert_into("user")
    .columns(["email", "active"])
    .values(["alice@example.com", 1])
  let seed2 = @morm.insert_into("user")
    .columns(["email", "active"])
    .values(["bob@example.com", 0])
  let seed3 = @morm.insert_into("user")
    .columns(["email", "active"])
    .values(["carol@example.com", 1])
  let seed_res = engine.exec(seed)
  if !seed_res.ok {
    println("seed user alice failed")
    return
  }
  let seed2_res = engine.exec(seed2)
  if !seed2_res.ok {
    println("seed user bob failed")
    return
  }
  let seed3_res = engine.exec(seed3)
  if !seed3_res.ok {
    println("seed user carol failed")
    return
  }

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

  let page = mapper.find_users_page_by_active(1, @morm.pageable(1, 1))
  println(
    "mapper: active_page total=\{page.total_elements} page=\{page.number}/\{page.total_pages}",
  )
  for user in page.content {
    println("mapper: page_user=\{user.email}")
  }

  engine.close()
}
