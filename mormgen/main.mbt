///|
/// 变换阶段：从 EntitySpec 构建 @morm.Table，不接触解析细节
fn transform_entity_to_table(spec : EntitySpec, source : String) -> @morm.Table {
  let columns : Array[@morm.Column] = []
  let foreign_keys : Array[@morm.ForeignKey] = []
  for f in spec.fields {
    let db_type = map_type_to_db_by_name(f.field_type, f.attrs)
    let (is_primary_key, is_auto_increment, _) = collect_field_flags(f.attrs)
    let is_nullable = f.nullable && !is_primary_key
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
    if parse_foreign_key_for_field(
        spec.name,
        f.label,
        f.field_type,
        f.attrs,
        source,
      )
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
  (
    $| pub impl @oboard/morm.Entity for \{name} with table(_self) -> @oboard/morm.Table { \{name}::table() }
    $| pub fn \{name}::table() -> @morm.Table { try! @json.from_json(\{table.to_json().stringify()}) }
  )
}

///|
/// 代码生成阶段：根据 MapperSpec 生成 struct、mapper 函数与方法实现
fn generate_mapper_code(spec : MapperSpec) -> String {
  let trait_name = spec.trait_name
  let impl_name = trait_name + "Impl"
  let entity_name = spec.entity_name
  let table_expr = match spec.table_name {
    Some(t) => "\"\{t}\""
    None =>
      match entity_name {
        Some(n) => "\{n}::table().name"
        None => "\"\""
      }
  }
  let struct_def =
    $| pub struct \{impl_name} {
    $|   engine : &@engine.Engine
    $| }
    $|
  let mapper_fn =
    $| pub fn \{impl_name}::new(engine : &@engine.Engine) -> \{impl_name} {
    $|   \{impl_name}::{ engine, }
    $| }
    $|
  let mut has_sync_methods = false
  for m in spec.methods {
    if !m.is_async {
      has_sync_methods = true
    }
  }
  let mapper_helpers = if has_sync_methods {
    (
      $| pub fn[Q : @engine.QueryBuilder] \{impl_name}::exec_query_sync(
      $|   self : \{impl_name},
      $|   q : Q,
      $| ) -> @engine.QueryResult {
      $|   let mut res : @engine.QueryResult = {
      $|     ok: false,
      $|     rows_affected: 0,
      $|     rows: [],
      $|     error: Some("async execution did not return"),
      $|   }
      $|   @async.run_async_main(() => {
      $|     res = @engine.exec_query(self.engine, q)
      $|   })
      $|   res
      $| }
      $|
      $| pub fn \{impl_name}::exec_raw_sync(
      $|   self : \{impl_name},
      $|   sql : String,
      $|   params : FixedArray[@engine.Param],
      $| ) -> @engine.QueryResult {
      $|   let mut res : @engine.QueryResult = {
      $|     ok: false,
      $|     rows_affected: 0,
      $|     rows: [],
      $|     error: Some("async execution did not return"),
      $|   }
      $|   @async.run_async_main(() => {
      $|     res = self.engine.exec_raw(sql, params)
      $|   })
      $|   res
      $| }
      $|
    )
  } else {
    ""
  }
  let mut impls = ""
  for m in spec.methods {
    let param_sig_parts : Array[String] = []
    let query_args_parts : Array[String] = []
    for p in m.params {
      let (pname, ptype) = p
      param_sig_parts.push("\{pname} : \{ptype}")
      query_args_parts.push("@engine.to_param(\{pname})")
    }
    let param_sig = if param_sig_parts.length() == 0 {
      "self"
    } else {
      "self, " + param_sig_parts.join(", ")
    }
    let query_args = "[" + query_args_parts.join(", ") + "]"
    // 返回类型字符串
    let ret_type = m.return_type
    let method_header =
      $| pub impl \{trait_name} for \{impl_name} with \{m.name}(
      $|   \{param_sig}
      $| ) -> \{ret_type} {
    let body = if m.name == "save" && m.params.length() == 1 {
      if m.returns_option {
        (
          $|   let q = @morm.upsert_into(\{table_expr}).from(entity)
          $|   let res = @engine.exec_query(self.engine, q)
          $|   if res.rows is [result, ..] {
          $|     return Some(try! @json.from_json(result))
          $|   }
          $|   None
          $| }
          $|
        )
      } else {
        let entity_ty = m.params[0].1
        (
          $|   let q = @morm.upsert_into(\{table_expr}).from(entity)
          $|   let res = @engine.exec_query(self.engine, q)
          $|   if res.rows is [result, ..] {
          $|     return (try! @json.from_json(result) : \{entity_ty})
          $|   }
          $|   panic()
          $| }
          $|
        )
      }
    } else if m.name == "delete" && m.params.length() == 1 {
      (
        $|   let q = @morm.delete_from(\{table_expr}).from(entity)
        $|   @engine.exec_query(self.engine, q).ok
        $| }
        $|
      )
    } else {
      match m.builder_code {
        Some(code) =>
          if m.returns_array {
            (
              $|   let q = \{code}
              $|   @engine.exec_query(self.engine, q).rows.map(row => @json.from_json(
              $|       row,
              $|     ) catch {
              $|       _ => panic()
              $|     },
              $|   )
              $| }
              $|
            )
          } else if m.returns_option {
            (
              $|   let q = \{code}
              $|   if @engine.exec_query(self.engine, q).rows
              $|     is [result, ..] {
              $|     return Some(try! @json.from_json(result))
              $|   }
              $|   None
              $| }
              $|
            )
          } else {
            (
              $|   let q = \{code}
              $|   if @engine.exec_query(self.engine, q).rows
              $|     is [result, ..] {
              $|     return (try! @json.from_json(result) : \{ret_type})
              $|   }
              $|   panic()
              $| }
              $|
            )
          }
        None => {
          let sql = m.sql.unwrap()
          if m.returns_array {
            (
              $|   self.engine.exec_raw("\{sql}", \{query_args}).rows.map(row => @json.from_json(
              $|       row,
              $|     ) catch {
              $|       _ => panic()
              $|     },
              $|   )
              $| }
              $|
            )
          } else if m.returns_option {
            (
              $|   if self.engine.exec_raw("\{sql}", \{query_args}).rows
              $|     is [result, ..] {
              $|     return Some(try! @json.from_json(result))
              $|   }
              $|   None
              $| }
              $|
            )
          } else {
            (
              $|   if self.engine.exec_raw("\{sql}", \{query_args}).rows
              $|     is [result, ..] {
              $|     return (try! @json.from_json(result) : \{ret_type})
              $|   }
              $|   panic()
              $| }
              $|
            )
          }
        }
      }
    }
    impls = impls + method_header + body
  }
  struct_def + mapper_fn + mapper_helpers + impls
}

///|
fn main {
  let argv = @sys.get_cli_args()
  let input_file = @ref.new("")
  let output_file = @ref.new("")
  let usage =
    #| MoonBit ORM CLI tool for generating database schema from Moonbit files
    #| usage: 
    #|      mormgen <input_file> -o <output_file>
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
  ) catch {
    e => {
      println("Error: \{e}")
      return
    }
  }
  try {
    let (ast, _) = @parser.parse_file(input_file.val)
    let source_content = @fs.read_file_to_string(input_file.val)
    let specs = parse_entities_from_ast(ast)
    let mapper_specs = parse_mappers_from_ast(ast, source_content, specs)
    //
    let codes : Array[String] = []
    specs.each(spec => {
      let table = transform_entity_to_table(spec, source_content)
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
