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

  must_ok(
    engine.exec_raw(
      "CREATE TABLE post (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, published INTEGER NOT NULL DEFAULT 0)",
      [],
    ),
    "create table post",
  )

  must_ok(
    engine.exec_raw(
      "INSERT INTO post(title, published) VALUES (?, ?), (?, ?), (?, ?)",
      [
        String("Hello"),
        Bool(true),
        String("Draft"),
        Bool(false),
        String("Release"),
        Bool(true),
      ],
    ),
    "insert posts",
  )

  // Raw SQL with bound params.
  let q = engine.exec_raw(
    "SELECT id, title, published FROM post WHERE published = ? AND title LIKE ? ORDER BY id DESC",
    [Bool(true), String("%e%")],
  )
  must_ok(q, "query published posts")

  println("exec_raw: matched_rows=\{q.rows.length()}")
  for row in q.rows {
    println(row.stringify())
  }

  engine.close()
}
