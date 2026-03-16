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
  let engine = @sqlite3.SQLiteEngine::open(":memory:")

  // Schema for belongs_to / has_many / many_to_many.
  must_ok(
    engine.exec_raw(
      "CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL)",
      [],
    ),
    "create user",
  )
  must_ok(
    engine.exec_raw(
      "CREATE TABLE post (id INTEGER PRIMARY KEY, author_id INTEGER NOT NULL, title TEXT NOT NULL)",
      [],
    ),
    "create post",
  )
  must_ok(
    engine.exec_raw(
      "CREATE TABLE tag (id INTEGER PRIMARY KEY, name TEXT NOT NULL)",
      [],
    ),
    "create tag",
  )
  must_ok(
    engine.exec_raw(
      "CREATE TABLE post_tag (post_id INTEGER NOT NULL, tag_id INTEGER NOT NULL)",
      [],
    ),
    "create post_tag",
  )

  // Seed data.
  must_ok(
    engine.exec_raw(
      "INSERT INTO user(id, name) VALUES (1, 'Alice'), (2, 'Bob')",
      [],
    ),
    "seed user",
  )
  must_ok(
    engine.exec_raw(
      "INSERT INTO post(id, author_id, title) VALUES (10, 1, 'A-1'), (11, 1, 'A-2'), (12, 2, 'B-1')",
      [],
    ),
    "seed post",
  )
  must_ok(
    engine.exec_raw(
      "INSERT INTO tag(id, name) VALUES (100, 'rust'), (101, 'moonbit'), (102, 'orm')",
      [],
    ),
    "seed tag",
  )
  must_ok(
    engine.exec_raw(
      "INSERT INTO post_tag(post_id, tag_id) VALUES (10, 100), (10, 102), (11, 101), (12, 100)",
      [],
    ),
    "seed post_tag",
  )

  let owner_params : FixedArray[@engine.Param] = [Int(1), Int(2)]

  let belongs_to_sql = @engine.preload_in_sql_qmark(
    "user",
    "id",
    owner_params.length(),
  )
  let user_map = @engine.preload_belongs_to_default(
    engine, belongs_to_sql, "id", owner_params,
  )
  println("preload: belongs_to keys=\{user_map.length()}")

  let has_many_sql = @engine.preload_in_sql_qmark(
    "post",
    "author_id",
    owner_params.length(),
  )
  let post_map = @engine.preload_has_many_default(
    engine, has_many_sql, "author_id", owner_params,
  )
  println("preload: has_many keys=\{post_map.length()}")

  let mtm_sql = @engine.preload_many_to_many_sql_qmark(
    "tag", "id", "post_tag", "post_id", "tag_id", 2,
  )
  let mtm_map = @engine.preload_many_to_many_default(engine, mtm_sql, [
    Int(10),
    Int(11),
  ])
  println("preload: many_to_many keys=\{mtm_map.length()}")

  engine.close()
}
