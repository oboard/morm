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
fn write_be16(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte(((v >> 8) & 0xff).to_byte())
  buf.write_byte((v & 0xff).to_byte())
}

///|
fn write_be32(buf : @buffer.Buffer, v : Int) -> Unit {
  buf.write_byte(((v >> 24) & 0xff).to_byte())
  buf.write_byte(((v >> 16) & 0xff).to_byte())
  buf.write_byte(((v >> 8) & 0xff).to_byte())
  buf.write_byte((v & 0xff).to_byte())
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
  write_be16(b, total_len)
  write_be16(b, 0) // packet checksum (unused)
  b.write_byte(tns_packet_type_code(Connect).to_byte())
  b.write_byte(0) // flag
  write_be16(b, 0)

  write_be16(b, version)
  write_be16(b, lo_version)
  write_be16(b, 0)

  let short_sdu = if sdu > 0xFFFF { 0xFFFF } else { sdu }
  let short_tdu = if tdu > 0xFFFF { 0xFFFF } else { tdu }
  write_be16(b, short_sdu)
  write_be16(b, short_tdu)

  b.write_byte(79)
  b.write_byte(152)
  write_be16(b, 0)
  write_be16(b, 1)
  write_be16(b, data.length())
  write_be16(b, header_len)

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
  write_be32(b, sdu)
  write_be32(b, tdu)
  write_be32(b, 0)

  while b.length() < header_len {
    b.write_byte(0)
  }

  if use_inline {
    b.write_bytes(data)
  }
  b.to_bytes()
}
