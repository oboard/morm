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

///|
test "parse mapper collection return kinds" {
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct User {
    #|  #morm.id
    #|  id : Int
    #|  name : String
    #|} derive(ToJson, FromJson)
    #|
    #|///|
    #|#morm.mapper(table="user")
    #|pub trait UserMapper {
    #|  #morm.query("select * from user")
    #|  async users_as_set(Self) -> @set.Set[User]
    #|  #morm.query("select * from user")
    #|  async users_as_list(Self) -> @list.List[User]
    #|  #morm.query("select * from user")
    #|  async users_by_id(Self) -> Map[Int, User]
    #|}
  let (ast, _) = @parser.parse_string(source)
  let entity_specs = parse_entities_from_ast(ast)
  let mappers = parse_mappers_from_ast(ast, source, entity_specs)
  let methods = mappers[0].methods
  inspect(methods[0].return_type, content="@set.Set[User]")
  inspect(methods[0].return_kind, content="Set")
  inspect(
    methods[0].return_item_type.to_json().stringify(),
    content="[\"User\"]",
  )
  inspect(methods[1].return_type, content="@list.List[User]")
  inspect(methods[1].return_kind, content="List")
  inspect(methods[2].return_type, content="Map[Int,User]")
  inspect(methods[2].return_kind, content="Map")
  inspect(
    methods[2].return_map_key_type.to_json().stringify(),
    content="[\"Int\"]",
  )
  inspect(
    methods[2].return_map_value_type.to_json().stringify(),
    content="[\"User\"]",
  )
}

///|
test "generate mapper code for set list and map returns" {
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct User {
    #|  #morm.id
    #|  id : Int
    #|  name : String
    #|} derive(ToJson, FromJson)
    #|
    #|///|
    #|#morm.mapper(table="user")
    #|pub trait UserMapper {
    #|  #morm.query("select * from user")
    #|  async users_as_set(Self) -> @set.Set[User]
    #|  #morm.query("select * from user")
    #|  async users_as_list(Self) -> @list.List[User]
    #|  #morm.query("select * from user")
    #|  async users_by_id(Self) -> Map[Int, User]
    #|}
  let (ast, _) = @parser.parse_string(source)
  let entity_specs = parse_entities_from_ast(ast)
  let mapper_specs = parse_mappers_from_ast(ast, source, entity_specs)
  let code = generate_mapper_code(mapper_specs[0], entity_specs, [])
  inspect(
    code.contains("let out : @set.Set[User] = @set.Set::new()"),
    content="true",
  )
  inspect(code.contains("@list.List::from_array(out)"), content="true")
  inspect(code.contains("let out : Map[Int,User] = Map::new()"), content="true")
  inspect(code.contains("let key : Int = value.id"), content="true")
}

///|
test "parse and generate mapper page return" {
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct User {
    #|  #morm.id
    #|  id : Int
    #|  name : String
    #|  active : Int
    #|} derive(ToJson, FromJson)
    #|
    #|///|
    #|#morm.mapper(table="user")
    #|pub trait UserMapper {
    #|  async find_users_by_active(Self, active : Int, pageable : @engine.Pageable) -> @engine.Page[User]
    #|  #morm.query("SELECT id, name, active FROM user WHERE active = ?")
    #|  async find_users_page_raw(Self, active : Int, pageable : @engine.Pageable) -> @engine.Page[User]
    #|}
  let (ast, _) = @parser.parse_string(source)
  let entity_specs = parse_entities_from_ast(ast)
  let mapper_specs = parse_mappers_from_ast(ast, source, entity_specs)
  let methods = mapper_specs[0].methods
  inspect(methods[0].return_kind, content="Page")
  inspect(
    methods[0].return_item_type.to_json().stringify(),
    content="[\"User\"]",
  )
  let code = generate_mapper_code(mapper_specs[0], entity_specs, [])
  inspect(code.contains("@morm.paginate(self.engine"), content="true")
  inspect(code.contains("@morm.paginate_raw(self.engine"), content="true")
}

///|
test "parse plain enum specs from source" {
  let source =
    #|///|
    #|pub(all) enum Status {
    #|  Draft,
    #|  Published,
    #|}
    #|
    #|///|
    #|pub(all) enum IgnoreMe {
    #|  WithPayload(String)
    #|}
  let enum_specs = parse_enum_specs_from_source(source)
  inspect(enum_specs.length(), content="1")
  inspect(enum_specs[0].name, content="Status")
  inspect(
    enum_specs[0].values.to_json().stringify(),
    content="[\"Draft\",\"Published\"]",
  )
}

///|
test "generate enum codec impls for mapper package types" {
  let source =
    #|///|
    #|pub(all) enum Status {
    #|  Draft
    #|  Published
    #|} derive(ToJson, FromJson)
    #|
    #|///|
    #|#morm.mapper(table="article")
    #|pub trait ArticleMapper {
    #|  #morm.query("select status from article where id = ?")
    #|  find_status(Self, id : Int) -> Status
    #|}
  let (ast, _) = @parser.parse_string(source)
  let mapper_specs = parse_mappers_from_ast(ast, source, [])
  let code = render_enum_codec_impl(parse_enum_specs_from_source(source)[0]) +
    "\n" +
    generate_mapper_code(
      mapper_specs[0],
      [],
      parse_enum_specs_from_source(source),
    )
  inspect(code.contains("pub impl @engine.ToParam for Status"), content="true")
  inspect(
    code.contains("pub impl @engine.FromParam for Status"),
    content="true",
  )
  inspect(
    code.contains("(try! @engine.from_param(result) : Status)"),
    content="true",
  )
}
