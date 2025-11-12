///|
// 解析阶段的中间结构，避免直接耦合到 @morm.*
struct FieldSpec {
  label : String
  field_type : String
  nullable : Bool
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute]
}

///|
struct EntitySpec {
  name : String
  table_name : String
  fields : Array[FieldSpec]
}

///|
struct ORMAttribute {
  name : String
  value : Map[String, String]
}

///|
/// 去除参数键名两端空白字符（空格/制表符）
fn trim_key(s : String) -> String {
  let mut t = s
  // 去除前缀空白
  while t.has_prefix(" ") || t.has_prefix("\t") {
    t = t[1:].to_string() catch { _ => t }
  }
  // 去除后缀空白
  while t.has_suffix(" ") || t.has_suffix("\t") {
    let n = t.length()
    if n == 0 {
      break
    }
    t = t[0:n - 1].to_string() catch { _ => t }
  }
  t
}

///|
/// 收集并解析所有 #morm.* attributes 为结构化 ORMAttribute
fn collect_orm_attributes(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> Array[ORMAttribute] {
  let results : Array[ORMAttribute] = []
  attrs.each(attr => if attr.raw.has_prefix("#morm.") {
    let raw = attr.raw
    let mut name = raw
    let mut params_part = ""
    if raw.find("(") is Some(open_idx) {
      name = raw[0:open_idx].to_string() catch { _ => raw }
      if raw.find(")") is Some(close_idx) {
        params_part = raw[open_idx + 1:close_idx].to_string() catch { _ => "" }
      }
    }
    // 解析 params_part 为 key="value" 的字典
    let m : Map[String, String] = Map::new()
    let mut i = 0
    let n = params_part.length()
    while i < n {
      let rest = params_part[i:].to_string() catch { _ => "" }
      if rest.find(",") is Some(comma_rel) {
        let comma_abs = i + comma_rel
        let pair = params_part[i:comma_abs].to_string() catch { _ => "" }
        i = comma_abs + 1
        if pair.find("=") is Some(eq_idx) {
          let k = trim_key(pair[0:eq_idx].to_string() catch { _ => "" })
          let vrest = pair[eq_idx + 1:].to_string() catch { _ => "" }
          if vrest.has_prefix("\"") {
            let vrest_tail = vrest[1:].to_string() catch { _ => "" }
            if vrest_tail.find("\"") is Some(end_rel) {
              let v = vrest[1:1 + end_rel].to_string() catch { _ => "" }
              m.set(k, v)
            }
          }
        }
      } else {
        let pair = params_part[i:].to_string() catch { _ => "" }
        i = n
        if pair.find("=") is Some(eq_idx) {
          let k = trim_key(pair[0:eq_idx].to_string() catch { _ => "" })
          let vrest = pair[eq_idx + 1:].to_string() catch { _ => "" }
          if vrest.has_prefix("\"") {
            let vrest_tail = vrest[1:].to_string() catch { _ => "" }
            if vrest_tail.find("\"") is Some(end_rel) {
              let v = vrest[1:1 + end_rel].to_string() catch { _ => "" }
              m.set(k, v)
            }
          }
        }
      }
    }
    results.push({ name, value: m })
  })
  results
}

///|
/// Mapper 方法规格：方法名、SQL、参数与返回实体名
struct MapperMethodSpec {
  name : String
  sql : String
  params : Array[(String, String)] // (param_name, type_name)
  return_entity : String
  returns_array : Bool
}

///|
/// Mapper 规格：Trait 名称、实体名、方法列表
struct MapperSpec {
  trait_name : String
  entity_name : String
  methods : Array[MapperMethodSpec]
}

///|
/// 提取 attribute 括号中的内容（不含引号处理）
fn extract_text_inside_parens(raw : String) -> String? {
  if raw.find("(") is Some(open_idx) {
    if raw.find(")") is Some(close_idx) {
      return Some(try! raw[open_idx + 1:close_idx].to_string())
    }
  }
  None
}

///|
/// 提取 attribute 中首个引号包裹的字符串
fn extract_quoted_string_in_parens(raw : String) -> String? {
  if raw.find("\"") is Some(start_idx) {
    let tail = try! raw[start_idx + 1:].to_string()
    if tail.find("\"") is Some(end_rel) {
      return Some(try! raw[start_idx + 1:start_idx + 1 + end_rel].to_string())
    }
  }
  None
}

///|
/// 解析阶段：从 AST 收集 Mapper 规格
fn parse_mappers_from_ast(
  ast : @moonbitlang/core/list.List[@moonbitlang/parser/syntax.Impl],
) -> Array[MapperSpec] {
  let specs : Array[MapperSpec] = []
  ast.each(item => if item is @syntax.Impl::TopTrait(trait_decl) {
    if trait_decl is { name: { name: trait_name, .. }, methods, attrs, .. } {
      // 读取实体名
      let mut entity_name_opt : String? = None
      attrs.each(attr => if attr.raw.has_prefix("#morm.mapper") {
        entity_name_opt = extract_text_inside_parens(attr.raw)
      })
      if entity_name_opt is None {
        return
      }
      let entity_name = entity_name_opt.unwrap()

      // 收集方法
      let mmethods : Array[MapperMethodSpec] = []
      methods.each(m => if m is { name: { name: mname, .. }, params, attrs, .. } {
        // 提取 SQL
        let mut sql_opt : String? = None
        attrs.each(a => if a.raw.has_prefix("#morm.query") {
          sql_opt = extract_quoted_string_in_parens(a.raw)
        })
        if sql_opt is None {
          return
        }
        let sql = sql_opt.unwrap()

        // 提取参数（基于 Parameter 变体，读取 binder.name 与显式类型）
        let plist : Array[(String, String)] = []
        params.each(p => match p {
          Positional(binder={ name: pname, .. }, ty=Some(pty)) => {
            let tname = match pty {
              Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..) => t
              _ => "String"
            }
            plist.push((pname, tname))
          }
          Labelled(binder={ name: pname, .. }, ty=Some(pty)) => {
            let tname = match pty {
              Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..) => t
              _ => "String"
            }
            plist.push((pname, tname))
          }
          Optional(binder={ name: pname, .. }, ty=Some(pty), ..) => {
            let tname = match pty {
              Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..) => t
              _ => "String"
            }
            plist.push((pname, tname))
          }
          QuestionOptional(binder={ name: pname, .. }, ty=Some(pty)) => {
            let tname = match pty {
              Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..) => t
              _ => "String"
            }
            plist.push((pname, tname))
          }
          _ => ()
        })

        // 解析返回类型：Option[Entity] / FixedArray[Entity] / 基本类型可选 T?
        let mut returns_array = false
        let mut ret_entity = entity_name
        match m {
          { return_type: Some(return_type), .. } =>
            match return_type {
              Option(
                ty=Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..),
                ..
              ) => ret_entity = t
              Name(
                constr_id={
                  id: Ident(name="FixedArray")
                  | Dot(id="FixedArray", ..),
                  ..,
                },
                tys~,
                ..
              ) => {
                // 安全遍历类型参数列表，取首元素作为数组内类型
                let mut inner_opt : @moonbitlang/parser/syntax.Type? = None
                tys.each(inner => if inner_opt is None {
                  inner_opt = Some(inner)
                })
                if inner_opt is Some(inner_ty) {
                  returns_array = true
                  match inner_ty {
                    Name(
                      constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. },
                      ..
                    ) => ret_entity = t
                    _ => ()
                  }
                }
              }
              // 普通名称类型（例如 Int），非数组场景下用于推断基础返回类型
              Name(constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. }, ..) =>
                ret_entity = t
              _ => ()
            }
          _ => ()
        }
        // SQL 级别回退：识别 count 聚合返回 Int?
        if !returns_array {
          if sql.find("count(") is Some(_) {
            ret_entity = "Int"
          }
        }
        mmethods.push({
          name: mname,
          sql,
          params: plist,
          return_entity: ret_entity,
          returns_array,
        })
        //
      })
      specs.push({ trait_name, entity_name, methods: mmethods })
    }
  })
  specs
}

///|
/// 解析字段上的外键属性（仅参数化声明），学习 GORM 风格，不依赖命名约定
fn parse_foreign_key_for_field(
  current_table : String,
  field_label : String,
  _field_type : String,
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> @morm.ForeignKey? {
  // 一次性收集并解析 attributes
  let parsed = collect_orm_attributes(attrs)
  // 查找 foreign_key 项
  let mut fkargs_refs : String? = None
  let mut fkargs_table : String? = None
  let mut fkargs_column : String? = None
  let mut fkargs_on_delete : String? = None
  let mut fkargs_on_update : String? = None
  parsed.each(a => if a.name == "#morm.foreign_key" {
    if a.value.get("references") is Some(v) {
      fkargs_refs = Some(v)
    }
    if a.value.get("table") is Some(v) {
      fkargs_table = Some(v)
    }
    if a.value.get("column") is Some(v) {
      fkargs_column = Some(v)
    }
    if a.value.get("on_delete") is Some(v) {
      fkargs_on_delete = Some(v)
    }
    if a.value.get("on_update") is Some(v) {
      fkargs_on_update = Some(v)
    }
  })
  if fkargs_refs is None &&
    fkargs_table is None &&
    fkargs_column is None &&
    fkargs_on_delete is None &&
    fkargs_on_update is None {
    return None
  }
  // 支持 references="Table.column" 或分别提供 table/column
  let mut referenced_table = ""
  let mut referenced_column = ""
  if fkargs_refs is Some(r) {
    if r.find(".") is Some(dot_index) {
      let dot = dot_index
      try {
        referenced_table = r[0:dot].to_string()
        referenced_column = r[dot + 1:].to_string()
      } catch {
        _ => ()
      }
    }
  }
  if referenced_table == "" {
    if fkargs_table is Some(t) {
      referenced_table = t
    }
  }
  if referenced_column == "" {
    if fkargs_column is Some(c) {
      referenced_column = c
    }
  }

  // 未提供足够信息则不生成外键
  if referenced_table == "" || referenced_column == "" {
    return None
  }
  let constraint_name = "fk_" + current_table + "_" + field_label
  let mut fk = @morm.ForeignKey::new(
    constraint_name, field_label, referenced_table, referenced_column,
  )

  // 可选 on_delete / on_update 参数（CASCADE/SET NULL/RESTRICT/NO ACTION）
  if fkargs_on_delete is Some(od) {
    if od == "CASCADE" {
      fk = @morm.on_delete_cascade(fk)
    }
  }
  if fkargs_on_update is Some(ou) {
    if ou == "CASCADE" {
      fk = @morm.on_update_cascade(fk)
    }
  }
  Some(fk)
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
fn extract_type_name_and_nullable(
  ty : @moonbitlang/parser/syntax.Type,
) -> (String, Bool) {
  match ty {
    Name(constr_id={ id: Ident(name~) | Dot(id=name, ..), .. }, ..) =>
      (name, false)
    Option(
      ty=Name(constr_id={ id: Ident(name~) | Dot(id=name, ..), .. }, ..),
      ..
    ) => (name, true)
    _ => ("String", false)
  }
}

///|
/// 解析阶段：使用中间结构 EntitySpec（调用者负责提供 AST）
// 说明：避免在此函数中调用可能带错误类型的 API，保持纯解析逻辑。
fn parse_entities_from_ast(
  ast : @moonbitlang/core/list.List[@moonbitlang/parser/syntax.Impl],
) -> Array[EntitySpec] {
  let specs : Array[EntitySpec] = []
  ast.each(item => if item is @syntax.Impl::TopTypeDef(type_decl) {
    if type_decl is { tycon: name, components: Record(params), attrs, .. } {
      let orm_attrs = collect_orm_attributes(attrs)
      let mut has_entity = false
      let mut table_name = name
      orm_attrs.each(a => if a.name == "#morm.entity" {
        has_entity = true
        if a.value.get("name") is Some(custom_name) {
          table_name = custom_name
        }
      })
      if !has_entity {
        return
      }
      let fields : Array[FieldSpec] = []
      params.each(param => if param is { name: { label, .. }, ty, attrs, .. } {
        let (field_type, is_nullable) = extract_type_name_and_nullable(ty)
        fields.push({ label, field_type, nullable: is_nullable, attrs })
      })
      specs.push({ name, table_name, fields })
    }
  })
  specs
}

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
