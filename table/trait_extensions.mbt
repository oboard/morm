///|
pub extend ColumnType with ToJson::{to_json}

///|
pub extend ColumnType with @json.FromJson::{from_json}

///|
pub extend ColumnType with Eq::{not_equal, equal}

///|
pub extend ColumnType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ColumnType with Hash::{hash, hash_combine}

///|
pub extend ColumnType with Show::{to_string, output}

///|
pub extend Column with ToJson::{to_json}

///|
pub extend Column with Eq::{not_equal, equal}

///|
pub extend Column with Show::{to_string, output}

///|
pub extend IndexType with ToJson::{to_json}

///|
pub extend IndexType with @json.FromJson::{from_json}

///|
pub extend IndexType with Eq::{not_equal, equal}

///|
pub extend IndexType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend IndexType with Hash::{hash, hash_combine}

///|
pub extend IndexType with Show::{to_string, output}

///|
pub extend Index with ToJson::{to_json}

///|
pub extend Index with @json.FromJson::{from_json}

///|
pub extend Index with Eq::{not_equal, equal}

///|
pub extend Index with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend Index with Hash::{hash, hash_combine}

///|
pub extend Index with Show::{to_string, output}

///|
pub extend ForeignKey with ToJson::{to_json}

///|
pub extend ForeignKey with @json.FromJson::{from_json}

///|
pub extend ForeignKey with Eq::{not_equal, equal}

///|
pub extend ForeignKey with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub extend ForeignKey with Hash::{hash, hash_combine}

///|
pub extend ForeignKey with Show::{to_string, output}

///|
pub extend Table with ToJson::{to_json}

///|
pub extend Table with Eq::{not_equal, equal}

///|
pub extend Table with Show::{to_string, output}
