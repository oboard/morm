///|
test "query-sql-pgsql" {
  let q = @morm.select_from("students")
    .where_eq("id", 1)
    .where_eq("name", "Alice")
    .order_by(Desc("id"))
    .page(2, 5)
  let (sql, params) = q.to(PgSQL)
  inspect(
    sql,
    content=(
      #|SELECT * FROM students WHERE id = $1 AND name = $2 ORDER BY id DESC LIMIT 5 OFFSET 5
    ),
  )
}

///|
test "insert-sql-pgsql" {
  let vals : FixedArray[Json] = [1, "Alice", 20, "2000-01-01"]
  let (sql, params) = @morm.insert_into("students")
    .columns(["id", "name", "age", "birth_date"])
    .values(vals)
    .to(PgSQL)
  inspect(
    sql,
    content=(
      #|INSERT INTO students (id, name, age, birth_date) VALUES ($1, $2, $3, $4)
    ),
  )
}

///|
test "update-sql-pgsql" {
  let (sql, params) = @morm.update("students")
    .set("name", "Bob")
    .set("age", 21)
    .where_eq("id", 1)
    .to(PgSQL)
  inspect(
    sql,
    content=(
      #|UPDATE students SET name = $1, age = $2 WHERE id = $3
    ),
  )
}

///|
test "delete-sql-pgsql" {
  let (sql, params) = @morm.delete_from("students").where_eq("id", 1).to(PgSQL)
  inspect(
    sql,
    content=(
      #|DELETE FROM students WHERE id = $1
    ),
  )
}
