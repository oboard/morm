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
