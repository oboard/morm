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
  inspect(
    infer_mapper_param_names("delete_by_id_and_tenant_id", 2),
    content="[\"id\", \"tenant_id\"]",
  )
  inspect(
    infer_mapper_param_names("update_status_and_name_by_id", 3),
    content="[\"status\", \"name\", \"id\"]",
  )
}

///|
test "derive builder code for update/delete naming conventions" {
  inspect(
    derive_builder_code("delete_by_id_and_tenant_id", "User", Some("user")).unwrap_or(
      "",
    ),
    content=(
      #|@morm.delete_from("user").where_eq("id", id).where_eq("tenant_id", tenant_id)
    ),
  )
  inspect(
    derive_builder_code("update_status_and_name_by_id", "User", Some("user")).unwrap_or(
      "",
    ),
    content=(
      #|@morm.update("user").set("status", status).set("name", name).where_eq("id", id)
    ),
  )
}
