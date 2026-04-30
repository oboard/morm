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
pub(all) enum Weekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
} derive(Eq)

///|
pub impl Show for Weekday with output(self : Weekday, logger : &Logger) {
  let text = match self {
    Monday => "Monday"
    Tuesday => "Tuesday"
    Wednesday => "Wednesday"
    Thursday => "Thursday"
    Friday => "Friday"
    Saturday => "Saturday"
    Sunday => "Sunday"
  }
  logger.write_string(text)
}

///|
fn Weekday::new(week_day : Int) -> Weekday? {
  match week_day {
    1 => Some(Monday)
    2 => Some(Tuesday)
    3 => Some(Wednesday)
    4 => Some(Thursday)
    5 => Some(Friday)
    6 => Some(Saturday)
    7 => Some(Sunday)
    _ => None
  }
}

///|
fn Weekday::value(self : Weekday) -> Int {
  match self {
    Monday => 1
    Tuesday => 2
    Wednesday => 3
    Thursday => 4
    Friday => 5
    Saturday => 6
    Sunday => 7
  }
}

///|
test "new" {
  assert_true(Weekday::new(0) is None)
  assert_true(Weekday::new(1) is Some(Monday))
  assert_true(Weekday::new(2) is Some(Tuesday))
  assert_true(Weekday::new(3) is Some(Wednesday))
  assert_true(Weekday::new(4) is Some(Thursday))
  assert_true(Weekday::new(5) is Some(Friday))
  assert_true(Weekday::new(6) is Some(Saturday))
  assert_true(Weekday::new(7) is Some(Sunday))
  assert_true(Weekday::new(8) is None)
}

///|
test "value" {
  inspect(Weekday::Monday.value(), content="1")
  inspect(Weekday::Tuesday.value(), content="2")
  inspect(Weekday::Wednesday.value(), content="3")
  inspect(Weekday::Thursday.value(), content="4")
  inspect(Weekday::Friday.value(), content="5")
  inspect(Weekday::Saturday.value(), content="6")
  inspect(Weekday::Sunday.value(), content="7")
}
