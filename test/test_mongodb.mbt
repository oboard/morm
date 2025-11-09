///|
test "mongo-find-eq" {
  let cmd = @morm.select_from("students").where_eq("id", 1).to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"find": "students", "filter": {"id": 1}}
    ),
  )
}

///|
test "mongo-find-comparison" {
  let cmd = @morm.select_from("students")
    .where_gt("age", 18)
    .where_lte("score", 100)
    .to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"find": "students", "filter": {"age": {"$gt": 18}, "score": {"$lte": 100}}}
    ),
  )
}

///|
test "mongo-find-sort-limit-skip" {
  let cmd = @morm.select_from("students")
    .order_by(Asc("name"))
    .order_by(Desc("id"))
    .limit(10)
    .offset(20)
    .to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"find": "students", "filter": {}, "sort": {"name": 1, "id": -1}, "limit": 10, "skip": 20}
    ),
  )
}

///|
test "mongo-insert-basic" {
  let cmd = @morm.insert_into("students")
    .columns(["id", "name", "age", "active"])
    .values([1, "Alice", 20, true])
    .to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"insert": "students", "documents": [{"id": 1, "name": "Alice", "age": 20, "active": true}]}
    ),
  )
}

///|
test "mongo-update-set" {
  let cmd = @morm.update("students")
    .set("name", "Bob")
    .set("active", true)
    .where_eq("id", 1)
    .to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"update": "students", "updates": [{"q": {"id": 1}, "u": {"$set": {"name": "Bob", "active": true}}}]}
    ),
  )
}

///|
test "mongo-delete-basic" {
  let cmd = @morm.delete_from("students").where_eq("id", 1).to(MongoDB)
  inspect(
    cmd,
    content=(
      #|{"delete": "students", "deletes": [{"q": {"id": 1}, "limit": 0}]}
    ),
  )
}
