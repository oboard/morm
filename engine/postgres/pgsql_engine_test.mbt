///|
async test "pgsql real connection" {
  let engine = match
    PgSQLEngine::open("postgres://postgres@127.0.0.1:15432/morm_test") {
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
async test "pgsql sql execution coverage" {
  let engine = match
    PgSQLEngine::open("postgres://postgres@127.0.0.1:15432/morm_test") {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec_raw("DROP TABLE IF EXISTS morm_engine_tx_test", []))
  inspect(
    engine.exec_raw(
      "CREATE TABLE morm_engine_tx_test (id INT PRIMARY KEY, name VARCHAR(64), score DOUBLE PRECISION, active BOOLEAN)",
      [],
    ).ok,
    content="true",
  )

  inspect(
    engine.exec_raw(
      "INSERT INTO morm_engine_tx_test (id, name, score, active) VALUES ($1, $2, $3, $4)",
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
      "INSERT INTO morm_engine_tx_test (id, name, score, active) VALUES ($1, $2, $3, $4)",
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
    engine.exec_raw("UPDATE morm_engine_tx_test SET score = $1 WHERE id = $2", [
      @engine.Double(88.8),
      @engine.Int(2),
    ]).ok,
    content="true",
  )
  let q = engine.exec_raw(
    "SELECT id, name, score FROM morm_engine_tx_test WHERE id = $1",
    [@engine.Int(2)],
  )
  inspect(q.ok, content="true")
  inspect(q.rows.length(), content="1")
  json_inspect(q.rows[0], content={ "id": 2, "name": "B", "score": 88.8 })

  inspect(
    engine.exec_raw("DELETE FROM morm_engine_tx_test WHERE id = $1", [
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
test "pgsql compatible dsn schemes" {
  inspect(
    PgSQLEngine::open("gaussdb://postgres@127.0.0.1:15432/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("cockroachdb://root@127.0.0.1:26257/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("opengauss://postgres@127.0.0.1:5432/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("mogdb://postgres@127.0.0.1:5432/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("kingbase://system@127.0.0.1:54321/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("kingbase8://system@127.0.0.1:54321/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("highgo://sysdba@127.0.0.1:5866/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("vastbase://postgres@127.0.0.1:5432/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("ivorysql://postgres@127.0.0.1:5432/test") is Ok(_),
    content="true",
  )
  inspect(
    PgSQLEngine::open("jdbc:postgresql://postgres@127.0.0.1:5432/test") is Ok(_),
    content="true",
  )
}
