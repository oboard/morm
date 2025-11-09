///|
fn map_type_to_db_by_name(
  field_type : String,
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> @morm.ColumnType {
  // 首先检查是否有特定的 morm 类型属性
  // 使用 match 模式替代多个 if 判断，更接近 GORM 的风格
  let attr_type = find_morm_type_attribute(attrs)
  if attr_type is Some(ty) {
    return ty
  }
  // 默认类型映射表，类似 GORM 的 DataTypeMap
  match field_type {
    // 基本类型
    "Int" => @morm.ColumnType::Int
    "Int8" => @morm.ColumnType::TinyInt
    "Int16" => @morm.ColumnType::SmallInt
    "Int32" => @morm.ColumnType::Int
    "Int64" => @morm.ColumnType::BigInt
    "UInt" => @morm.ColumnType::Int
    "UInt8" => @morm.ColumnType::Int
    "UInt16" => @morm.ColumnType::Int
    "UInt32" => @morm.ColumnType::Int
    "UInt64" => @morm.ColumnType::Int
    "Float" => @morm.ColumnType::Float
    "Float32" => @morm.ColumnType::Float
    "Float64" => @morm.ColumnType::Double
    "Bool" => @morm.ColumnType::Boolean
    "String" => @morm.ColumnType::VarChar(255)
    "Char" => @morm.ColumnType::Char(1)
    // 复杂类型
    "Date" => @morm.ColumnType::Date
    "DateTime" => @morm.ColumnType::DateTime
    "Time" => @morm.ColumnType::Time
    "Timestamp" => @morm.ColumnType::Timestamp
    "Json" => @morm.ColumnType::Json
    "Bytes" => @morm.ColumnType::Blob
    "UUID" => @morm.ColumnType::VarChar(36)
    // 默认情况
    _ => @morm.ColumnType::VarChar(255)
  }
}

///|
/// 查找 morm 类型属性
fn find_morm_type_attribute(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> @morm.ColumnType? {
  // 单次遍历 attrs，记录首个匹配并在遍历结束返回，避免多次线性扫描与闭包返回类型不匹配
  let mut result : @morm.ColumnType? = None
  attrs.each(attr => match attr.raw {
    "#morm.datetime" => result = Some(@morm.ColumnType::DateTime)
    "#morm.date" => result = Some(@morm.ColumnType::Date)
    "#morm.time" => result = Some(@morm.ColumnType::Time)
    "#morm.timestamp" => result = Some(@morm.ColumnType::Timestamp)
    "#morm.varchar" => result = Some(@morm.ColumnType::VarChar(255))
    "#morm.char" => result = Some(@morm.ColumnType::Char(1))
    "#morm.text" => result = Some(@morm.ColumnType::Text)
    "#morm.mediumtext" => result = Some(@morm.ColumnType::MediumText)
    "#morm.longtext" => result = Some(@morm.ColumnType::LongText)
    "#morm.binary" => result = Some(@morm.ColumnType::Binary(1))
    "#morm.varbinary" => result = Some(@morm.ColumnType::VarBinary(255))
    "#morm.blob" => result = Some(@morm.ColumnType::Blob)
    "#morm.tinyint" => result = Some(@morm.ColumnType::TinyInt)
    "#morm.smallint" => result = Some(@morm.ColumnType::SmallInt)
    "#morm.int" => result = Some(@morm.ColumnType::Int)
    "#morm.bigint" => result = Some(@morm.ColumnType::BigInt)
    "#morm.float" => result = Some(@morm.ColumnType::Float)
    "#morm.double" => result = Some(@morm.ColumnType::Double)
    "#morm.decimal" => result = Some(@morm.ColumnType::Decimal(10, 2))
    "#morm.boolean" => result = Some(@morm.ColumnType::Boolean)
    "#morm.json" => result = Some(@morm.ColumnType::Json)
    "#morm.jsonb" => result = Some(@morm.ColumnType::JsonB)
    "#morm.uuid" => result = Some(@morm.ColumnType::VarChar(36))
    _ => ()
  })
  result
}

///|
/// 获取属性参数
fn get_attribute_param(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  attr_name : String,
  default_value : String,
) -> String {
  // 简化实现，实际应该解析属性参数
  // 这里只返回默认值，后续可以扩展为解析实际参数
  return default_value
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
/// 单次遍历收集常用字段标志，避免重复扫描
fn collect_field_flags(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> (Bool, Bool, Bool) {
  let mut is_primary_key = false
  let mut is_auto_increment = false
  let mut has_not_null = false
  attrs.each(attr => match attr.raw {
    "#morm.primary_key" => is_primary_key = true
    "#morm.auto_increment" => is_auto_increment = true
    "#morm.not_null" => has_not_null = true
    _ => ()
  })
  (is_primary_key, is_auto_increment, has_not_null)
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let path = @ref.new("")
  let usage =
    #| MoonBit ORM CLI tool for generating database schema from Moonbit files
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
          let fields : Array[@morm.Column] = []
          params.each(param => if param
            is { name: { label, .. }, ty, attrs, .. } {
            let field_type = match ty {
              Name(constr_id={ id: Ident(name~) | Dot(id=name, ..), .. }, ..) =>
                name
              _ => "String"
            }
            let db_type = map_type_to_db_by_name(field_type, attrs)
            let (is_primary_key, is_auto_increment, has_not_null) = collect_field_flags(
              attrs,
            )
            let is_nullable = !has_not_null && !is_primary_key
            let field_info : @morm.Column = {
              name: label,
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
            fields.push(field_info)
          })
          let table = @morm.Table::new(
            name,
            columns=FixedArray::from_array(fields),
          )
          let code = "pub impl @morm.Entity for \{name} with table(_self) -> @morm.Table { try! @json.from_json(\{table.to_json().stringify()}) }"
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
