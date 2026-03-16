///|
async fn main {
  let engine = @sqlite3.SQLiteEngine::open(":memory:")

  let create_res = engine.exec_raw(
    "CREATE TABLE post (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, published INTEGER NOT NULL DEFAULT 0)",
    [],
  )
  if !create_res.ok {
    println("create table post failed")
    return
  }

  let insert_res = engine.exec_raw(
    "INSERT INTO post(title, published) VALUES (?, ?), (?, ?), (?, ?)",
    [
      String("Hello"),
      Bool(true),
      String("Draft"),
      Bool(false),
      String("Release"),
      Bool(true),
    ],
  )
  if !insert_res.ok {
    println("insert posts failed")
    return
  }

  // Raw SQL with bound params.
  let q = engine.exec_raw(
    "SELECT id, title, published FROM post WHERE published = ? AND title LIKE ? ORDER BY id DESC",
    [Bool(true), String("%e%")],
  )
  if !q.ok {
    println("query published posts failed")
    return
  }

  println("exec_raw: matched_rows=\{q.rows.length()}")
  for row in q.rows {
    println(row.stringify())
  }

  engine.close()
}
