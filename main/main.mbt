///|
/// 变换阶段：从 EntitySpec 构建 @morm.Table，不接触解析细节
fn transform_entity_to_table(spec : EntitySpec) -> @morm.Table {
  let columns : Array[@morm.Column] = []
  let foreign_keys : Array[@morm.ForeignKey] = []
  for f in spec.fields {
    let db_type = map_type_to_db_by_name(f.field_type, f.attrs)
    let (is_primary_key, is_auto_increment, has_not_null) = collect_field_flags(
      f.attrs,
    )
    let is_nullable = !has_not_null && !is_primary_key
    let col : @morm.Column = {
      name: f.label,
      column_type: db_type,
      size: 0,
      nullable: is_nullable,
      default_value: None,
      auto_increment: is_auto_increment,
      primary_key: is_primary_key,
      unique: false,
      comment: "",
      charset: None,
      collation: None,
    }
    columns.push(col)
    if parse_foreign_key_for_field(spec.name, f.label, f.field_type, f.attrs)
      is Some(fk) {
      foreign_keys.push(fk)
    }
  }
  let mut table = @morm.Table::new(
    spec.table_name,
    columns=FixedArray::from_array(columns),
  )
  for fk in foreign_keys {
    table = @morm.add_foreign_key(table, fk)
  }
  table
}

///|
/// 代码生成阶段：从表结构生成实现代码
fn generate_entity_impl(name : String, table : @morm.Table) -> String {
  "pub impl @oboard/morm.Entity for \{name} with table(_self) -> @oboard/morm.Table { \{name}::table() }\n" +
  "pub fn \{name}::table() -> @morm.Table { try! @json.from_json(\{table.to_json().stringify()}) }"
}

///|
/// 代码生成阶段：根据 MapperSpec 生成 struct、mapper 函数与方法实现
fn generate_mapper_code(spec : MapperSpec) -> String {
  let trait_name = spec.trait_name
  let entity_name = spec.entity_name
  let struct_def = "pub struct \{trait_name}_ {\n  engine : &@engine.Engine\n}\n\n"
  let mapper_fn = "pub fn \{entity_name}::mapper(engine : &@engine.Engine) -> \{trait_name}_ {\n  \{trait_name}_::{ engine, }\n}\n\n"
  let mut impls = ""
  for m in spec.methods {
    let param_sig_parts : Array[String] = []
    let json_args_parts : Array[String] = []
    for p in m.params {
      let (pname, ptype) = p
      param_sig_parts.push("\{pname} : \{ptype}")
      json_args_parts.push("\{pname}.to_json()")
    }
    let param_sig = if param_sig_parts.length() == 0 {
      "self"
    } else {
      "self, " + param_sig_parts.join(", ")
    }
    let json_args = "[" + json_args_parts.join(", ") + "]"
    // 返回类型字符串
    let ret_type = if m.returns_array {
      "FixedArray[\{m.return_entity}]"
    } else {
      "\{m.return_entity}?"
    }
    let method_header = "pub impl \{trait_name} for \{trait_name}_ with \{m.name}(\n  \{param_sig}\n) -> \{ret_type} {\n"
    let body = if m.returns_array {
      "  self.engine.exec(\"\{m.sql}\", \{json_args}).rows.map(row => @json.from_json(\n      row,\n    ) catch {\n      _ => panic()\n    },\n  )\n}\n\n"
    } else {
      "  if self.engine.exec(\"\{m.sql}\", \{json_args}).rows\n    is [result, ..] {\n    return Some(try! @json.from_json(result))\n  }\n  None\n}\n\n"
    }
    impls = impls + method_header + body
  }
  struct_def + mapper_fn + impls
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let input_file = @ref.new("")
  let output_file = @ref.new("")
  let usage =
    #| MoonBit ORM CLI tool for generating database schema from Moonbit files
    #| usage: 
    #|      morm-gen <input_file> -o <output_file>
    #|
  @ArgParser.parse(
    [
      (
        "--output-file",
        "-o",
        String(file => output_file.val = file),
        "Output file",
      ),
    ],
    file => input_file.val = file,
    usage,
    argv,
  )
  try {
    let (ast, _) = @parser.parse_file(input_file.val)
    let specs = parse_entities_from_ast(ast)
    let mapper_specs = parse_mappers_from_ast(ast)
    //
    let codes : Array[String] = []
    specs.each(spec => {
      let table = transform_entity_to_table(spec)
      let code = generate_entity_impl(spec.name, table)
      codes.push(code)
    })
    mapper_specs.each(ms => {
      let mcode = generate_mapper_code(ms)
      codes.push(mcode)
    })
    let code = codes.join("\n\n")
    @fs.write_string_to_file(output_file.val, code, encoding="utf8")
    let entity_names = specs.map(spec => spec.name)
    let mapper_names = mapper_specs.map(ms => ms.trait_name)
    if entity_names.length() > 0 {
      println("Generated \{output_file.val} for entities: \{entity_names}")
    }
    if mapper_names.length() > 0 {
      println("Generated \{output_file.val} for mappers: \{mapper_names}")
    }
  } catch {
    @fs.IOError(e) => println("IOError: \{e}")
  }
}
