///|
test "transient field is not emitted as table column" {
  let path = "/tmp/mormgen_transient_" + @env.now().to_string() + ".mbt"
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct Demo {
    #|  #morm.primary_key
    #|  id : Int
    #|  name : String
    #|  #morm.transient
    #|  display_name : String?
    #|} derive(ToJson, FromJson)
  @fs.write_string_to_file(path, source, encoding="utf8")
  let (ast, _) = @parser.parse_file(path)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source)
  inspect(table.columns.length(), content="2")
  inspect(table.columns[0].name, content="id")
  inspect(table.columns[1].name, content="name")
}
