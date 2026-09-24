///|
pub extend Duration with Eq::{not_equal, equal}

///|
pub extend Duration with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Duration with Show::{output}

///|
pub extend Period with Eq::{not_equal, equal}

///|
pub extend Period with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Period with Show::{output}

///|
pub extend PlainDate with Show::{output}

///|
pub extend PlainDate with ToJson::{to_json}

///|
pub extend PlainDate with @json.FromJson::{from_json}

///|
pub extend PlainDate with Eq::{not_equal, equal}

///|
pub extend PlainDate with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend PlainDateTime with Eq::{not_equal, equal}

///|
pub extend PlainDateTime with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend PlainDateTime with Show::{output}

///|
pub extend PlainDateTime with ToJson::{to_json}

///|
pub extend PlainDateTime with @json.FromJson::{from_json}

///|
pub extend PlainTime with Eq::{not_equal, equal}

///|
pub extend PlainTime with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend PlainTime with Show::{output}

///|
pub extend PlainTime with ToJson::{to_json}

///|
pub extend PlainTime with @json.FromJson::{from_json}

///|
pub extend Weekday with Eq::{not_equal, equal}

///|
pub extend Weekday with Show::{to_string, output}

///|
pub extend Zone with Eq::{not_equal, equal}

///|
pub extend Zone with Show::{output}

///|
pub extend ZoneOffset with Show::{output}

///|
pub extend ZoneOffset with Eq::{not_equal, equal}

///|
pub extend ZoneOffset with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ZonedDateTime with Show::{output}

///|
pub extend ZonedDateTime with Eq::{not_equal, equal}

///|
pub extend ZonedDateTime with ToJson::{to_json}

///|
pub extend ZonedDateTime with @json.FromJson::{from_json}
