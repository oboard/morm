///|
test "sqlite datatype constants" {
  assert_eq(SQLITE_INTEGER, 1)
  assert_eq(SQLITE_FLOAT, 2)
  assert_eq(SQLITE_TEXT, 3)
  assert_eq(SQLITE_BLOB, 4)
  assert_eq(SQLITE_NULL, 5)
}

///|
test "sqlite storage classes roundtrip" {
  let conn = try! Connection::open(":memory:")
  let create_stmt = try! conn.prepare(
    "CREATE TABLE t(i INTEGER, r REAL, t TEXT, b BLOB, n TEXT, bo INTEGER)",
  )
  try! create_stmt.step_once()
  try! create_stmt.finalize()

  let insert_stmt = try! conn.prepare("INSERT INTO t VALUES (?, ?, ?, ?, ?, ?)")
  try! insert_stmt.bind(index=0, val=42)
  try! insert_stmt.bind(index=1, val=3.14)
  try! insert_stmt.bind(index=2, val="hello")
  try! insert_stmt.bind(index=3, val=@encoding/utf8.encode("xyz"))
  try! insert_stmt.bind_null(index=4)
  try! insert_stmt.bind(index=5, val=true)
  try! insert_stmt.step_once()
  try! insert_stmt.finalize()

  let query_stmt = try! conn.prepare("SELECT i, r, t, b, n, bo FROM t")
  assert_eq(try! query_stmt.step(), true)

  assert_eq(query_stmt.column_type(index=0), SQLITE_INTEGER)
  assert_eq(query_stmt.column_type(index=1), SQLITE_FLOAT)
  assert_eq(query_stmt.column_type(index=2), SQLITE_TEXT)
  assert_eq(query_stmt.column_type(index=3), SQLITE_BLOB)
  assert_eq(query_stmt.column_type(index=4), SQLITE_NULL)
  assert_eq(query_stmt.column_type(index=5), SQLITE_INTEGER)

  let i : Int = query_stmt.column(index=0)
  let r : Double = query_stmt.column(index=1)
  let t : String = query_stmt.column(index=2)
  let b : Bytes = query_stmt.column(index=3)
  let bo : Int = query_stmt.column(index=5)

  assert_eq(i, 42)
  assert_true(r > 3.139 && r < 3.141)
  assert_eq(t, "hello")
  assert_eq(b, @encoding/utf8.encode("xyz"))
  assert_eq(bo, 1)

  try! query_stmt.finalize()
  try! conn.close()
}

///|
test "sqlite value json and param conversion" {
  let v = SQLiteValue::Text("alice")
  assert_eq(v.to_json().stringify(), "\"alice\"")

  let parsed : SQLiteValue = try! @json.from_json(@json.parse("123"))
  match parsed {
    SQLiteValue::Integer(i) => assert_eq(i, 123)
    _ => panic()
  }

  let p = @engine.to_param(SQLiteValue::Real(2.5))
  assert_eq(p.to_json().stringify(), "2.5")
}
