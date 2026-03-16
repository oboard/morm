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

  // Build table schema with morm API and migrate it through the engine.
  let user_table = @morm.new_table("user", columns=[
    {
      ..@morm.new_column("id", @morm.ColumnType::Int),
      primary_key: true,
      auto_increment: true,
      nullable: false,
    },
    {
      ..@morm.new_column("email", @morm.ColumnType::VarChar(255)),
      nullable: false,
      unique: true,
    },
    {
      ..@morm.new_column("name", @morm.ColumnType::VarChar(255)),
      nullable: true,
    },
    { ..@morm.new_column("active", @morm.ColumnType::Int), nullable: false },
  ])
  must_ok(engine.migrate_table(user_table), "migrate user table")

  // Query Builder INSERT.
  let insert_alice = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values([String("alice@example.com"), String("Alice"), Int(1)])
  let insert_bob = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values([String("bob@example.com"), String("Bob"), Int(0)])
  must_ok(@engine.exec_query(engine, insert_alice), "insert alice")
  must_ok(@engine.exec_query(engine, insert_bob), "insert bob")

  // Query Builder SELECT.
  let select_active = @morm.select_from("user")
    .where_eq("active", 1)
    .order_by(Asc("id"))
  let active_res = @engine.exec_query(engine, select_active)
  must_ok(active_res, "select active users")
  println("basic: active_rows=\{active_res.rows.length()}")
  for row in active_res.rows {
    println(row.stringify())
  }

  // Query Builder UPDATE.
  let update_bob = @morm.update("user")
    .set("active", 1)
    .where_eq("email", "bob@example.com")
  must_ok(@engine.exec_query(engine, update_bob), "update bob active")

  // Query Builder DELETE.
  let delete_alice = @morm.delete_from("user").where_eq(
    "email", "alice@example.com",
  )
  must_ok(@engine.exec_query(engine, delete_alice), "delete alice")

  // Final state.
  let final_res = @engine.exec_query(
    engine,
    @morm.select_from("user").order_by(Asc("id")),
  )
  must_ok(final_res, "final select")
  println("basic: final_rows=\{final_res.rows.length()}")
  for row in final_res.rows {
    println(row.stringify())
  }

  engine.close()
}
