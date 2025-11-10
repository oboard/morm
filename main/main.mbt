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
  "pub impl @morm.Entity for \{name} with table(_self) -> @morm.Table { \{name}::table() }\n" +
  "pub fn \{name}::table() -> @morm.Table { try! @json.from_json(\{table.to_json().stringify()}) }"
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
    let codes : Array[String] = []
    specs.each(spec => {
      let table = transform_entity_to_table(spec)
      let code = generate_entity_impl(spec.name, table)
      codes.push(code)
    })
    let code = codes.join("\n\n")
    @fs.write_string_to_file(output_file.val, code, encoding="utf8")
    println(
      "Generated \{output_file.val} for entities: \{specs.map(spec => spec.name)}",
    )
  } catch {
    @fs.IOError(e) => println("IOError: \{e}")
  }
}
