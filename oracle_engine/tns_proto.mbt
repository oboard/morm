///|
// Oracle Net packet type values translated from go-ora/network/packets.go
pub(all) enum TNSPacketType {
  Connect
  Accept
  Ack
  Refuse
  Redirect
  Data
  NullPacket
  Abort
  Resend
  Marker
  Attn
  Ctrl
}

///|
fn tns_packet_type_code(t : TNSPacketType) -> Int {
  match t {
    Connect => 1
    Accept => 2
    Ack => 3
    Refuse => 4
    Redirect => 5
    Data => 6
    NullPacket => 7
    Abort => 9
    Resend => 11
    Marker => 12
    Attn => 13
    Ctrl => 14
  }
}

///|
// Build a CONNECT packet following go-ora/newConnectPacket + ConnectPacket::bytes.
pub fn build_tns_connect_packet(
  connect_data : String,
  sdu : Int,
  tdu : Int,
  version : Int,
  lo_version : Int,
) -> Bytes {
  let data = @utf8.encode(connect_data)
  let use_inline = data.length() <= 230
  let header_len = 70
  let total_len = if use_inline {
    header_len + data.length()
  } else {
    header_len
  }

  let b = @buffer.new()
  b.write_uint16_be(total_len.reinterpret_as_uint().to_uint16())
  b.write_uint16_be(0) // packet checksum (unused)
  b.write_byte(tns_packet_type_code(Connect).to_byte())
  b.write_byte(0) // flag
  b.write_uint16_be(0)

  b.write_uint16_be(version.reinterpret_as_uint().to_uint16())
  b.write_uint16_be(lo_version.reinterpret_as_uint().to_uint16())
  b.write_uint16_be(0)

  let short_sdu = if sdu > 0xFFFF { 0xFFFF } else { sdu }
  let short_tdu = if tdu > 0xFFFF { 0xFFFF } else { tdu }
  b.write_uint16_be(short_sdu.reinterpret_as_uint().to_uint16())
  b.write_uint16_be(short_tdu.reinterpret_as_uint().to_uint16())

  b.write_byte(79)
  b.write_byte(152)
  b.write_uint16_be(0)
  b.write_uint16_be(1)
  b.write_uint16_be(data.length().reinterpret_as_uint().to_uint16())
  b.write_uint16_be(header_len.reinterpret_as_uint().to_uint16())

  // pad to offset 32
  while b.length() < 32 {
    b.write_byte(0)
  }
  b.write_byte(1)
  b.write_byte(1)

  // pad to offset 58
  while b.length() < 58 {
    b.write_byte(0)
  }
  b.write_uint_be(sdu.reinterpret_as_uint())
  b.write_uint_be(tdu.reinterpret_as_uint())
  b.write_uint_be(0)

  while b.length() < header_len {
    b.write_byte(0)
  }

  if use_inline {
    b.write_bytes(data)
  }
  b.to_bytes()
}
