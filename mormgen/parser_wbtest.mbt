///|
test "infer unnamed mapper params from method name" {
  inspect(
    infer_mapper_param_names("find_by_peer_id", 1),
    content="[\"peer_id\"]",
  )
  inspect(
    infer_mapper_param_names("find_messages_by_sender_id_and_peer_id", 2),
    content="[\"sender_id\", \"peer_id\"]",
  )
  inspect(infer_mapper_param_names("save", 1), content="[\"entity\"]")
}
