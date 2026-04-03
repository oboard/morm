///|
pub(all) enum Status {
  Draft
  Published
} derive(ToJson, FromJson, Show)

///|
test "enum param helpers round trip through JSON string form" {
  let param = try! enum_to_param(Status::Published)
  inspect(param.to_json().stringify(), content="\"Published\"")
  let status : Status = try! enum_from_param(param)
  inspect(status.to_json().stringify(), content="\"Published\"")
}
