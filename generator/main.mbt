///|
struct FieldInfo {
  name : String
  db_type : String
  is_primary_key : Bool
  is_auto_increment : Bool
  is_nullable : Bool
}

///|
fn map_type_to_db_by_name(
  field_type : String,
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> String {
  // 首先检查是否有特定的 morm 类型属性
  if has_attribute(attrs, "#morm.datetime") {
    return "DateTime"
  }
  if has_attribute(attrs, "#morm.varchar") {
    return "VarChar(255)" // 简化处理
  }
  if has_attribute(attrs, "#morm.bigint") {
    return "BigInt"
  }
  if has_attribute(attrs, "#morm.text") {
    return "Text"
  }

  // 根据字段类型映射
  match field_type {
    "Int" => "Int"
    "String" => "VarChar(255)"
    _ => "VarChar(255)"
  }
}

///|
fn has_attribute(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  attr_name : String,
) -> Bool {
  let mut found = false
  attrs.each(attr => if attr.raw == attr_name { found = true })
  found
}

///|
fn generate_column_code(field : FieldInfo) -> String {
  let mut column_code = "Column::new(\"\{field.name}\", \{field.db_type})"
  if field.is_primary_key {
    column_code = column_code + " |> primary_key"
  }
  if field.is_auto_increment {
    column_code = column_code + " |> auto_increment"
  }
  if !field.is_nullable {
    column_code = column_code + " |> not_null"
  }
  column_code
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let path = @ref.new("")
  let usage =
    #| Simple CLI tool for generating database schema from Moonbit files
    #| usage: 
    #|      morm-generator <path>
    #|
  @ArgParser.parse([], file => path.val = file, usage, argv)
  try {
    let files = @fs.read_dir(path.val).filter(file => file.has_suffix(".mbt"))
    println("Files: \{files}")
    files.each(file => {
      let (ast, _) = @parser.parse_file("\{path.val}/\{file}")
      ast.each(item => if item is @syntax.Impl::TopTypeDef(type_decl) {
        if type_decl is { tycon: name, components: Record(params), attrs, .. } {
          if !has_attribute(attrs, "#morm.entity") {
            return
          }

          // 收集所有字段信息
          let fields : Array[FieldInfo] = []
          params.each(param => if param
            is { name: { label, .. }, ty, attrs, .. } {
            let field_type = match ty {
              Name(constr_id={ id: Ident(name~) | Dot(id=name, ..), .. }, ..) =>
                name
              _ => "String"
            }
            let db_type = map_type_to_db_by_name(field_type, attrs)
            let is_primary_key = has_attribute(attrs, "#morm.primary_key")
            let is_auto_increment = has_attribute(attrs, "#morm.auto_increment")
            let is_nullable = !has_attribute(attrs, "#morm.not_null") &&
              !is_primary_key
            let field_info : FieldInfo = {
              name: label,
              db_type,
              is_primary_key,
              is_auto_increment,
              is_nullable,
            }
            fields.push(field_info)
          })

          // 生成列定义代码
          let column_definitions = fields
            .map(generate_column_code)
            .join(",\n    ")
          let code = "pub impl Entity for \{name} with table(_self) -> Table { Table::new(\"\{name}\", columns=[\{column_definitions}])}"
          let output_file = if file.strip_suffix(".mbt") is Some(base_name) {
            base_name + ".g.mbt"
          } else {
            raise @fs.IOError("File name does not end with .mbt")
          }
          @fs.write_string_to_file(
            "\{path.val}/\{output_file}",
            code,
            encoding="utf8",
          )
          println("Generated \{output_file} for entity \{name}")
        }
      })
    })
  } catch {
    @fs.IOError(e) => println("IOError: \{e}")
  }
}
