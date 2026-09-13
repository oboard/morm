///|
async fn main {
  let engine = @sqlite3.SQLiteEngine::open(":memory:")

  // Use codegen table schema from `user.g.mbt`.
  let migrate_ok = engine.migrate_table(User::table()).ok
  if !migrate_ok {
    println("migrate user table failed")
    return
  }

  // Mapper implementation is generated in `user_mapper.g.mbt`.
  let mapper = UserMapperImpl(engine)

  // C: save
  let created = mapper.save({ id: 1, email: "alice@example.com", active: 1, })
  if !created {
    println("save user failed")
    return
  }
  println("curd: created=true")

  // R: find by id
  if mapper.find_user_by_id(1) is Some(user) {
    println("curd: read=\{ToJson::to_json(user).stringify()}")
  } else {
    println("curd: read=null")
  }

  // U: update
  let updated = mapper.update({ id: 1, email: "alice@example.com", active: 0, })
  if !updated {
    println("update user failed")
    return
  }
  println("curd: updated=true")

  if mapper.find_user_by_id(1) is Some(user) {
    println("curd: after_update=\{ToJson::to_json(user).stringify()}")
  }

  // U: update_[field]_by_[where]
  let updated_by_name = mapper.update_active_by_id(1, 1)
  if !updated_by_name {
    println("update_active_by_id failed")
    return
  }
  if mapper.find_user_by_id(1) is Some(user) {
    println("curd: after_update_by=\{ToJson::to_json(user).stringify()}")
  }

  // D: delete
  let deleted = mapper.delete({ id: 1, email: "alice@example.com", active: 1, })
  if !deleted {
    println("delete user failed")
    return
  }
  println("curd: deleted=true")

  // Re-create and delete by naming-convention method
  let recreated = mapper.save({ id: 2, email: "bob@example.com", active: 1, })
  if !recreated {
    println("save bob failed")
    return
  }
  let deleted_by_name = mapper.delete_by_id(2)
  if !deleted_by_name {
    println("delete_by_id failed")
    return
  }
  println("curd: deleted_by_id=true")

  let final_user = mapper.find_user_by_id(1)
  println("curd: final=\{@json.to_json(final_user).stringify()}")

  engine.close()
}
