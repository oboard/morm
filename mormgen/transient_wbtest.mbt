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

///|
fn column_option_value(col : @morm.Column, key : String) -> String? {
  for opt in col.engine_options {
    if opt.key == key {
      return Some(opt.value)
    }
  }
  None
}

///|
test "primary key strategy annotation is emitted to engine options" {
  let path = "/tmp/mormgen_pk_strategy_" + @env.now().to_string() + ".mbt"
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct Keyed {
    #|  #morm.primary_key(strategy="uuid")
    #|  id : String
    #|  name : String
    #|} derive(ToJson, FromJson)
  @fs.write_string_to_file(path, source, encoding="utf8")
  let (ast, _) = @parser.parse_file(path)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source)
  inspect(table.columns[0].primary_key, content="true")
  inspect(table.columns[0].auto_increment, content="false")
  inspect(
    column_option_value(table.columns[0], "pk.strategy").unwrap_or(""),
    content="uuid",
  )
}

///|
test "auto_increment strategy keeps auto increment behavior" {
  let path = "/tmp/mormgen_pk_strategy_ai_" + @env.now().to_string() + ".mbt"
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct AutoId {
    #|  #morm.primary_key(strategy="auto_increment")
    #|  id : Int64
    #|} derive(ToJson, FromJson)
  @fs.write_string_to_file(path, source, encoding="utf8")
  let (ast, _) = @parser.parse_file(path)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source)
  inspect(table.columns[0].primary_key, content="true")
  inspect(table.columns[0].auto_increment, content="true")
  inspect(
    column_option_value(table.columns[0], "pk.strategy").unwrap_or(""),
    content="auto_increment",
  )
}
