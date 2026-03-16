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
  let migrate_res = engine.migrate_table(user_table)
  if !migrate_res.ok {
    println("migrate user table failed")
    return
  }

  // Query Builder INSERT.
  let insert_alice = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values([String("alice@example.com"), String("Alice"), Int(1)])
  let insert_bob = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values([String("bob@example.com"), String("Bob"), Int(0)])
  let insert_alice_res = @engine.exec_query(engine, insert_alice)
  if !insert_alice_res.ok {
    println("insert alice failed")
    return
  }
  let insert_bob_res = @engine.exec_query(engine, insert_bob)
  if !insert_bob_res.ok {
    println("insert bob failed")
    return
  }

  // Query Builder SELECT.
  let select_active = @morm.select_from("user")
    .where_eq("active", 1)
    .order_by(Asc("id"))
  let active_res = @engine.exec_query(engine, select_active)
  if !active_res.ok {
    println("select active users failed")
    return
  }
  println("basic: active_rows=\{active_res.rows.length()}")
  for row in active_res.rows {
    println(row.stringify())
  }

  // Query Builder UPDATE.
  let update_bob = @morm.update("user")
    .set("active", 1)
    .where_eq("email", "bob@example.com")
  let update_bob_res = @engine.exec_query(engine, update_bob)
  if !update_bob_res.ok {
    println("update bob active failed")
    return
  }

  // Query Builder DELETE.
  let delete_alice = @morm.delete_from("user").where_eq(
    "email", "alice@example.com",
  )
  let delete_alice_res = @engine.exec_query(engine, delete_alice)
  if !delete_alice_res.ok {
    println("delete alice failed")
    return
  }

  // Final state.
  let final_res = @engine.exec_query(
    engine,
    @morm.select_from("user").order_by(Asc("id")),
  )
  if !final_res.ok {
    println("final select failed")
    return
  }
  println("basic: final_rows=\{final_res.rows.length()}")
  for row in final_res.rows {
    println(row.stringify())
  }

  engine.close()
}
