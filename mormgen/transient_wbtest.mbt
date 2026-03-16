///|
test "transient field is not emitted as table column" {
  let path = "/tmp/mormgen_transient_" + @env.now().to_string() + ".mbt"
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct Demo {
    #|  #morm.id
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
    #|  #morm.id(strategy="uuid")
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
    #|  #morm.id(strategy="auto_increment")
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

///|
test "default expression literals are preserved by field type" {
  let path = "/tmp/mormgen_default_expr_" + @env.now().to_string() + ".mbt"
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct DefaultsDemo {
    #|  #morm.id
    #|  #morm.default(autoincrement())
    #|  id : Int64
    #|  #morm.default("2020-03-19T14:21:00+02:00")
    #|  created_at : String
    #|  #morm.default("SGVsbG8gd29ybGQ=")
    #|  payload : Bytes
    #|  #morm.default(["red", "yellow", "purple"])
    #|  tags : Json
    #|  #morm.default(false)
    #|  published : Bool
    #|} derive(ToJson, FromJson)
  @fs.write_string_to_file(path, source, encoding="utf8")
  let (ast, _) = @parser.parse_file(path)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source)
  inspect(table.columns[0].auto_increment, content="true")
  inspect(table.columns[0].default_value.to_json().stringify(), content="null")
  inspect(
    table.columns[1].default_value.unwrap_or(""),
    content="'2020-03-19T14:21:00+02:00'",
  )
  inspect(
    table.columns[2].default_value.unwrap_or(""),
    content="'SGVsbG8gd29ybGQ='",
  )
  inspect(
    table.columns[3].default_value.unwrap_or(""),
    content="'[\"red\", \"yellow\", \"purple\"]'",
  )
  inspect(table.columns[4].default_value.unwrap_or(""), content="false")
}
