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
async test "mysql sql execution coverage" {
  let engine = match
    MySQLEngine::open("mysql://root:123456@127.0.0.1:13306/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec_raw("DROP TABLE IF EXISTS morm_engine_tx_test", []))
  inspect(
    engine.exec_raw(
      "CREATE TABLE morm_engine_tx_test (id INT PRIMARY KEY, name VARCHAR(64), score DOUBLE, active BOOLEAN)",
      [],
    ).ok,
    content="true",
  )

  inspect(
    engine.exec_raw(
      "INSERT INTO morm_engine_tx_test (id, name, score, active) VALUES (?, ?, ?, ?)",
      [
        @engine.Int(1),
        @engine.String("A"),
        @engine.Double(10.5),
        @engine.Bool(true),
      ],
    ).ok,
    content="true",
  )
  inspect(
    engine.exec_raw(
      "INSERT INTO morm_engine_tx_test (id, name, score, active) VALUES (?, ?, ?, ?)",
      [
        @engine.Int(2),
        @engine.String("B"),
        @engine.Double(20.5),
        @engine.Bool(false),
      ],
    ).ok,
    content="true",
  )

  inspect(
    engine.exec_raw("UPDATE morm_engine_tx_test SET score = ? WHERE id = ?", [
      @engine.Double(88.8),
      @engine.Int(2),
    ]).ok,
    content="true",
  )
  let q = engine.exec_raw(
    "SELECT id, name, score FROM morm_engine_tx_test WHERE id = ?",
    [@engine.Int(2)],
  )
  inspect(q.ok, content="true")
  inspect(q.rows.length(), content="1")
  json_inspect(q.rows[0], content={ "id": 2, "name": "B", "score": 88.8 })

  inspect(
    engine.exec_raw("DELETE FROM morm_engine_tx_test WHERE id = ?", [
      @engine.Int(2),
    ]).ok,
    content="true",
  )
  let after_delete = engine.exec_raw(
    "SELECT COUNT(*) AS c FROM morm_engine_tx_test",
    [],
  )
  inspect(after_delete.ok, content="true")
  json_inspect(after_delete.rows[0], content={ "c": 1 })

  let bad_sql = engine.exec_raw("SELECT * FROM morm_engine_tx_test WHERE", [])
  inspect(bad_sql.ok, content="false")

  engine.close()
}

///|
async test "mysql transaction pins one connection" {
  let engine = match
    MySQLEngine::open("mysql://root:123456@127.0.0.1:13306/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec_raw("DROP TABLE IF EXISTS morm_engine_tx_pin_test", []))
  inspect(
    engine.exec_raw(
      "CREATE TABLE morm_engine_tx_pin_test (id INT PRIMARY KEY, name VARCHAR(64))",
      [],
    ).ok,
    content="true",
  )

  inspect(engine.exec(@engine.Tx(@engine.Begin)).ok, content="true")
  inspect(
    engine.exec_raw(
      "INSERT INTO morm_engine_tx_pin_test (id, name) VALUES (1, 'A')",
      [],
    ).ok,
    content="true",
  )
  inspect(engine.exec(@engine.Tx(@engine.Rollback)).ok, content="true")
  json_inspect(
    engine.exec_raw("SELECT COUNT(*) AS c FROM morm_engine_tx_pin_test", []).rows[0],
    content={ "c": 0 },
  )

  inspect(engine.exec(@engine.Tx(@engine.Begin)).ok, content="true")
  inspect(
    engine.exec_raw(
      "INSERT INTO morm_engine_tx_pin_test (id, name) VALUES (1, 'A')",
      [],
    ).ok,
    content="true",
  )
  inspect(engine.exec(@engine.Tx(@engine.Commit)).ok, content="true")
  json_inspect(
    engine.exec_raw("SELECT COUNT(*) AS c FROM morm_engine_tx_pin_test", []).rows[0],
    content={ "c": 1 },
  )

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
  inspect(
    MySQLEngine::open("oceanbase://root@127.0.0.1:2881/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("polardb://root@127.0.0.1:3306/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("doris://root@127.0.0.1:9030/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("starrocks://root@127.0.0.1:9030/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("selectdb://root@127.0.0.1:9030/test") is Ok(_),
    content="true",
  )
  inspect(
    MySQLEngine::open("jdbc:mysql://root@127.0.0.1:3306/test") is Ok(_),
    content="true",
  )
}
