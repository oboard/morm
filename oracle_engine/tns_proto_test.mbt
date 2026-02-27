///|
test "tns connect packet basic" {
  let p = build_tns_connect_packet(
    "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=127.0.0.1)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=XEPDB1)))",
    0x2000, 0x2000, 317, 300,
  )
  inspect(p.length() >= 70, content="true")
  inspect(p[4].to_int(), content="1")
}
