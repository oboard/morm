///|
fn[T] json_decode_error(
  path : @json.JsonPath,
  msg : String,
) -> T raise @json.JsonDecodeError {
  raise @json.JsonDecodeError((path, msg))
}

///|
fn parse_timestamp_offset_seconds(offset : String) -> Int? {
  if offset == "Z" {
    return Some(0)
  }
  if offset.length() != 6 && offset.length() != 9 {
    return None
  }
  let sign_text = offset[:1].to_string() catch { _ => return None }
  let hour_text = offset[1:3].to_string() catch { _ => return None }
  let first_colon = offset[3:4].to_string() catch { _ => return None }
  let minute_text = offset[4:6].to_string() catch { _ => return None }
  if first_colon != ":" {
    return None
  }
  let sign = match sign_text {
    "+" => 1
    "-" => -1
    _ => return None
  }
  let hour = @strconv.parse_int(hour_text) catch { _ => return None }
  let minute = @strconv.parse_int(minute_text) catch { _ => return None }
  let second = if offset.length() == 9 {
    let second_colon = offset[6:7].to_string() catch { _ => return None }
    let second_text = offset[7:9].to_string() catch { _ => return None }
    if second_colon != ":" {
      return None
    }
    @strconv.parse_int(second_text) catch {
      _ => return None
    }
  } else {
    0
  }
  Some(sign * (hour * 3600 + minute * 60 + second))
}

///|
fn parse_zoned_date_time(s : String) -> @time.ZonedDateTime? {
  let mut bracket_idx = -1
  let mut idx = 0
  for c in s {
    if c == '[' {
      bracket_idx = idx
      break
    }
    idx += 1
  }
  let core = if bracket_idx >= 0 {
    s[:bracket_idx].to_string() catch {
      _ => return None
    }
  } else {
    s
  }
  let zone_name = if bracket_idx >= 0 {
    if s.length() < bracket_idx + 2 {
      return None
    }
    let end = s[s.length() - 1:s.length()].to_string() catch {
      _ => return None
    }
    if end != "]" {
      return None
    }
    s[bracket_idx + 1:s.length() - 1].to_string() catch {
      _ => return None
    }
  } else {
    ""
  }
  let mut offset_idx = -1
  let mut i = 0
  for c in core {
    if i >= 10 && (c == 'Z' || c == '+' || c == '-') {
      offset_idx = i
      break
    }
    i += 1
  }
  if offset_idx < 0 {
    return None
  }
  let datetime_text = core[:offset_idx].to_string() catch { _ => return None }
  let offset_text = core[offset_idx:].to_string() catch { _ => return None }
  let datetime = @time.PlainDateTime::from_string(datetime_text) catch {
    _ => return None
  }
  let offset_seconds = match parse_timestamp_offset_seconds(offset_text) {
    Some(v) => v
    None => return None
  }
  let zone = if zone_name == "" {
    if offset_seconds == 0 {
      @time.utc_zone
    } else {
      @time.fixed_zone(offset_text, offset_seconds) catch {
        _ => return None
      }
    }
  } else {
    @time.fixed_zone(zone_name, offset_seconds, abbrev=zone_name) catch {
      _ => return None
    }
  }
  Some(@time.ZonedDateTime::from_plain_datetime(datetime, zone~))
}

///|
pub struct DateValue {
  value : @time.PlainDate
} derive(Eq)

///|
pub fn DateValue::from_plain_date(value : @time.PlainDate) -> DateValue {
  { value, }
}

///|
pub fn DateValue::from_string(s : String) -> DateValue raise {
  { value: @time.PlainDate::from_string(s) }
}

///|
pub fn DateValue::to_plain_date(self : DateValue) -> @time.PlainDate {
  self.value
}

///|
pub fn DateValue::to_string(self : DateValue) -> String {
  self.value.to_string()
}

///|
pub impl Show for DateValue with output(self, logger : &Logger) {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for DateValue with to_json(self) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for DateValue with from_json(json, path) {
  guard json is String(s) else {
    json_decode_error(path, "DateValue::from_json: expected string")
  }
  DateValue::from_string(s) catch {
    error =>
      json_decode_error(path, "DateValue::from_json: parsing failure \{error}")
  }
}

///|
pub struct TimeValue {
  value : @time.PlainTime
} derive(Eq, Compare)

///|
pub fn TimeValue::from_plain_time(value : @time.PlainTime) -> TimeValue {
  { value, }
}

///|
pub fn TimeValue::from_string(s : String) -> TimeValue raise {
  { value: @time.PlainTime::from_string(s) }
}

///|
pub fn TimeValue::to_plain_time(self : TimeValue) -> @time.PlainTime {
  self.value
}

///|
pub fn TimeValue::to_string(self : TimeValue) -> String {
  self.value.to_string()
}

///|
pub impl Show for TimeValue with output(self, logger : &Logger) {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for TimeValue with to_json(self) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for TimeValue with from_json(json, path) {
  guard json is String(s) else {
    json_decode_error(path, "TimeValue::from_json: expected string")
  }
  TimeValue::from_string(s) catch {
    error =>
      json_decode_error(path, "TimeValue::from_json: parsing failure \{error}")
  }
}

///|
pub struct DateTimeValue {
  value : @time.PlainDateTime
} derive(Eq, Compare)

///|
pub fn DateTimeValue::from_plain_date_time(
  value : @time.PlainDateTime,
) -> DateTimeValue {
  { value, }
}

///|
pub fn DateTimeValue::from_string(s : String) -> DateTimeValue raise {
  { value: @time.PlainDateTime::from_string(s) }
}

///|
pub fn DateTimeValue::to_plain_date_time(
  self : DateTimeValue,
) -> @time.PlainDateTime {
  self.value
}

///|
pub fn DateTimeValue::to_string(self : DateTimeValue) -> String {
  self.value.to_string()
}

///|
pub impl Show for DateTimeValue with output(self, logger : &Logger) {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for DateTimeValue with to_json(self) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for DateTimeValue with from_json(json, path) {
  guard json is String(s) else {
    json_decode_error(path, "DateTimeValue::from_json: expected string")
  }
  DateTimeValue::from_string(s) catch {
    error =>
      json_decode_error(
        path,
        "DateTimeValue::from_json: parsing failure \{error}",
      )
  }
}

///|
pub struct TimestampValue {
  value : @time.ZonedDateTime
}

///|
pub fn TimestampValue::from_zoned_date_time(
  value : @time.ZonedDateTime,
) -> TimestampValue {
  { value, }
}

///|
pub fn TimestampValue::from_string(s : String) -> TimestampValue raise {
  match parse_zoned_date_time(s) {
    Some(value) => { value, }
    None => fail("invalid timestamp")
  }
}

///|
pub fn TimestampValue::to_zoned_date_time(
  self : TimestampValue,
) -> @time.ZonedDateTime {
  self.value
}

///|
pub fn TimestampValue::to_string(self : TimestampValue) -> String {
  self.value.to_string()
}

///|
pub impl Eq for TimestampValue with equal(self, other) {
  self.to_string() == other.to_string()
}

///|
pub impl Show for TimestampValue with output(self, logger : &Logger) {
  logger.write_string(self.to_string())
}

///|
pub impl ToJson for TimestampValue with to_json(self) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for TimestampValue with from_json(json, path) {
  guard json is String(s) else {
    json_decode_error(path, "TimestampValue::from_json: expected string")
  }
  TimestampValue::from_string(s) catch {
    error =>
      json_decode_error(
        path,
        "TimestampValue::from_json: parsing failure \{error}",
      )
  }
}

///|
pub impl ToParam for @time.PlainDate with to_param(self) -> Param {
  Date(self)
}

///|
pub impl ToParam for DateValue with to_param(self) -> Param {
  Date(self.to_plain_date())
}

///|
pub impl ToParam for @time.PlainTime with to_param(self) -> Param {
  Time(self)
}

///|
pub impl ToParam for TimeValue with to_param(self) -> Param {
  Time(self.to_plain_time())
}

///|
pub impl ToParam for @time.PlainDateTime with to_param(self) -> Param {
  DateTime(self)
}

///|
pub impl ToParam for DateTimeValue with to_param(self) -> Param {
  DateTime(self.to_plain_date_time())
}

///|
pub impl ToParam for @time.ZonedDateTime with to_param(self) -> Param {
  Timestamp(self)
}

///|
pub impl ToParam for TimestampValue with to_param(self) -> Param {
  Timestamp(self.to_zoned_date_time())
}
