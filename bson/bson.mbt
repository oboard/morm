///|
pub(all) suberror BsonError {
  BsonError(String)
} derive(Eq, ToJson)

///|
pub impl Show for BsonError with output(self : BsonError, logger : &Logger) {
  logger.write_string(self.to_json().stringify())
}

///|
fn[T] error(msg : String) -> T raise BsonError {
  raise BsonError(msg)
}

///|
fn write_cstring(buf : @buffer.Buffer, text : String) -> Unit {
  buf.write_string_utf8(text)
  buf.write_byte(0)
}

///|
fn write_string(buf : @buffer.Buffer, text : String) -> Unit {
  let bytes = @utf8.encode(text)
  buf.write_int_le(bytes.length() + 1)
  buf.write_bytes(bytes)
  buf.write_byte(0)
}

///|
fn write_value(buf : @buffer.Buffer, key : String, value : Json) -> Unit {
  match value {
    Null => {
      buf.write_byte(0x0A)
      write_cstring(buf, key)
    }
    True => {
      buf.write_byte(0x08)
      write_cstring(buf, key)
      buf.write_byte(1)
    }
    False => {
      buf.write_byte(0x08)
      write_cstring(buf, key)
      buf.write_byte(0)
    }
    String(text) => {
      buf.write_byte(0x02)
      write_cstring(buf, key)
      write_string(buf, text)
    }
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        buf.write_byte(0x10)
        write_cstring(buf, key)
        buf.write_int_le(n.to_int())
      } else {
        buf.write_byte(0x01)
        write_cstring(buf, key)
        buf.write_double_le(n)
      }
    Array(items) => {
      buf.write_byte(0x04)
      write_cstring(buf, key)
      buf.write_bytes(encode_array(items))
    }
    Object(obj) => {
      buf.write_byte(0x03)
      write_cstring(buf, key)
      buf.write_bytes(encode_object(obj))
    }
  }
}

///|
fn encode_entries(entries : Iter[(String, Json)]) -> Bytes {
  let body = @buffer.new()
  for entry in entries {
    let (key, value) = entry
    write_value(body, key, value)
  }
  body.write_byte(0)
  let out = @buffer.new()
  out.write_int_le(body.length() + 4)
  out.write_bytes(body.to_bytes())
  out.to_bytes()
}

///|
fn encode_object(obj : Map[String, Json]) -> Bytes {
  encode_entries(obj.map((k, v) => (k, v)).values())
}

///|
fn encode_array(items : Array[Json]) -> Bytes {
  let entries : Array[(String, Json)] = []
  let mut i = 0
  for item in items {
    entries.push(("\{i}", item))
    i = i + 1
  }
  encode_entries(entries.iter())
}

///|
pub fn to_bytes(value : Json) -> Bytes {
  encode_entries([("__morm_root", value)].iter())
}

///|
pub fn to_document_bytes(value : Json) -> Bytes raise BsonError {
  match value {
    Object(obj) => encode_object(obj)
    _ => error("root value must be an object")
  }
}

///|
pub fn json_bytes_to_bytes(value : Json) -> Bytes? {
  match value {
    Array(items) => {
      let out = @buffer.new(size_hint=items.length())
      for item in items {
        match item {
          Number(n, ..) if n.to_int().to_double() == n => {
            let byte = n.to_int()
            guard byte >= 0 && byte <= 255 else { return None }
            out.write_byte(byte.to_byte())
          }
          _ => return None
        }
      }
      Some(out.to_bytes())
    }
    _ => None
  }
}

///|
fn read_cstring(data : Bytes, offset : Int) -> (String, Int) raise BsonError {
  let mut i = offset
  while i < data.length() && data[i] != 0 {
    i = i + 1
  }
  guard i < data.length() else { return error("unterminated cstring") }
  (@utf8.decode_lossy(data[offset:i].to_bytes()), i + 1)
}

///|
fn read_i32(data : Bytes, offset : Int) -> Int raise BsonError {
  guard offset >= 0 && offset + 4 <= data.length() else {
    return error("short i32")
  }
  match data[offset:offset + 4] {
    [i32le(v)] => v
    _ => error("bad i32")
  }
}

///|
fn read_i64(data : Bytes, offset : Int) -> Int64 raise BsonError {
  guard offset >= 0 && offset + 8 <= data.length() else {
    return error("short i64")
  }
  match data[offset:offset + 8] {
    [i64le(v)] => v
    _ => error("bad i64")
  }
}

///|
fn bytes_hex(data : Bytes) -> String {
  let out = @buffer.new()
  for byte in data {
    let hi = byte.to_int() / 16
    let lo = byte.to_int() % 16
    let digit = fn(v : Int) -> Char {
      if v < 10 {
        (48 + v).unsafe_to_char()
      } else {
        (87 + v).unsafe_to_char()
      }
    }
    out.write_char(digit(hi))
    out.write_char(digit(lo))
  }
  out.to_string()
}

///|
fn decode_value(
  data : Bytes,
  tag : Int,
  offset : Int,
) -> (Json, Int) raise BsonError {
  match tag {
    0x01 => {
      guard offset >= 0 && offset + 8 <= data.length() else {
        return error("short double")
      }
      match data[offset:offset + 8] {
        [u64le(bits)] =>
          (Json::number(bits.reinterpret_as_double()), offset + 8)
        _ => error("bad double")
      }
    }
    0x02 => {
      let len = read_i32(data, offset)
      guard len > 0 && offset + 4 + len <= data.length() else {
        return error("bad string length")
      }
      let start = offset + 4
      let end = start + len - 1
      guard data[end] == 0 else {
        return error("string is not null-terminated")
      }
      (
        Json::string(@utf8.decode_lossy(data[start:end].to_bytes())),
        start + len,
      )
    }
    0x03 => decode_document(data, offset, false)
    0x04 => decode_document(data, offset, true)
    0x05 => {
      let len = read_i32(data, offset)
      guard len >= 0 && offset + 5 + len <= data.length() else {
        return error("bad binary length")
      }
      (data[offset + 5:offset + 5 + len].to_bytes().to_json(), offset + 5 + len)
    }
    0x07 => {
      guard offset >= 0 && offset + 12 <= data.length() else {
        return error("short objectid")
      }
      (
        Json::string(bytes_hex(data[offset:offset + 12].to_bytes())),
        offset + 12,
      )
    }
    0x08 => {
      guard offset < data.length() else { return error("short bool") }
      (Json::boolean(data[offset] != 0), offset + 1)
    }
    0x09 => {
      let v = read_i64(data, offset)
      (v.to_json(), offset + 8)
    }
    0x0A => (Json::null(), offset)
    0x0B => {
      let (pattern, next) = read_cstring(data, offset)
      let (options, after) = read_cstring(data, next)
      (Json::string("/" + pattern + "/" + options), after)
    }
    0x0D => {
      let len = read_i32(data, offset)
      guard len > 0 && offset + 4 + len <= data.length() else {
        return error("bad js length")
      }
      let start = offset + 4
      let end = start + len - 1
      guard data[end] == 0 else {
        return error("javascript is not null-terminated")
      }
      (
        Json::string(@utf8.decode_lossy(data[start:end].to_bytes())),
        start + len,
      )
    }
    0x10 => {
      let v = read_i32(data, offset)
      (Json::number(v.to_double()), offset + 4)
    }
    0x11 => {
      let v = read_i64(data, offset)
      (v.to_json(), offset + 8)
    }
    0x12 => {
      let v = read_i64(data, offset)
      (v.to_json(), offset + 8)
    }
    0x13 => {
      guard offset >= 0 && offset + 16 <= data.length() else {
        return error("short decimal128")
      }
      (
        Json::string(bytes_hex(data[offset:offset + 16].to_bytes())),
        offset + 16,
      )
    }
    0x7F => (Json::null(), offset)
    0xFF => (Json::null(), offset)
    _ => error("unsupported tag \{tag}")
  }
}

///|
fn decode_document(
  data : Bytes,
  offset : Int,
  as_array : Bool,
) -> (Json, Int) raise BsonError {
  let len = read_i32(data, offset)
  guard len >= 5 && offset + len <= data.length() else {
    return error("bad document length")
  }
  let end = offset + len
  let mut pos = offset + 4
  let obj : Map[String, Json] = {}
  let arr : Array[Json] = []
  while pos < end - 1 {
    let tag = data[pos].to_int()
    pos = pos + 1
    let (key, next_pos) = read_cstring(data, pos)
    let (value, after_value) = decode_value(data, tag, next_pos)
    pos = after_value
    if as_array {
      ignore(key)
      arr.push(value)
    } else {
      obj[key] = value
    }
  }
  guard data[end - 1] == 0 else {
    return error("document is not null-terminated")
  }
  if as_array {
    (arr.to_json(), end)
  } else {
    (obj.to_json(), end)
  }
}

///|
pub fn from_bytes(data : Bytes) -> Json raise BsonError {
  let (root, next_pos) = decode_document(data, 0, false)
  guard next_pos == data.length() else { return error("trailing bytes") }
  match root {
    Object(obj) =>
      match obj.get("__morm_root") {
        Some(value) => {
          let mut count = 0
          for _ in obj.values() {
            count = count + 1
          }
          guard count == 1 else { return error("missing root wrapper") }
          value
        }
        None => error("missing root wrapper")
      }
    _ => error("root is not an object")
  }
}

///|
pub fn from_document_bytes(data : Bytes) -> Json raise BsonError {
  let (root, next_pos) = decode_document(data, 0, false)
  guard next_pos == data.length() else { return error("trailing bytes") }
  root
}
