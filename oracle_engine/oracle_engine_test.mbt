///|
async test "oracle real connection with transaction batch" {
  let engine = match
    OracleEngine::open(
      "oracle://system:oracle@morm-oracle:1521/XEPDB1",
    ) {
    Ok(e) => e
    Err(_) => panic()
  }

  let ping_res = engine.exec_raw("SELECT 1 FROM dual", [])
  inspect(ping_res.ok, content="true")

  ignore(engine.exec_raw("DROP TABLE morm_engine_test PURGE", []))
  let create_res = engine.exec_raw(
    "CREATE TABLE morm_engine_test (id NUMBER(10) PRIMARY KEY, name VARCHAR2(64), age NUMBER(10))",
    [],
  )
  inspect(create_res.ok, content="true")

  let batch_res = engine.exec_raw(
    "INSERT INTO morm_engine_test (id, name, age) VALUES (1, 'Alice', 20); INSERT INTO morm_engine_test (id, name, age) VALUES (2, 'Bob', 21); COMMIT",
    [],
  )
  inspect(batch_res.ok, content="true")

  let query_res = engine.exec_raw(
    "SELECT COUNT(*) FROM morm_engine_test",
    [],
  )
  inspect(query_res.ok, content="true")
  inspect(query_res.rows.length() > 0, content="true")

  engine.close()
}
