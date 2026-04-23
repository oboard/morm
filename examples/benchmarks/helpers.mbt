///|
fn bench_user(id : Int) -> BenchUser {
  {
    id,
    email: "user-\{id}@example.com",
    active: if id % 2 == 0 {
      1
    } else {
      0
    },
  }
}

///|
fn bench_post(id : Int, user_id : Int) -> BenchPost {
  {
    id,
    user_id,
    title: "post-\{id}",
    published: if id % 3 == 0 {
      0
    } else {
      1
    },
  }
}

///|
async fn seed_database(engine : @sqlite3.SQLiteEngine) -> Unit {
  ignore(engine.migrate_table(BenchUser::table()))
  ignore(engine.migrate_table(BenchPost::table()))
  let users : Array[BenchUser] = []
  for id in 1..<=120 {
    users.push(bench_user(id))
  }
  ignore(
    engine.exec(
      @morm.insert_into("bench_user").from_many(FixedArray::from_array(users)),
    ),
  )
  let posts : Array[BenchPost] = []
  for user_id in 1..<=120 {
    for n in 1..<=3 {
      let id = (user_id - 1) * 3 + n
      posts.push(bench_post(id, user_id))
    }
  }
  ignore(
    engine.exec(
      @morm.insert_into("bench_post").from_many(FixedArray::from_array(posts)),
    ),
  )
}

///|
fn setup_engine() -> @sqlite3.SQLiteEngine {
  let engine = @sqlite3.SQLiteEngine::open_quiet(":memory:")
  @async.run_async_main(async fn() { seed_database(engine) })
  engine
}
