///|
pub extend BsonError with Eq::{not_equal, equal}

///|
pub extend BsonError with ToJson::{to_json}

///|
pub extend BsonError with Show::{to_string, output}
