// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
/// A datetime with a time zone and offset in the ISO 8601 calendar system.
struct ZonedDateTime {
  datetime : PlainDateTime
  zone : Zone
  offset : ZoneOffset
}

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute, second and a time zone.
/// The default time zone is UTC+0.
pub fn date_time(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
    zone~,
  )
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn unix(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  ZonedDateTime::from_unix_second(second, nanosecond~, zone~)
}

///|
/// Creates a ZonedDateTime from year, month, day, hour, minute and second.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::of(
  year : Int,
  month : Int,
  day : Int,
  hour? : Int = 0,
  minute? : Int = 0,
  second? : Int = 0,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let datetime = PlainDateTime::of(
    year,
    month,
    day,
    hour~,
    minute~,
    second~,
    nanosecond~,
  )
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from a PlainDateTime and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_plain_datetime(
  datetime : PlainDateTime,
  zone? : Zone = utc_zone,
) -> ZonedDateTime {
  create_from_plain(datetime, zone)
}

///|
/// Creates a ZonedDateTime from elapsed seconds since the unix epoch and a time zone.
/// The default time zone is UTC+0.
pub fn ZonedDateTime::from_unix_second(
  second : Int64,
  nanosecond? : Int = 0,
  zone? : Zone = utc_zone,
) -> ZonedDateTime raise Error {
  let offset = zone.lookup_offset(second)
  let datetime = PlainDateTime::from_unix_second(second, nanosecond, offset)
  { datetime, zone, offset }
}

///|
pub fn ZonedDateTime::from_string(str : String) -> ZonedDateTime raise Error {
  let mut bracket_idx = -1
  let mut idx = 0
  for c in str {
    if c == '[' {
      bracket_idx = idx
      break
    }
    idx += 1
  }
  let core = if bracket_idx >= 0 { str[:bracket_idx].to_string() } else { str }
  let zone_name = if bracket_idx < 0 {
    ""
  } else {
    if str.length() < bracket_idx + 2 ||
      str[str.length() - 1:str.length()].to_string() != "]" {
      fail(invalid_date_time_err)
    }
    str[bracket_idx + 1:str.length() - 1].to_string()
  }
  let mut offset_idx = -1
  let mut i = 0
  for c in core {
    if i >= 10 && c is ('Z' | '+' | '-') {
      offset_idx = i
      break
    }
    i += 1
  }
  if offset_idx < 0 {
    fail(invalid_date_time_err)
  }
  let datetime_text = core[:offset_idx].to_string()
  let offset_text = core[offset_idx:].to_string()
  let datetime = PlainDateTime::from_string(datetime_text)
  let offset_seconds = parse_offset_seconds(offset_text)
  let zone = if zone_name == "" && offset_seconds == 0 {
    utc_zone
  } else if zone_name == "" {
    fixed_zone(offset_text, offset_seconds)
  } else {
    fixed_zone(zone_name, offset_seconds, abbrev=zone_name)
  }
  ZonedDateTime::from_plain_datetime(datetime, zone~)
}

///|
/// Returns a string representing this datetime, like "2008-08-08T20:00:00+8:00[Asia/Beijing]"
pub fn ZonedDateTime::to_string(self : ZonedDateTime) -> String {
  let buf = StringBuilder::new(size_hint=0)
  buf.write_string(self.datetime.to_string())
  buf.write_string(self.offset.to_string())
  if self.zone != utc_zone {
    buf.write_char('[')
    let abbrev = self.offset.abbreviation()
    if abbrev == "" {
      buf.write_string(self.zone.to_string())
    } else {
      buf.write_string(abbrev)
    }
    buf.write_char(']')
  }
  buf.to_string()
}

///|
pub impl Show for ZonedDateTime with output(
  self : ZonedDateTime,
  logger : &Logger,
) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for ZonedDateTime with equal(self, other) -> Bool {
  self.to_string() == other.to_string()
}

///|
pub impl ToJson for ZonedDateTime with to_json(self) -> Json {
  Json::string(self.to_string())
}

///|
pub impl @json.FromJson for ZonedDateTime with from_json(json, path) {
  guard json is String(s) else {
    json_decode_error(path, "ZonedDateTime::from_json: expected string")
  }
  ZonedDateTime::from_string(s) catch {
    error =>
      json_decode_error(
        path,
        "ZonedDateTime::from_json: parsing failure \{error}",
      )
  }
}

///|
/// Returns the elapsed seconds since the unix epoch.
pub fn ZonedDateTime::to_unix_second(self : ZonedDateTime) -> Int64 {
  self.datetime.to_unix_second() - self.offset.seconds().to_int64()
}

///|
fn parse_offset_seconds(offset : String) -> Int raise Error {
  if offset == "Z" {
    return 0
  }
  if offset.length() != 6 && offset.length() != 9 {
    fail(invalid_date_time_err)
  }
  let sign_text = offset[:1].to_string()
  let hour_text = offset[1:3].to_string()
  let first_colon = offset[3:4].to_string()
  let minute_text = offset[4:6].to_string()
  if first_colon != ":" {
    fail(invalid_date_time_err)
  }
  let sign = match sign_text {
    "+" => 1
    "-" => -1
    _ => fail(invalid_date_time_err)
  }
  let hour = @string.parse_int(hour_text) catch {
    _ => fail(invalid_date_time_err)
  }
  let minute = @string.parse_int(minute_text) catch {
    _ => fail(invalid_date_time_err)
  }
  let second = if offset.length() == 9 {
    let second_colon = offset[6:7].to_string()
    let second_text = offset[7:9].to_string()
    if second_colon != ":" {
      fail(invalid_date_time_err)
    }
    @string.parse_int(second_text) catch {
      _ => fail(invalid_date_time_err)
    }
  } else {
    0
  }
  sign * (hour * 3600 + minute * 60 + second)
}

///|
/// Returns the date part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date(self : ZonedDateTime) -> PlainDate {
  self.datetime.to_plain_date()
}

///|
/// Returns the time part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_time(self : ZonedDateTime) -> PlainTime {
  self.datetime.to_plain_time()
}

///|
/// Returns the datetime part of this datetime, without timezone.
pub fn ZonedDateTime::to_plain_date_time(self : ZonedDateTime) -> PlainDateTime {
  self.datetime
}

///|
/// Returns the era of this datetime.
pub fn ZonedDateTime::era(self : ZonedDateTime) -> String {
  self.datetime.era()
}

///|
/// Returns the year of era of this datetime.
pub fn ZonedDateTime::era_year(self : ZonedDateTime) -> Int {
  self.datetime.era_year()
}

///|
/// Returns the year of this datetime.
pub fn ZonedDateTime::year(self : ZonedDateTime) -> Int {
  self.datetime.year()
}

///|
/// Returns the month of this datetime.
pub fn ZonedDateTime::month(self : ZonedDateTime) -> Int {
  self.datetime.month()
}

///|
/// Returns the day of month of this datetime.
pub fn ZonedDateTime::day(self : ZonedDateTime) -> Int {
  self.datetime.day()
}

///|
/// Returns the weekday of this datetime.
pub fn ZonedDateTime::weekday(self : ZonedDateTime) -> Weekday {
  self.datetime.weekday()
}

///|
/// Returns the ordinal day of year of this datetime.
pub fn ZonedDateTime::ordinal(self : ZonedDateTime) -> Int {
  self.datetime.ordinal()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_week(self : ZonedDateTime) -> Int {
  self.datetime.days_in_week()
}

///|
/// Returns the number of days in a month of this datetime.
pub fn ZonedDateTime::days_in_month(self : ZonedDateTime) -> Int {
  self.datetime.days_in_month()
}

///|
/// Returns the number of days in a year of this datetime.
pub fn ZonedDateTime::days_in_year(self : ZonedDateTime) -> Int {
  self.datetime.days_in_year()
}

///|
/// Returns the number of months in a year of this datetime.
pub fn ZonedDateTime::months_in_year(self : ZonedDateTime) -> Int {
  self.datetime.months_in_year()
}

///|
/// Checks if this datetime is in a leap year.
pub fn ZonedDateTime::in_leap_year(self : ZonedDateTime) -> Bool {
  self.datetime.in_leap_year()
}

///|
/// Returns the hour of this datetime.
pub fn ZonedDateTime::hour(self : ZonedDateTime) -> Int {
  self.datetime.hour()
}

///|
/// Returns the minute of this datetime.
pub fn ZonedDateTime::minute(self : ZonedDateTime) -> Int {
  self.datetime.minute()
}

///|
/// Returns the second of this datetime.
pub fn ZonedDateTime::second(self : ZonedDateTime) -> Int {
  self.datetime.second()
}

///|
/// Returns the nanosecond of this datetime.
pub fn ZonedDateTime::nanosecond(self : ZonedDateTime) -> Int {
  self.datetime.nanosecond()
}

///|
/// Returns the time zone of this datetime.
pub fn ZonedDateTime::zone(self : ZonedDateTime) -> Zone {
  self.zone
}

///|
/// Returns the time offset of this datetime.
pub fn ZonedDateTime::offset(self : ZonedDateTime) -> ZoneOffset {
  self.offset
}

///|
/// Adds specified years to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_years(
  self : ZonedDateTime,
  years : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_years(years), self.zone)
}

///|
/// Adds specified months to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_months(
  self : ZonedDateTime,
  months : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_months(months), self.zone)
}

///|
/// Adds specified weeks to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_weeks(
  self : ZonedDateTime,
  weeks : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_weeks(weeks), self.zone)
}

///|
/// Adds specified days to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_days(
  self : ZonedDateTime,
  days : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_days(days), self.zone)
}

///|
/// Adds specified hours to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_hours(
  self : ZonedDateTime,
  hours : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_hours(hours), self.zone)
}

///|
/// Adds specified minutes to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_minutes(
  self : ZonedDateTime,
  minutes : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_minutes(minutes), self.zone)
}

///|
/// Adds specified seconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_seconds(
  self : ZonedDateTime,
  seconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_seconds(seconds), self.zone)
}

///|
/// Adds specified nanoseconds to this datetime, and returns a new datetime.
pub fn ZonedDateTime::add_nanoseconds(
  self : ZonedDateTime,
  nanoseconds : Int64,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.add_nanoseconds(nanoseconds), self.zone)
}

///|
/// Returns a new datetime with the specified year.
pub fn ZonedDateTime::with_year(
  self : ZonedDateTime,
  year : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_year(year), self.zone)
}

///|
/// Returns a new datetime with the specified month.
pub fn ZonedDateTime::with_month(
  self : ZonedDateTime,
  month : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_month(month), self.zone)
}

///|
/// Returns a new datetime with the specified day of the month.
pub fn ZonedDateTime::with_day(
  self : ZonedDateTime,
  day : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_day(day), self.zone)
}

///|
/// Returns a new datetime with the specified ordinal day of the year.
pub fn ZonedDateTime::with_ordinal(
  self : ZonedDateTime,
  ordinal : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_ordinal(ordinal), self.zone)
}

///|
/// Returns a new datetime with the specified hour.
pub fn ZonedDateTime::with_hour(
  self : ZonedDateTime,
  hour : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_hour(hour), self.zone)
}

///|
/// Returns a new datetime with the specified minute.
pub fn ZonedDateTime::with_minute(
  self : ZonedDateTime,
  minute : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_minute(minute), self.zone)
}

///|
/// Returns a new datetime with the specified second.
pub fn ZonedDateTime::with_second(
  self : ZonedDateTime,
  second : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_second(second), self.zone)
}

///|
/// Returns a new datetime with the specified nanosecond.
pub fn ZonedDateTime::with_nanosecond(
  self : ZonedDateTime,
  nanosecond : Int,
) -> ZonedDateTime raise Error {
  create_from_plain(self.datetime.with_nanosecond(nanosecond), self.zone)
}

///|
fn create_from_plain(datetime : PlainDateTime, zone : Zone) -> ZonedDateTime {
  let offset = zone.lookup_offset(datetime.to_unix_second())
  { datetime, zone, offset }
}
