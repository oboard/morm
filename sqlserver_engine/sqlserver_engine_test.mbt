///|
async test "sqlserver real connection with transaction batch" {
  let engine = match
    SQLServerEngine::open(
      "sqlserver://sa:YourStrong!Passw0rd@127.0.0.1:11433/tempdb",
    ) {
    Ok(e) => e
    Err(_) => panic()
  }

  let ping_res = engine.exec_raw("BEGIN TRAN; ROLLBACK", [])
  inspect(ping_res.ok, content="true")

  ignore(engine.exec_raw("DROP TABLE IF EXISTS morm_engine_test", []))
  let create_res = engine.exec_raw(
    "CREATE TABLE morm_engine_test (id INT PRIMARY KEY, name NVARCHAR(64), age INT)",
    [],
  )
  inspect(create_res.ok, content="true")

  let batch_sql =
    #|BEGIN TRAN
    #|GO
    #|INSERT INTO morm_engine_test (id, name, age) VALUES (1, 'Alice', 20)
    #|GO
    #|INSERT INTO morm_engine_test (id, name, age) VALUES (2, 'Bob', 21)
    #|GO
    #|COMMIT
  let batch_res = engine.exec_raw(batch_sql, [])
  inspect(batch_res.ok, content="true")

  engine.close()
}

///|
async test "sqlserver sql execution coverage" {
  let engine = match
    SQLServerEngine::open(
      "sqlserver://sa:YourStrong!Passw0rd@127.0.0.1:11433/tempdb",
    ) {
    Ok(e) => e
    Err(_) => panic()
  }

  ignore(engine.exec_raw("DROP TABLE IF EXISTS morm_engine_tx_test", []))
  inspect(
    engine.exec_raw(
      "CREATE TABLE morm_engine_tx_test (id INT PRIMARY KEY, name NVARCHAR(64), score FLOAT, active BIT)",
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
  inspect(
    engine.exec_raw("DELETE FROM morm_engine_tx_test WHERE id = ?", [
      @engine.Int(2),
    ]).ok,
    content="true",
  )
  let batch_sql =
    #|BEGIN TRAN
    #|GO
    #|INSERT INTO morm_engine_tx_test (id, name, score, active) VALUES (4, 'D', 40.5, 1)
    #|GO
    #|DELETE FROM morm_engine_tx_test WHERE id = 4
    #|GO
    #|COMMIT
  inspect(engine.exec_raw(batch_sql, []).ok, content="true")

  let bad_sql = engine.exec_raw("SELECT FROM", [])
  inspect(bad_sql.ok, content="false")

  engine.close()
}
