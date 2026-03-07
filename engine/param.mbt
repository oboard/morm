///|
pub(all) enum Param {
  Null
  Bool(Bool)
  Byte(Byte)
  Int(Int)
  Int16(Int16)
  UInt16(UInt16)
  UInt(UInt)
  UInt64(UInt64)
  Int64(Int64)
  BigInt(BigInt)
  Float(Float)
  Double(Double)
  Decimal(String)
  Date(@time.PlainDate, String?)
  Time(@time.PlainTime, String?)
  DateTime(@time.PlainDateTime, String?)
  Timestamp(@time.ZonedDateTime, String?)
  Uuid(String)
  Json(Json)
  String(String)
  Bytes(Bytes)
} derive(Show)

///|
pub(all) suberror ParamDecodeError {
  ParamDecodeError(String)
} derive(Eq, Show, ToJson)

///|
pub impl @json.FromJson for Param with from_json(json, _path) {
  match json {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Int(n.to_int())
      } else {
        Double(n)
      }
    String(s) => String(s)
    Array(_) | Object(_) => Json(json)
  }
}

///|
pub impl Eq for Param with equal(self, other) {
  match (self, other) {
    (Null, Null) => true
    (Bool(a), Bool(b)) => a == b
    (Byte(a), Byte(b)) => a == b
    (Int(a), Int(b)) => a == b
    (Int16(a), Int16(b)) => a == b
    (UInt16(a), UInt16(b)) => a == b
    (UInt(a), UInt(b)) => a == b
    (UInt64(a), UInt64(b)) => a == b
    (Int64(a), Int64(b)) => a == b
    (BigInt(a), BigInt(b)) => a == b
    (Float(a), Float(b)) => a == b
    (Double(a), Double(b)) => a == b
    (Decimal(a), Decimal(b)) => a == b
    (Date(a, af), Date(b, bf)) => a == b && af == bf
    (Time(a, af), Time(b, bf)) => a == b && af == bf
    (DateTime(a, af), DateTime(b, bf)) => a == b && af == bf
    (Timestamp(a, af), Timestamp(b, bf)) =>
      a.to_string() == b.to_string() && af == bf
    (Uuid(a), Uuid(b)) => a == b
    (Json(a), Json(b)) => a == b
    (String(a), String(b)) => a == b
    (Bytes(a), Bytes(b)) => a == b
    _ => false
  }
}

///|
fn pad_with_zeros(value : Int, width : Int) -> String {
  let mut out = value.abs().to_string()
  while out.length() < width {
    out = "0" + out
  }
  out
}

///|
fn format_year_4(year : Int) -> String {
  if year < 0 {
    "-" + pad_with_zeros(year, 4)
  } else {
    pad_with_zeros(year, 4)
  }
}

///|
fn pad_fraction_millis(nanosecond : Int) -> String {
  pad_with_zeros(nanosecond / 1_000_000, 3)
}

///|
fn pad_fraction_nanos(nanosecond : Int) -> String {
  pad_with_zeros(nanosecond, 9)
}

///|
fn apply_temporal_format(
  pattern : String,
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
  nanosecond : Int,
  offset : String,
) -> String {
  pattern
  .replace_all(old="yyyy", new=format_year_4(year))
  .replace_all(old="YYYY", new=format_year_4(year))
  .replace_all(old="MM", new=pad_with_zeros(month, 2))
  .replace_all(old="dd", new=pad_with_zeros(day, 2))
  .replace_all(old="DD", new=pad_with_zeros(day, 2))
  .replace_all(old="HH", new=pad_with_zeros(hour, 2))
  .replace_all(old="mm", new=pad_with_zeros(minute, 2))
  .replace_all(old="ss", new=pad_with_zeros(second, 2))
  .replace_all(old="SSS", new=pad_fraction_millis(nanosecond))
  .replace_all(old="nnnnnnnnn", new=pad_fraction_nanos(nanosecond))
  .replace_all(old="XXX", new=offset)
  .replace_all(old="Z", new=offset)
}

///|
pub fn format_plain_date(value : @time.PlainDate, format : String?) -> String {
  match format {
    Some(pattern) =>
      apply_temporal_format(
        pattern,
        value.year(),
        value.month(),
        value.day(),
        0,
        0,
        0,
        0,
        "",
      )
    None => value.to_string()
  }
}

///|
pub fn format_plain_time(value : @time.PlainTime, format : String?) -> String {
  match format {
    Some(pattern) =>
      apply_temporal_format(
        pattern,
        0,
        0,
        0,
        value.hour(),
        value.minute(),
        value.second(),
        value.nanosecond(),
        "",
      )
    None => value.to_string()
  }
}

///|
pub fn format_plain_date_time(
  value : @time.PlainDateTime,
  format : String?,
) -> String {
  match format {
    Some(pattern) =>
      apply_temporal_format(
        pattern,
        value.year(),
        value.month(),
        value.day(),
        value.hour(),
        value.minute(),
        value.second(),
        value.nanosecond(),
        "",
      )
    None => value.to_string()
  }
}

///|
pub fn format_zoned_date_time(
  value : @time.ZonedDateTime,
  format : String?,
) -> String {
  match format {
    Some(pattern) =>
      apply_temporal_format(
        pattern,
        value.year(),
        value.month(),
        value.day(),
        value.hour(),
        value.minute(),
        value.second(),
        value.nanosecond(),
        value.offset().to_string(),
      )
    None => value.to_string()
  }
}

///|
pub impl ToJson for Param with to_json(self) -> Json {
  match self {
    Null => Json::null()
    Bool(v) => Json::boolean(v)
    Byte(v) => Json::number(v.to_int().to_double())
    Int(v) => v.to_json()
    Int16(v) => v.to_json()
    UInt16(v) => v.to_json()
    UInt(v) => v.to_json()
    UInt64(v) => v.to_json()
    Int64(v) => v.to_json()
    BigInt(v) => v.to_json()
    Float(v) => v.to_json()
    Double(v) => v.to_json()
    Decimal(v) => Json::string(v)
    Date(v, format) => Json::string(format_plain_date(v, format))
    Time(v, format) => Json::string(format_plain_time(v, format))
    DateTime(v, format) => Json::string(format_plain_date_time(v, format))
    Timestamp(v, format) => Json::string(format_zoned_date_time(v, format))
    Uuid(v) => Json::string(v)
    Json(v) => v
    String(v) => v.to_json()
    Bytes(v) => v.to_json()
  }
}

///|
pub fn param_from_json_value(json : Json) -> Param {
  match json {
    Null => Null
    True => Bool(true)
    False => Bool(false)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Int(n.to_int())
      } else {
        Double(n)
      }
    String(s) => String(s)
    Array(_) | Object(_) => Json(json)
  }
}

///|
fn[T] param_decode_error(msg : String) -> T raise ParamDecodeError {
  raise ParamDecodeError(msg)
}

///|
pub(open) trait FromParam {
  from_param(Param) -> Self raise ParamDecodeError
}

///|
pub fn[T : FromParam] from_param(value : Param) -> T raise ParamDecodeError {
  FromParam::from_param(value)
}

///|
pub impl FromParam for Param with from_param(self) {
  self
}

///|
pub impl FromParam for Unit with from_param(value) {
  match value {
    Null => ()
    _ => param_decode_error("Unit::from_param: expected Null")
  }
}

///|
pub impl FromParam for Bool with from_param(value) {
  match value {
    Bool(v) => v
    _ => param_decode_error("Bool::from_param: expected Bool")
  }
}

///|
pub impl FromParam for Byte with from_param(value) {
  match value {
    Byte(v) => v
    Int(v) if v >= 0 && v <= 255 => v.to_byte()
    _ => param_decode_error("Byte::from_param: expected Byte-compatible value")
  }
}

///|
pub impl FromParam for Int with from_param(value) {
  match value {
    Int(v) => v
    Int16(v) => v.to_int()
    UInt16(v) => v.to_int()
    Byte(v) => v.to_int()
    _ => param_decode_error("Int::from_param: expected Int-compatible value")
  }
}

///|
pub impl FromParam for Int16 with from_param(value) {
  match value {
    Int16(v) => v
    Int(v) if v >= -32768 && v <= 32767 => Int16::from_int(v)
    _ =>
      param_decode_error("Int16::from_param: expected Int16-compatible value")
  }
}

///|
pub impl FromParam for UInt16 with from_param(value) {
  match value {
    UInt16(v) => v
    Int(v) if v >= 0 && v <= 65535 => v.to_uint16()
    _ =>
      param_decode_error("UInt16::from_param: expected UInt16-compatible value")
  }
}

///|
pub impl FromParam for UInt with from_param(value) {
  match value {
    UInt(v) => v
    UInt16(v) => v.to_uint()
    Byte(v) => v.to_uint()
    Int(v) if v >= 0 => v.reinterpret_as_uint()
    String(s) =>
      @strconv.parse_uint(s) catch {
        _ => param_decode_error("UInt::from_param: invalid UInt string")
      }
    _ => param_decode_error("UInt::from_param: expected UInt-compatible value")
  }
}

///|
pub impl FromParam for UInt64 with from_param(value) {
  match value {
    UInt64(v) => v
    UInt(v) => v.to_uint64()
    UInt16(v) => v.to_uint64()
    Byte(v) => v.to_uint64()
    Int(v) if v >= 0 => v.to_uint64()
    String(s) =>
      @strconv.parse_uint64(s) catch {
        _ => param_decode_error("UInt64::from_param: invalid UInt64 string")
      }
    _ =>
      param_decode_error("UInt64::from_param: expected UInt64-compatible value")
  }
}

///|
pub impl FromParam for Int64 with from_param(value) {
  match value {
    Int64(v) => v
    Int(v) => v.to_int64()
    Int16(v) => v.to_int64()
    UInt16(v) => v.to_int64()
    Byte(v) => v.to_int64()
    String(s) =>
      @strconv.parse_int64(s) catch {
        _ => param_decode_error("Int64::from_param: invalid Int64 string")
      }
    _ =>
      param_decode_error("Int64::from_param: expected Int64-compatible value")
  }
}

///|
pub impl FromParam for BigInt with from_param(value) {
  match value {
    BigInt(v) => v
    Int(v) => BigInt::from_int(v)
    Int64(v) => BigInt::from_int64(v)
    String(s) => BigInt::from_string(s)
    _ =>
      param_decode_error("BigInt::from_param: expected BigInt-compatible value")
  }
}

///|
pub impl FromParam for Float with from_param(value) {
  match value {
    Float(v) => v
    Double(v) => Float::from_double(v)
    Int(v) => Float::from_int(v)
    String(s) =>
      Float::from_double(@strconv.parse_double(s)) catch {
        _ => param_decode_error("Float::from_param: invalid Float string")
      }
    _ =>
      param_decode_error("Float::from_param: expected Float-compatible value")
  }
}

///|
pub impl FromParam for Double with from_param(value) {
  match value {
    Double(v) => v
    Float(v) => v.to_double()
    Int(v) => v.to_double()
    String(s) =>
      @strconv.parse_double(s) catch {
        _ => param_decode_error("Double::from_param: invalid Double string")
      }
    _ =>
      param_decode_error("Double::from_param: expected Double-compatible value")
  }
}

///|
pub impl FromParam for String with from_param(value) {
  match value {
    String(v) => v
    Decimal(v) => v
    Uuid(v) => v
    Date(v, format) => format_plain_date(v, format)
    Time(v, format) => format_plain_time(v, format)
    DateTime(v, format) => format_plain_date_time(v, format)
    Timestamp(v, format) => format_zoned_date_time(v, format)
    _ =>
      param_decode_error("String::from_param: expected String-compatible value")
  }
}

///|
pub impl FromParam for Bytes with from_param(value) {
  match value {
    Bytes(v) => v
    _ => param_decode_error("Bytes::from_param: expected Bytes")
  }
}

///|
pub impl FromParam for Json with from_param(value) {
  match value {
    Json(v) => v
    _ => value.to_json()
  }
}

///|
pub impl FromParam for @time.PlainDate with from_param(value) {
  match value {
    Date(v, _) => v
    String(v) =>
      @time.PlainDate::from_string(v) catch {
        _ => param_decode_error("PlainDate::from_param: invalid date string")
      }
    _ =>
      param_decode_error(
        "PlainDate::from_param: expected date-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.PlainTime with from_param(value) {
  match value {
    Time(v, _) => v
    String(v) =>
      @time.PlainTime::from_string(v) catch {
        _ => param_decode_error("PlainTime::from_param: invalid time string")
      }
    _ =>
      param_decode_error(
        "PlainTime::from_param: expected time-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.PlainDateTime with from_param(value) {
  match value {
    DateTime(v, _) => v
    String(v) =>
      @time.PlainDateTime::from_string(v) catch {
        _ =>
          param_decode_error(
            "PlainDateTime::from_param: invalid datetime string",
          )
      }
    _ =>
      param_decode_error(
        "PlainDateTime::from_param: expected datetime-compatible value",
      )
  }
}

///|
pub impl FromParam for @time.ZonedDateTime with from_param(value) {
  match value {
    Timestamp(v, _) => v
    String(v) =>
      @time.ZonedDateTime::from_string(v) catch {
        _ =>
          param_decode_error(
            "ZonedDateTime::from_param: invalid timestamp string",
          )
      }
    _ =>
      param_decode_error(
        "ZonedDateTime::from_param: expected timestamp-compatible value",
      )
  }
}

///|
pub impl[T : FromParam] FromParam for T? with from_param(value) {
  match value {
    Null => None
    _ => Some(try! FromParam::from_param(value))
  }
}

///|
pub(open) trait ToParam {
  to_param(Self) -> Param
}

///|
pub fn[T : ToParam] to_param(value : T) -> Param {
  value.to_param()
}

///|
pub impl ToParam for Param with to_param(self) -> Param {
  self
}

///|
pub impl ToParam for Unit with to_param(_self) -> Param {
  Null
}

///|
pub impl ToParam for Bool with to_param(self) -> Param {
  Bool(self)
}

///|
pub impl ToParam for Byte with to_param(self) -> Param {
  Byte(self)
}

///|
pub impl ToParam for Int with to_param(self) -> Param {
  Int(self)
}

///|
pub impl ToParam for Int16 with to_param(self) -> Param {
  Int16(self)
}

///|
pub impl ToParam for UInt16 with to_param(self) -> Param {
  UInt16(self)
}

///|
pub impl ToParam for UInt with to_param(self) -> Param {
  UInt(self)
}

///|
pub impl ToParam for UInt64 with to_param(self) -> Param {
  UInt64(self)
}

///|
pub impl ToParam for Int64 with to_param(self) -> Param {
  Int64(self)
}

///|
pub impl ToParam for BigInt with to_param(self) -> Param {
  BigInt(self)
}

///|
pub impl ToParam for Double with to_param(self) -> Param {
  Double(self)
}

///|
pub impl ToParam for Float with to_param(self) -> Param {
  Float(self)
}

///|
pub impl ToParam for @time.PlainDate with to_param(self) -> Param {
  Date(self, None)
}

///|
pub impl ToParam for @time.PlainTime with to_param(self) -> Param {
  Time(self, None)
}

///|
pub impl ToParam for @time.PlainDateTime with to_param(self) -> Param {
  DateTime(self, None)
}

///|
pub impl ToParam for @time.ZonedDateTime with to_param(self) -> Param {
  Timestamp(self, None)
}

///|
pub impl ToParam for String with to_param(self) -> Param {
  String(self)
}

///|
pub impl ToParam for Bytes with to_param(self) -> Param {
  Bytes(self)
}

///|
pub impl ToParam for Json with to_param(self) -> Param {
  Json(self)
}
