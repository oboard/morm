///|
async fn main {
  let engine = @sqlite3.SQLiteEngine::open(":memory:")

  // Build table schema with morm API and migrate it through the engine.
  let user_table = @morm.new_table("user", columns=[
    {
      ..@morm.new_column("id", Int),
      primary_key: true,
      auto_increment: true,
      nullable: false,
    },
    { ..@morm.new_column("email", VarChar(255)), nullable: false, unique: true },
    { ..@morm.new_column("name", VarChar(255)), nullable: true },
    { ..@morm.new_column("active", Int), nullable: false },
  ])
  let migrate_res = engine.migrate_table(user_table)
  if !migrate_res.ok {
    println("migrate user table failed")
    return
  }

  // Query Builder INSERT.
  let insert_alice = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values(["alice@example.com", "Alice", 1])
  let insert_bob = @morm.insert_into("user")
    .columns(["email", "name", "active"])
    .values(["bob@example.com", "Bob", 0])
  let insert_alice_res = engine.exec(insert_alice)
  if !insert_alice_res.ok {
    println("insert alice failed")
    return
  }
  let insert_bob_res = engine.exec(insert_bob)
  if !insert_bob_res.ok {
    println("insert bob failed")
    return
  }

  // Query Builder SELECT.
  let select_active = @morm.select_from("user")
    .where_eq("active", 1)
    .order_by(Asc("id"))
  let active_res = engine.exec(select_active)
  if !active_res.ok {
    println("select active users failed")
    return
  }
  println("basic: active_rows=\{active_res.rows.length()}")
  for row in active_res.rows {
    println(row.to_json().stringify())
  }

  // Query Builder UPDATE.
  let update_bob = @morm.update("user")
    .set("active", 1)
    .where_eq("email", "bob@example.com")
  let update_bob_res = engine.exec(update_bob)
  if !update_bob_res.ok {
    println("update bob active failed")
    return
  }

  // Query Builder DELETE.
  let delete_alice = @morm.delete_from("user").where_eq(
    "email", "alice@example.com",
  )
  let delete_alice_res = engine.exec(delete_alice)
  if !delete_alice_res.ok {
    println("delete alice failed")
    return
  }

  // Final state.
  let final_res = engine.exec(@morm.select_from("user").order_by(Asc("id")))
  if !final_res.ok {
    println("final select failed")
    return
  }
  println("basic: final_rows=\{final_res.rows.length()}")
  for row in final_res.rows {
    println(row.to_json().stringify())
  }

  engine.close()
}
