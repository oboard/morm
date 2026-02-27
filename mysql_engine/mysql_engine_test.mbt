///|
async test "mysql real connection" {
  let engine = match
    MySQLEngine::open("mysql://root:123456@127.0.0.1:13306/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  let ping_res = engine.exec_raw("SELECT 1 AS x", [])
  inspect(ping_res.ok, content="true")

  let _ = engine.exec_raw("DROP TABLE IF EXISTS morm_engine_test", [])
  let create_res = engine.exec_raw(
    "CREATE TABLE IF NOT EXISTS morm_engine_test (id INT PRIMARY KEY, name VARCHAR(64), age INT)",
    [],
  )
  inspect(create_res.ok, content="true")

  let ins1 = engine.exec_raw(
    "INSERT INTO morm_engine_test (id, name, age) VALUES (1, 'Alice', 20)",
    [],
  )
  inspect(ins1.ok, content="true")

  let ins2 = engine.exec_raw(
    "INSERT INTO morm_engine_test (id, name, age) VALUES (2, 'Bob', 21)",
    [],
  )
  inspect(ins2.ok, content="true")

  let query_res = engine.exec_raw(
    "SELECT id, name, age FROM morm_engine_test ORDER BY id",
    [],
  )
  inspect(query_res.ok, content="true")
  inspect(query_res.rows.length(), content="2")
  json_inspect(query_res.rows[0], content={
    "id": 1,
    "name": "Alice",
    "age": 20,
  })
  json_inspect(query_res.rows[1], content={ "id": 2, "name": "Bob", "age": 21 })

  engine.close()
}

///|
test "mysql compatible dsn schemes" {
  inspect(
    MySQLEngine::open("mariadb://root@127.0.0.1:3306/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("tidb://root@127.0.0.1:4000/test") is Ok(_),
    content="true",
  )
}
