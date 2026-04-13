///|
test "transient field is not emitted as table column" {
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
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source, [])
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
fn table_option_values(table : @morm.Table, key : String) -> Array[String] {
  let values : Array[String] = []
  for opt in table.engine_options {
    if opt.key == key {
      values.push(opt.value)
    }
  }
  values
}

///|
test "primary key strategy annotation is emitted to engine options" {
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct Keyed {
    #|  #morm.id(strategy="uuid")
    #|  id : String
    #|  name : String
    #|} derive(ToJson, FromJson)
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source, [])
  inspect(table.columns[0].primary_key, content="true")
  inspect(table.columns[0].auto_increment, content="false")
  inspect(
    column_option_value(table.columns[0], "pk.strategy").unwrap_or(""),
    content="uuid",
  )
}

///|
test "auto_increment strategy keeps auto increment behavior" {
  let source =
    #|///|
    #|#morm.entity
    #|pub(all) struct AutoId {
    #|  #morm.id(strategy="auto_increment")
    #|  id : Int64
    #|} derive(ToJson, FromJson)
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source, [])
  inspect(table.columns[0].primary_key, content="true")
  inspect(table.columns[0].auto_increment, content="true")
  inspect(
    column_option_value(table.columns[0], "pk.strategy").unwrap_or(""),
    content="auto_increment",
  )
}

///|
test "default expression literals are preserved by field type" {
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
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source, [])
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

///|
test "enum field maps to native enum column type" {
  let source =
    #|///|
    #|pub(all) enum Status {
    #|  Draft
    #|  Published
    #|} derive(ToJson, FromJson)
    #|
    #|///|
    #|#morm.entity
    #|pub(all) struct Article {
    #|  #morm.id
    #|  id : Int
    #|  status : Status
    #|} derive(ToJson, FromJson)
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let enum_specs = parse_enum_specs_from_source(source)
  let table = transform_entity_to_table(specs[0], source, enum_specs)
  inspect(
    table.columns[1].column_type.to_json().stringify(),
    content=(
      #|["Enum","Status",["Draft","Published"]]
    ),
  )
}

///|
test "postgres privilege annotations emit table engine options" {
  let source =
    #|///|
    #|#morm.entity
    #|#morm.postgres.schema("app")
    #|#morm.postgres.schema(authorization="app_owner")
    #|#morm.postgres.table(owner="app_owner", unlogged="true", with="fillfactor=70")
    #|#morm.postgres.grant(role="app_reader", schema="USAGE", table="SELECT", default_table="SELECT", for_role="app_owner")
    #|#morm.postgres.grant(role="app_writer", schema="USAGE", table="SELECT, INSERT, UPDATE, DELETE", sequence="USAGE, SELECT", with_grant_option="true")
    #|pub(all) struct Article {
    #|  #morm.id
    #|  id : Int
    #|} derive(ToJson, FromJson)
  let (ast, _) = @parser.parse_string(source)
  let specs = parse_entities_from_ast(ast)
  let table = transform_entity_to_table(specs[0], source, [])
  inspect(table.schema.unwrap_or(""), content="\"app\"")
  inspect(
    table_option_values(table, "pgsql.schema.authorization")[0],
    content="app_owner",
  )
  inspect(
    table_option_values(table, "pgsql.table.owner")[0],
    content="app_owner",
  )
  inspect(table_option_values(table, "pgsql.unlogged")[0], content="true")
  inspect(table_option_values(table, "pgsql.with")[0], content="fillfactor=70")
  inspect(
    table_option_values(table, "pgsql.grant.schema")[0],
    content="role=app_reader;privileges=USAGE;grant_option=false",
  )
  inspect(
    table_option_values(table, "pgsql.grant.table")[1],
    content=(
      #|role=app_writer;privileges=SELECT, INSERT, UPDATE, DELETE;grant_option=true
    ),
  )
  inspect(
    table_option_values(table, "pgsql.grant.sequence")[0],
    content="role=app_writer;privileges=USAGE, SELECT;grant_option=true",
  )
  inspect(
    table_option_values(table, "pgsql.default_grant.table")[0],
    content=(
      #|role=app_reader;privileges=SELECT;grant_option=false;for_role=app_owner
    ),
  )
}
