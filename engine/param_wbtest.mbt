///|
pub(all) enum Status {
  Draft
  Published
} derive(ToJson, FromJson)

///|
pub impl Show for Status with fn output(self : Status, logger : &Logger) {
  let text = match self {
    Draft => "Draft"
    Published => "Published"
  }
  logger.write_string(text)
}

///|
pub extend Status with ToJson::{to_json}

///|
pub extend Status with @json.FromJson::{from_json}

///|
pub extend Status with Show::{to_string, output}

///|
test "enum param helpers round trip through JSON string form" {
  let param = try! enum_to_param(Status::Published)
  inspect(param.to_json().stringify(), content="\"Published\"")
  let status : Status = try! enum_from_param(param)
  inspect(status.to_json().stringify(), content="\"Published\"")
}
