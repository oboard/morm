///|
pub(all) enum Status {
  Draft
  Published
} derive(ToJson, FromJson)

///|
pub impl Show for Status with output(self : Status, logger : &Logger) {
  let text = match self {
    Draft => "Draft"
    Published => "Published"
  }
  logger.write_string(text)
}

///|
test "enum param helpers round trip through JSON string form" {
  let param = try! enum_to_param(Status::Published)
  inspect(param.to_json().stringify(), content="\"Published\"")
  let status : Status = try! enum_from_param(param)
  inspect(status.to_json().stringify(), content="\"Published\"")
}
