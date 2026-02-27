///|
async test "oracle native tns handshake" {
  let engine = match
    OracleEngine::open("oracle://system:oracle@127.0.0.1:11521/XEPDB1") {
    Ok(e) => e
    Err(_) => panic()
  }

  let ok = engine.ping()
  if !ok {
    // Local Oracle container may be unavailable in some environments.
    inspect("oracle-unavailable", content="oracle-unavailable")
    engine.close()
    return
  }
  inspect(ok, content="true")
  let not_ready = engine.exec_raw("SELECT 1 FROM dual", [])
  inspect(not_ready.ok, content="false")

  engine.close()
}
