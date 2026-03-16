///|
// 解析阶段的中间结构，避免直接耦合到 @morm.*
struct FieldSpec {
  label : String
  field_type : String
  nullable : Bool
  attrs : @list.List[@moonbitlang/parser/attribute.Attribute]
}

///|
struct EntitySpec {
  name : String
  table_name : String
  fields : Array[FieldSpec]
  attrs : Array[ORMAttribute]
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
    t = t[1:].to_string()
  }
  // 去除后缀空白
  while t.has_suffix(" ") || t.has_suffix("\t") {
    let n = t.length()
    if n == 0 {
      break
    }
    t = t[0:n - 1].to_string()
  }
  t
}

///|
/// 收集并解析所有 #morm.* attributes 为结构化 ORMAttribute
fn collect_orm_attributes(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> Array[ORMAttribute] {
  let results : Array[ORMAttribute] = []
  attrs.each(attr => {
    if attr.raw.has_prefix("#morm.") {
      let raw = attr.raw
      let mut name = raw
      let mut params_part = ""
      if raw.find("(") is Some(open_idx) {
        name = raw[0:open_idx].to_string()
        if raw.has_suffix(")") && raw.length() > open_idx + 1 {
          params_part = raw[open_idx + 1:raw.length() - 1].to_string()
        } else if raw.find(")") is Some(close_idx) {
          params_part = raw[open_idx + 1:close_idx].to_string()
        }
      }
      // 解析 params_part 为 key="value" 的字典
      let m : Map[String, String] = Map::new()
      if name == "#morm.default" && trim_key(params_part) != "" {
        m.set("value", trim_key(params_part))
      } else if !params_part.contains("=") && trim_key(params_part) != "" {
        m.set("value", trim_key(params_part))
      } else {
        let mut i = 0
        let n = params_part.length()
        while i < n {
          let rest = params_part[i:].to_string()
          if rest.find(",") is Some(comma_rel) {
            let comma_abs = i + comma_rel
            let pair = params_part[i:comma_abs].to_string()
            i = comma_abs + 1
            if pair.find("=") is Some(eq_idx) {
              let k = trim_key(pair[0:eq_idx].to_string())
              let vrest = pair[eq_idx + 1:].to_string()
              if vrest.has_prefix("\"") {
                let vrest_tail = vrest[1:].to_string()
                if vrest_tail.find("\"") is Some(end_rel) {
                  let v = vrest[1:1 + end_rel].to_string()
                  m.set(k, v)
                }
              }
            }
          } else {
            let pair = params_part[i:].to_string()
            i = n
            if pair.find("=") is Some(eq_idx) {
              let k = trim_key(pair[0:eq_idx].to_string())
              let vrest = pair[eq_idx + 1:].to_string()
              if vrest.has_prefix("\"") {
                let vrest_tail = vrest[1:].to_string()
                if vrest_tail.find("\"") is Some(end_rel) {
                  let v = vrest[1:1 + end_rel].to_string()
                  m.set(k, v)
                }
              }
            } else if trim_key(pair) != "" {
              m.set("value", trim_key(pair))
            }
          }
        }
      }
      results.push({ name, value: m })
    }
  })
  results
}

///|
/// 与 collect_orm_attributes 相同，但会尝试基于位置信息恢复完整 attribute 文本
fn collect_orm_attributes_from_source(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> Array[ORMAttribute] {
  let results : Array[ORMAttribute] = []
  attrs.each(attr => {
    let mut raw = attr.raw
    if raw.has_prefix("#morm.") && !raw.contains("(") {
      let recovered = recover_attr_raw(source, attr)
      if recovered != "" {
        raw = recovered
      }
    }
    if raw.has_prefix("#morm.") {
      let mut name = raw
      let mut params_part = ""
      if raw.find("(") is Some(open_idx) {
        name = raw[0:open_idx].to_string()
        if raw.has_suffix(")") && raw.length() > open_idx + 1 {
          params_part = raw[open_idx + 1:raw.length() - 1].to_string()
        } else if raw.find(")") is Some(close_idx) {
          params_part = raw[open_idx + 1:close_idx].to_string()
        }
      }
      let m : Map[String, String] = Map::new()
      if name == "#morm.default" && trim_key(params_part) != "" {
        m.set("value", trim_key(params_part))
      } else if !params_part.contains("=") && trim_key(params_part) != "" {
        m.set("value", trim_key(params_part))
      } else {
        let mut i = 0
        let n = params_part.length()
        while i < n {
          let rest = params_part[i:].to_string()
          if rest.find(",") is Some(comma_rel) {
            let comma_abs = i + comma_rel
            let pair = params_part[i:comma_abs].to_string()
            i = comma_abs + 1
            if pair.find("=") is Some(eq_idx) {
              let k = trim_key(pair[0:eq_idx].to_string())
              let vrest = pair[eq_idx + 1:].to_string()
              if vrest.has_prefix("\"") {
                let vrest_tail = vrest[1:].to_string()
                if vrest_tail.find("\"") is Some(end_rel) {
                  let v = vrest[1:1 + end_rel].to_string()
                  m.set(k, v)
                }
              }
            }
          } else {
            let pair = params_part[i:].to_string()
            i = n
            if pair.find("=") is Some(eq_idx) {
              let k = trim_key(pair[0:eq_idx].to_string())
              let vrest = pair[eq_idx + 1:].to_string()
              if vrest.has_prefix("\"") {
                let vrest_tail = vrest[1:].to_string()
                if vrest_tail.find("\"") is Some(end_rel) {
                  let v = vrest[1:1 + end_rel].to_string()
                  m.set(k, v)
                }
              }
            } else if trim_key(pair) != "" {
              m.set("value", trim_key(pair))
            }
          }
        }
      }
      results.push({ name, value: m })
    }
  })
  results
}

///|
/// Mapper 方法规格：方法名、SQL、参数与返回实体名
struct MapperMethodSpec {
  name : String
  sql : String? // 显式 SQL
  builder_code : String? // 构建器代码
  fetch_join : String? // 查询时追加 JOIN（JPA JOIN FETCH 风格）
  params : Array[(String, String)] // (param_name, type_name)
  return_type : String
  returns_array : Bool
  returns_option : Bool
  is_async : Bool
}

///|
/// Mapper 规格：Trait 名称、实体名、方法列表
struct MapperSpec {
  trait_name : String
  entity_name : String?
  table_name : String?
  methods : Array[MapperMethodSpec]
}

///|
/// 提取 attribute 括号中的内容（不含引号处理）
fn extract_text_inside_parens(raw : String) -> String? {
  if raw.find("(") is Some(open_idx) && raw.find(")") is Some(close_idx) {
    return Some(raw[open_idx + 1:close_idx].to_string())
  }
  None
}

///|
/// 提取 attribute 中首个引号包裹的字符串
fn extract_quoted_string_in_parens(raw : String) -> String? {
  if raw.find("\"") is Some(start_idx) {
    let tail = raw[start_idx + 1:].to_string()
    if tail.find("\"") is Some(end_rel) {
      return Some(raw[start_idx + 1:start_idx + 1 + end_rel].to_string())
    }
  }
  None
}

///|
fn recover_attr_with_parens(
  source : String,
  attr : @moonbitlang/parser/attribute.Attribute,
  raw : String,
) -> String {
  if extract_text_inside_parens(raw) is Some(_) {
    return raw
  }
  let recovered = recover_attr_raw(source, attr)
  if recovered != "" {
    recovered
  } else {
    raw
  }
}

///|
fn recover_attr_with_quoted(
  source : String,
  attr : @moonbitlang/parser/attribute.Attribute,
  raw : String,
) -> String {
  if extract_quoted_string_in_parens(raw) is Some(_) {
    return raw
  }
  let recovered = recover_attr_raw(source, attr)
  if recovered != "" {
    recovered
  } else {
    raw
  }
}

///|
fn recover_attr_raw(
  source : String,
  attr : @moonbitlang/parser/attribute.Attribute,
) -> String {
  let loc = attr.loc
  let start_str = loc.start.to_string()
  let end_str = loc.end.to_string()

  let parse_pos = fn(s : String) -> (Int, Int) {
    let mut s = s
    if s.has_prefix("\"") && s.length() >= 2 {
      s = s[1:s.length()].to_string()
    }
    if s.has_suffix("\"") && s.length() >= 1 {
      s = s[0:s.length() - 1].to_string()
    }

    let parts = s.split(":").collect()
    let len = parts.length()
    if len >= 2 {
      let line = @strconv.parse_int(parts[len - 2]) catch { _ => -1 }
      let col = @strconv.parse_int(parts[len - 1]) catch { _ => -1 }
      (line, col)
    } else {
      (-1, -1)
    }
  }

  let (sl, sc) = parse_pos(start_str)
  let (el, ec) = parse_pos(end_str)

  let start_line = sl - 1
  let start_col = sc - 1
  let end_line = el - 1
  let end_col = ec - 1

  let lines = source.split("\n").collect()
  if start_line == end_line && start_line >= 0 && start_line < lines.length() {
    let line = lines[start_line]
    let len = line.length()
    if start_col >= 0 && end_col <= len && start_col <= end_col {
      let res = line[start_col:end_col].to_string()
      return res
    }
  }
  ""
}

///|
/// 从方法名提取 `_by_` 后面的条件字段
fn derive_method_condition_fields(method_name : String) -> Array[String] {
  let mut condition_part = ""

  if method_name.strip_prefix("find_") is Some(rest) {
    let parts = rest.split("_by_").collect()
    if parts.length() >= 2 {
      condition_part = parts[1].to_string()
    } else if rest.strip_prefix("by_") is Some(by_rest) {
      condition_part = by_rest.to_string()
    }
  } else if method_name.strip_prefix("count_") is Some(rest) {
    let parts = rest.split("_by_").collect()
    if parts.length() >= 2 {
      condition_part = parts[1].to_string()
    } else if rest.strip_prefix("by_") is Some(by_rest) {
      condition_part = by_rest.to_string()
    }
  }

  if condition_part == "" {
    return []
  }

  let fields : Array[String] = []
  for field in condition_part.split("_and_") {
    fields.push(field.to_string())
  }
  fields
}

///|
/// 为没有显式名字的 mapper 参数补上推导名
fn infer_mapper_param_names(method_name : String, count : Int) -> Array[String] {
  let inferred : Array[String] = []

  if count <= 0 {
    return inferred
  }

  if method_name is ("save" | "delete") {
    inferred.push("entity")
  } else {
    for field in derive_method_condition_fields(method_name) {
      inferred.push(field.to_string())
    }
  }

  while inferred.length() < count {
    inferred.push("arg" + (inferred.length() + 1).to_string())
  }

  let trimmed : Array[String] = []
  let mut i = 0
  while i < count {
    trimmed.push(inferred[i])
    i = i + 1
  }
  trimmed
}

///|
fn resolve_mapper_param_name(
  parsed_name : String,
  inferred_names : Array[String],
  index : Int,
) -> String {
  if parsed_name is ("" | "_" | "?binder") {
    return inferred_names[index]
  }
  parsed_name
}

///|
/// 从方法名推导构建器代码
fn derive_builder_code(
  method_name : String,
  entity_name : String,
  table_name : String?,
) -> String? {
  let table_expr = match table_name {
    Some(t) => "\"\{t}\""
    None => "\{entity_name}::table().name"
  }
  let is_count = method_name.has_prefix("count_")

  // 识别动作并提取 by 条件片段（与 entity 解耦）
  if method_name is ("find_all" | "all") {
    return Some("@morm.select_from(\{table_expr})")
  }

  let fields = derive_method_condition_fields(method_name)
  if fields.length() == 0 {
    return None
  }

  // 构建代码
  let start = if is_count {
    "@morm.select_raw(\{table_expr}, \"count(*)\")"
  } else {
    "@morm.select_from(\{table_expr})"
  }

  let wheres_arr : Array[String] = []
  fields.each(f => wheres_arr.push(".where_eq(\"\{f}\", \{f})"))
  let wheres = wheres_arr.join("")

  Some("\{start}\{wheres}")
}

///|
/// 解析阶段：从 AST 收集 Mapper 规格
fn parse_mappers_from_ast(
  ast : @moonbitlang/core/list.List[@moonbitlang/parser/syntax.Impl],
  source : String,
  entities : Array[EntitySpec],
) -> Array[MapperSpec] {
  let specs : Array[MapperSpec] = []

  // 建立实体名到表名的映射
  let entity_table_map : Map[String, String] = Map::new()
  entities.each(e => entity_table_map.set(e.name, e.table_name))

  ast.each(item => {
    match item {
      @syntax.Impl::TopTrait(trait_decl) =>
        if trait_decl is { name: { name: trait_name, .. }, methods, attrs, .. } {
          // println("Found TopTrait: \{trait_name}")
          // 读取 mapper 绑定信息（entity 可选，table 可选）
          let mut entity_name_opt : String? = None
          let mut table_name_opt : String? = None
          attrs.each(attr => {
            // println("  Attr: \{attr.raw}")
            let raw_text = recover_attr_with_parens(source, attr, attr.raw)
            if raw_text.has_prefix("#morm.mapper") {
              if extract_text_inside_parens(raw_text) is Some(inner) {
                if inner.contains("=") {
                  lexmatch inner {
                    (_before, "entity=\"" ("[^\"]*" as entity) "\"", _after) =>
                      entity_name_opt = Some(entity.to_string())
                    _ => ()
                  }
                  lexmatch inner {
                    (_before, "table=\"" ("[^\"]*" as table) "\"", _after) =>
                      table_name_opt = Some(table.to_string())
                    _ => ()
                  }
                } else {
                  let plain = trim_key(inner)
                  // 兼容旧写法 #mapper(Student)
                  if entity_table_map.get(plain) is Some(tbl) {
                    entity_name_opt = Some(plain)
                    table_name_opt = Some(tbl)
                  } else {
                    table_name_opt = Some(plain)
                  }
                }
              }
            }
          })
          if table_name_opt is None &&
            entity_name_opt is Some(entity_name) &&
            entity_table_map.get(entity_name) is Some(tbl) {
            table_name_opt = Some(tbl)
          }
          if entity_name_opt is None && table_name_opt is Some(table_name) {
            entities.each(e => {
              if e.table_name == table_name {
                entity_name_opt = Some(e.name)
              }
            })
          }
          // 收集方法
          let mmethods : Array[MapperMethodSpec] = []
          methods.each(m => {
            if m is { name: { name: mname, .. }, params, attrs, is_async, .. } {
              // 提取 SQL
              let mut sql_opt : String? = None
              let mut builder_code_opt : String? = None
              let mut fetch_join_opt : String? = None

              attrs.each(a => {
                let raw_text = recover_attr_with_quoted(source, a, a.raw)
                if raw_text.has_prefix("#morm.query") {
                  sql_opt = extract_quoted_string_in_parens(raw_text)
                }
                if raw_text.has_prefix("#morm.fetch") ||
                  raw_text.has_prefix("#morm.fetch_graph") ||
                  raw_text.has_prefix("#morm.load_graph") {
                  if extract_quoted_string_in_parens(raw_text) is Some(join_sql) {
                    fetch_join_opt = Some(join_sql)
                  } else if extract_text_inside_parens(raw_text) is Some(inner) {
                    lexmatch inner {
                      (_before, "join=\"" ("[^\"]*" as join_sql) "\"", _after) =>
                        fetch_join_opt = Some(join_sql.to_string())
                      (_before, "joins=\"" ("[^\"]*" as join_sql) "\"", _after) =>
                        fetch_join_opt = Some(join_sql.to_string())
                      _ => ()
                    }
                  }
                }
              })

              // 如果没有显式 query 注解，尝试从方法名推导构建器代码
              if sql_opt is None {
                builder_code_opt = derive_builder_code(
                  mname,
                  match entity_name_opt {
                    Some(n) => n
                    None => ""
                  },
                  table_name_opt,
                )
              }

              if sql_opt is None &&
                builder_code_opt is None &&
                mname != "save" &&
                mname != "delete" {
                return
              }

              // 提取参数（基于 Parameter 变体，读取 binder.name 与显式类型）
              let plist : Array[(String, String)] = []
              let mut total_params = 0
              params.each(_ => total_params = total_params + 1)
              let inferred_param_names = infer_mapper_param_names(
                mname, total_params,
              )
              let mut param_index = 0
              params.each(p => {
                match p {
                  Positional(binder={ name: pname, .. }, ty=Some(pty)) => {
                    let tname = match pty {
                      Name(
                        constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. },
                        ..
                      ) => t
                      _ => "String"
                    }
                    let resolved_name = resolve_mapper_param_name(
                      pname, inferred_param_names, param_index,
                    )
                    if tname != "Self" {
                      plist.push((resolved_name, tname))
                      param_index = param_index + 1
                    }
                  }
                  DiscardPositional(ty=Some(pty), ..) => {
                    let tname = match pty {
                      Name(
                        constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. },
                        ..
                      ) => t
                      _ => "String"
                    }
                    if tname != "Self" {
                      let pname = inferred_param_names[param_index]
                      plist.push((pname, tname))
                      param_index = param_index + 1
                    }
                  }
                  Labelled(binder={ name: pname, .. }, ty=Some(pty)) => {
                    let tname = match pty {
                      Name(
                        constr_id={ id: Ident(name=t) | Dot(id=t, ..), .. },
                        ..
                      ) => t
                      _ => "String"
                    }
                    let resolved_name = resolve_mapper_param_name(
                      pname, inferred_param_names, param_index,
                    )
                    if tname != "Self" {
                      plist.push((resolved_name, tname))
                      param_index = param_index + 1
                    }
                  }
                  _ => ()
                }
              })
              // 检查返回类型是否为 Array
              let mut returns_array = false
              let mut returns_option = false
              let mut return_type = "String?"

              match m.return_type {
                Some(ty) =>
                  match ty {
                    Name(
                      constr_id={ id: Ident(name=n) | Dot(id=n, ..), .. },
                      tys~,
                      ..
                    ) =>
                      if n == "FixedArray" {
                        match tys.head() {
                          Some(
                            Name(
                              constr_id={
                                id: Ident(name=inner)
                                | Dot(id=inner, ..),
                                ..,
                              },
                              ..
                            )
                          ) => {
                            returns_array = true
                            return_type = "FixedArray[\{inner}]"
                          }
                          _ => ()
                        }
                      } else {
                        return_type = n
                      }
                    Option(
                      ty=Name(
                        constr_id={
                          id: Ident(name=inner)
                          | Dot(id=inner, ..),
                          ..,
                        },
                        ..
                      ),
                      ..
                    ) => {
                      returns_option = true
                      return_type = "\{inner}?"
                    }
                    _ => ()
                  }
                None => ()
              }

              mmethods.push({
                name: mname,
                sql: sql_opt,
                builder_code: builder_code_opt,
                fetch_join: fetch_join_opt,
                params: plist,
                return_type,
                returns_array,
                returns_option,
                is_async: is_async is Some(_),
              })
            }
          })
          specs.push({
            trait_name,
            entity_name: entity_name_opt,
            table_name: table_name_opt,
            methods: mmethods,
          })
        }
      _ => ()
    }
  })

  specs
}

///|
/// 解析字段上的外键属性（仅参数化声明），学习 GORM 风格，不依赖命名约定
fn parse_foreign_key_for_field(
  current_table : String,
  field_label : String,
  field_type : String,
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> @morm.ForeignKey? {
  // 一次性收集并解析 attributes
  let parsed = collect_orm_attributes_from_source(attrs, source)
  // 查找 foreign_key 项
  let mut has_foreign_key = false
  let mut is_many_to_one = false
  let mut fk_column_name = field_label
  let mut fkargs_refs : String? = None
  let mut fkargs_table : String? = None
  let mut fkargs_column : String? = None
  let mut fkargs_on_delete : String? = None
  let mut fkargs_on_update : String? = None
  parsed.each(a => {
    if a.name == "#morm.foreign_key" {
      has_foreign_key = true
      if a.value.get("references") is Some(v) {
        fkargs_refs = Some(v)
      }
      if a.value.get("table") is Some(v) {
        fkargs_table = Some(v)
      }
      if a.value.get("column") is Some(v) {
        fkargs_column = Some(v)
        fk_column_name = v
      }
      if a.value.get("on_delete") is Some(v) {
        fkargs_on_delete = Some(v)
      }
      if a.value.get("on_update") is Some(v) {
        fkargs_on_update = Some(v)
      }
    }
    if a.name == "#morm.many_to_one" {
      has_foreign_key = true
      is_many_to_one = true
      if a.value.get("references") is Some(v) {
        fkargs_refs = Some(v)
      }
      if a.value.get("table") is Some(v) {
        fkargs_table = Some(v)
      }
      if a.value.get("column") is Some(v) {
        fkargs_column = Some(v)
      }
      if a.value.get("fk") is Some(v) {
        fk_column_name = v
      }
      if a.value.get("on_delete") is Some(v) {
        fkargs_on_delete = Some(v)
      }
      if a.value.get("on_update") is Some(v) {
        fkargs_on_update = Some(v)
      }
    }
    if a.name == "#morm.on_delete_cascade" {
      fkargs_on_delete = Some("CASCADE")
    }
    if a.name == "#morm.on_update_cascade" {
      fkargs_on_update = Some("CASCADE")
    }
  })
  if !has_foreign_key {
    return None
  }
  if is_many_to_one && fk_column_name == field_label {
    fk_column_name = field_label + "_id"
  }
  // 支持 references="Table.column" 或分别提供 table/column
  let mut referenced_table = ""
  let mut referenced_column = ""
  if fkargs_refs is Some(r) && r.find(".") is Some(dot_index) {
    let dot = dot_index
    referenced_table = r[0:dot].to_string()
    referenced_column = r[dot + 1:].to_string()
  }
  if referenced_table == "" && fkargs_table is Some(t) {
    referenced_table = t
  }
  if referenced_column == "" && fkargs_column is Some(c) {
    referenced_column = c
  }

  // 兜底：仅声明 #foreign_key 时，按常见命名推断 <name>_id -> <name>.id
  if referenced_table == "" && referenced_column == "" {
    if field_label.has_suffix("_id") && field_label.length() > 3 {
      referenced_table = field_label[0:field_label.length() - 3].to_string()
      referenced_column = "id"
    } else {
      referenced_table = field_type.to_lower()
      referenced_column = "id"
    }
  }

  // 未提供足够信息则不生成外键
  if referenced_table == "" || referenced_column == "" {
    return None
  }
  let constraint_name = "fk_" + current_table + "_" + field_label
  let mut fk = @morm.ForeignKey::new(
    constraint_name, fk_column_name, referenced_table, referenced_column,
  )

  // 可选 on_delete / on_update 参数（CASCADE/SET NULL/RESTRICT/NO ACTION）
  if fkargs_on_delete is Some("CASCADE") {
    fk = @morm.on_delete_cascade(fk)
  }
  if fkargs_on_update is Some("CASCADE") {
    fk = @morm.on_update_cascade(fk)
  }
  Some(fk)
}

///|
fn field_is_one_to_many(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> Bool {
  let parsed = collect_orm_attributes_from_source(attrs, source)
  let mut hit = false
  parsed.each(a => if a.name == "#morm.one_to_many" { hit = true })
  hit
}

///|
fn field_is_transient(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> Bool {
  let parsed = collect_orm_attributes_from_source(attrs, source)
  let mut hit = false
  parsed.each(a => if a.name == "#morm.transient" { hit = true })
  hit
}

///|
fn field_many_to_one_fk_column(
  field_label : String,
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> String? {
  let parsed = collect_orm_attributes_from_source(attrs, source)
  for a in parsed {
    if a.name == "#morm.many_to_one" {
      if a.value.get("fk") is Some(v) {
        return Some(v)
      }
      if a.value.get("column") is Some(v) {
        return Some(v)
      }
      return Some(field_label + "_id")
    }
  }
  None
}

///|
/// 查找 morm 类型属性
fn find_morm_type_attribute(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
) -> @morm.ColumnType? {
  // 单次遍历 attrs，记录首个匹配并在遍历结束返回，避免多次线性扫描与闭包返回类型不匹配
  let mut result : @morm.ColumnType? = None
  attrs.each(attr => {
    let raw = attr.raw
    if raw.has_prefix("#morm.datetime") {
      result = Some(@morm.ColumnType::DateTime)
    } else if raw.has_prefix("#morm.date") {
      result = Some(@morm.ColumnType::Date)
    } else if raw.has_prefix("#morm.time") {
      result = Some(@morm.ColumnType::Time)
    } else if raw.has_prefix("#morm.timestamp") {
      result = Some(@morm.ColumnType::Timestamp)
    } else if raw.has_prefix("#morm.varchar") {
      result = Some(@morm.ColumnType::VarChar(255))
    } else if raw.has_prefix("#morm.char") {
      result = Some(@morm.ColumnType::Char(1))
    } else if raw.has_prefix("#morm.text") {
      result = Some(@morm.ColumnType::Text)
    } else if raw.has_prefix("#morm.mediumtext") {
      result = Some(@morm.ColumnType::MediumText)
    } else if raw.has_prefix("#morm.longtext") {
      result = Some(@morm.ColumnType::LongText)
    } else if raw.has_prefix("#morm.binary") {
      result = Some(@morm.ColumnType::Binary(1))
    } else if raw.has_prefix("#morm.varbinary") {
      result = Some(@morm.ColumnType::VarBinary(255))
    } else if raw.has_prefix("#morm.blob") {
      result = Some(@morm.ColumnType::Blob)
    } else if raw.has_prefix("#morm.tinyint") {
      result = Some(@morm.ColumnType::TinyInt)
    } else if raw.has_prefix("#morm.smallint") {
      result = Some(@morm.ColumnType::SmallInt)
    } else if raw.has_prefix("#morm.int") {
      result = Some(@morm.ColumnType::Int)
    } else if raw.has_prefix("#morm.bigint") {
      result = Some(@morm.ColumnType::BigInt)
    } else if raw.has_prefix("#morm.float") {
      result = Some(@morm.ColumnType::Float)
    } else if raw.has_prefix("#morm.double") {
      result = Some(@morm.ColumnType::Double)
    } else if raw.has_prefix("#morm.decimal") {
      result = Some(@morm.ColumnType::Decimal(10, 2))
    } else if raw.has_prefix("#morm.boolean") {
      result = Some(@morm.ColumnType::Boolean)
    } else if raw.has_prefix("#morm.json") {
      result = Some(@morm.ColumnType::Json)
    } else if raw.has_prefix("#morm.jsonb") {
      result = Some(@morm.ColumnType::JsonB)
    } else if raw.has_prefix("#morm.uuid") {
      result = Some(@morm.ColumnType::VarChar(36))
    }
  })
  result
}

///|
/// 单次遍历收集常用字段标志，避免重复扫描
fn collect_field_flags(
  attrs : @moonbitlang/core/list.List[@moonbitlang/parser/attribute.Attribute],
  source : String,
) -> (Bool, Bool, Bool, String?) {
  let mut is_primary_key = false
  let mut is_auto_increment = false
  let mut has_not_null = false
  let mut primary_key_strategy : String? = None
  let parsed_attrs = collect_orm_attributes_from_source(attrs, source)
  parsed_attrs.each(attr => {
    match attr.name {
      "#morm.primary_key" | "#morm.id" => {
        is_primary_key = true
        if attr.value.get("strategy") is Some(strategy) {
          primary_key_strategy = Some(strategy)
        }
      }
      "#morm.auto_increment" => is_auto_increment = true
      "#morm.default" =>
        if attr.value.get("value") is Some(value) {
          let v = value.to_lower()
          if v is ("autoincrement" | "autoincrement()" | "autoincrement( )") {
            is_auto_increment = true
            if !is_primary_key {
              is_primary_key = true
            }
            if primary_key_strategy is None {
              primary_key_strategy = Some("auto_increment")
            }
          }
        }
      "#morm.not_null" => has_not_null = true
      _ => ()
    }
  })
  if primary_key_strategy is Some(strategy) {
    match strategy {
      "auto_increment" => {
        is_primary_key = true
        is_auto_increment = true
      }
      "manual" => {
        is_primary_key = true
        is_auto_increment = false
      }
      _ => {
        is_primary_key = true
        is_auto_increment = false
      }
    }
  }
  (is_primary_key, is_auto_increment, has_not_null, primary_key_strategy)
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
  ast.each(item => {
    if item is @syntax.Impl::TopTypeDef(type_decl) {
      if type_decl is { tycon: name, components: Record(params), attrs, .. } {
        let orm_attrs = collect_orm_attributes(attrs)
        let mut has_entity = false
        let mut table_name = name.to_lower()
        orm_attrs.each(a => {
          if a.name is ("#morm.model" | "#morm.entity") {
            has_entity = true
          }
          if a.name is ("#morm.model" | "#morm.entity" | "#morm.table") &&
            a.value.get("name") is Some(custom_name) {
            table_name = custom_name
          }
        })
        if !has_entity {
          return
        }
        let fields : Array[FieldSpec] = []
        params.each(param => {
          if param is { name: { label, .. }, ty, attrs, .. } {
            let (field_type, is_nullable) = extract_type_name_and_nullable(ty)
            fields.push({ label, field_type, nullable: is_nullable, attrs })
          }
        })
        specs.push({ name, table_name, fields, attrs: orm_attrs })
      }
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
    "PlainDateTime" => @morm.ColumnType::DateTime
    "Time" => @morm.ColumnType::Time
    "Timestamp" => @morm.ColumnType::Timestamp
    "ZonedDateTime" => @morm.ColumnType::Timestamp
    "Json" => @morm.ColumnType::Json
    "Bytes" => @morm.ColumnType::Blob
    "UUID" => @morm.ColumnType::VarChar(36)
    // 默认情况
    _ => @morm.ColumnType::VarChar(255)
  }
}
