///|
/// 变换阶段：从 EntitySpec 构建 @morm.Table，不接触解析细节
fn transform_entity_to_table(spec : EntitySpec, source : String) -> @morm.Table {
  let columns : Array[@morm.Column] = []
  let foreign_keys : Array[@morm.ForeignKey] = []
  for f in spec.fields {
    if field_is_one_to_many(f.attrs, source) {
      continue
    }
    let fk_col_opt = field_many_to_one_fk_column(f.label, f.attrs, source)
    let db_type = match fk_col_opt {
      Some(_) => @morm.ColumnType::Int
      None => map_type_to_db_by_name(f.field_type, f.attrs)
    }
    let (is_primary_key, is_auto_increment, _) = collect_field_flags(f.attrs)
    let is_nullable = f.nullable && !is_primary_key
    let col_name = match fk_col_opt {
      Some(n) => n
      None => f.label
    }
    let col : @morm.Column = {
      name: col_name,
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
fn escape_mbt_string(s : String) -> String {
  s
  .replace(old="\\", new="\\\\")
  .replace(old="\"", new="\\\"")
  .replace(old="\n", new="\\n")
  .replace(old="\r", new="\\r")
  .replace(old="\t", new="\\t")
}

///|
fn mbt_string(s : String) -> String {
  "\"" + escape_mbt_string(s) + "\""
}

///|
fn mbt_opt_string(v : String?) -> String {
  match v {
    Some(text) => "Some(" + mbt_string(text) + ")"
    None => "None"
  }
}

///|
fn mbt_opt_int(v : Int?) -> String {
  match v {
    Some(value) => "Some(" + value.to_string() + ")"
    None => "None"
  }
}

///|
fn render_column_type(ty : @morm.ColumnType) -> String {
  match ty {
    TinyInt => "@morm.ColumnType::TinyInt"
    SmallInt => "@morm.ColumnType::SmallInt"
    MediumInt => "@morm.ColumnType::MediumInt"
    Int => "@morm.ColumnType::Int"
    BigInt => "@morm.ColumnType::BigInt"
    Float => "@morm.ColumnType::Float"
    Double => "@morm.ColumnType::Double"
    Decimal(p, s) => "@morm.ColumnType::Decimal(\{p}, \{s})"
    Char(len) => "@morm.ColumnType::Char(\{len})"
    VarChar(len) => "@morm.ColumnType::VarChar(\{len})"
    Text => "@morm.ColumnType::Text"
    MediumText => "@morm.ColumnType::MediumText"
    LongText => "@morm.ColumnType::LongText"
    Binary(len) => "@morm.ColumnType::Binary(\{len})"
    VarBinary(len) => "@morm.ColumnType::VarBinary(\{len})"
    Blob => "@morm.ColumnType::Blob"
    MediumBlob => "@morm.ColumnType::MediumBlob"
    LongBlob => "@morm.ColumnType::LongBlob"
    Date => "@morm.ColumnType::Date"
    Time => "@morm.ColumnType::Time"
    DateTime => "@morm.ColumnType::DateTime"
    Timestamp => "@morm.ColumnType::Timestamp"
    Year => "@morm.ColumnType::Year"
    Json => "@morm.ColumnType::Json"
    JsonB => "@morm.ColumnType::JsonB"
    Boolean => "@morm.ColumnType::Boolean"
  }
}

///|
fn render_index_type(ty : @morm.IndexType) -> String {
  match ty {
    Primary => "@morm.IndexType::Primary"
    Unique => "@morm.IndexType::Unique"
    Index => "@morm.IndexType::Index"
    FullText => "@morm.IndexType::FullText"
    Spatial => "@morm.IndexType::Spatial"
  }
}

///|
fn render_column(col : @morm.Column) -> String {
  (
    $|      {
    $|        name: \{mbt_string(col.name)},
    $|        column_type: \{render_column_type(col.column_type)},
    $|        size: \{col.size},
    $|        nullable: \{col.nullable},
    $|        auto_increment: \{col.auto_increment},
    $|        primary_key: \{col.primary_key},
    $|        unique: \{col.unique},
    $|        comment: \{mbt_string(col.comment)},
    $|        charset: \{mbt_opt_string(col.charset)},
    $|        collation: \{mbt_opt_string(col.collation)},
    $|        default_value: \{mbt_opt_string(col.default_value)},
    $|      }
  )
}

///|
fn render_index(idx : @morm.Index) -> String {
  let cols = idx.columns.map(c => mbt_string(c)).join(", ")
  (
    $|      {
    $|        name: \{mbt_string(idx.name)},
    $|        index_type: \{render_index_type(idx.index_type)},
    $|        columns: [\{cols}],
    $|        comment: \{mbt_string(idx.comment)},
    $|      }
  )
}

///|
fn render_foreign_key(fk : @morm.ForeignKey) -> String {
  (
    $|      {
    $|        name: \{mbt_string(fk.name)},
    $|        column: \{mbt_string(fk.column)},
    $|        referenced_table: \{mbt_string(fk.referenced_table)},
    $|        referenced_column: \{mbt_string(fk.referenced_column)},
    $|        on_delete: \{mbt_string(fk.on_delete)},
    $|        on_update: \{mbt_string(fk.on_update)},
    $|      }
  )
}

///|
fn render_table_engine_option(option : @morm.TableEngineOption) -> String {
  (
    $|      {
    $|        key: \{mbt_string(option.key)},
    $|        value: \{mbt_string(option.value)},
    $|      }
  )
}

///|
fn render_table_literal(table : @morm.Table) -> String {
  let columns = table.columns.map(render_column).join(",\n")
  let indexes = table.indexes.map(render_index).join(",\n")
  let foreign_keys = table.foreign_keys.map(render_foreign_key).join(",\n")
  let engine_options = table.engine_options
    .map(render_table_engine_option)
    .join(",\n")
  (
    $| @morm.Table::{
    $|   name: \{mbt_string(table.name)},
    $|   schema: \{mbt_opt_string(table.schema)},
    $|   catalog: \{mbt_opt_string(table.catalog)},
    $|   columns: [
    $|\{columns}
    $|   ],
    $|   indexes: [
    $|\{indexes}
    $|   ],
    $|   foreign_keys: [
    $|\{foreign_keys}
    $|   ],
    $|   temporary: \{table.temporary},
    $|   if_not_exists: \{table.if_not_exists},
    $|   engine: \{mbt_opt_string(table.engine)},
    $|   charset: \{mbt_opt_string(table.charset)},
    $|   collation: \{mbt_opt_string(table.collation)},
    $|   tablespace: \{mbt_opt_string(table.tablespace)},
    $|   comment: \{mbt_string(table.comment)},
    $|   auto_increment: \{mbt_opt_int(table.auto_increment)},
    $|   engine_options: [
    $|\{engine_options}
    $|   ],
    $| }
  )
}

///|
/// 代码生成阶段：从表结构生成实现代码
fn generate_entity_impl(name : String, table : @morm.Table) -> String {
  let table_literal = render_table_literal(table)
  (
    $| pub impl @oboard/morm.Entity for \{name} with table(_self) -> @oboard/morm.Table { \{name}::table() }
    $| pub fn \{name}::table() -> @morm.Table {
    $|\{table_literal}
    $| }
  )
}

///|
fn find_entity_spec(specs : Array[EntitySpec], name : String) -> EntitySpec? {
  for spec in specs {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
fn find_entity_spec_by_table(
  specs : Array[EntitySpec],
  table_name : String,
) -> EntitySpec? {
  for spec in specs {
    if spec.table_name == table_name {
      return Some(spec)
    }
  }
  None
}

///|
fn field_has_attr(field : FieldSpec, attr_name : String) -> Bool {
  let orm_attrs = collect_orm_attributes(field.attrs)
  let mut hit = false
  orm_attrs.each(a => if a.name == attr_name { hit = true })
  hit
}

///|
fn field_auto_create_time(field : FieldSpec) -> Bool {
  field_has_attr(field, "#morm.auto_create_time") || field.label == "created_at"
}

///|
fn field_auto_update_time(field : FieldSpec) -> Bool {
  field_has_attr(field, "#morm.auto_update_time") || field.label == "updated_at"
}

///|
fn auto_time_value_expr(field : FieldSpec) -> String? {
  let base = match field.field_type {
    "PlainDateTime" | "DateTime" => Some("@morm.current_plain_date_time_utc()")
    "ZonedDateTime" | "Timestamp" => Some("@morm.current_timestamp_utc()")
    _ => None
  }
  match base {
    Some(expr) =>
      if field.nullable {
        Some("Some(" + expr + ")")
      } else {
        Some(expr)
      }
    None => None
  }
}

///|
fn path_dirname(path : String) -> String {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  let cut = match (slash, backslash) {
    (Some(a), Some(b)) => Some(if a > b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
  match cut {
    Some(0) => "/"
    Some(idx) => path[0:idx].to_string() catch { _ => "." }
    None => "."
  }
}

///|
fn path_join(dir : String, name : String) -> String {
  if dir == "." || dir == "" {
    name
  } else if dir == "/" {
    "/" + name
  } else {
    dir + "/" + name
  }
}

///|
fn is_source_mbt_file(name : String) -> Bool {
  name.has_suffix(".mbt") &&
  !name.has_suffix(".g.mbt") &&
  !name.has_suffix("_test.mbt") &&
  !name.has_suffix("_wbtest.mbt")
}

///|
fn collect_package_entity_specs(
  input_file : String,
) -> Array[EntitySpec] raise @fs.IOError {
  let dir = path_dirname(input_file)
  let merged : Array[EntitySpec] = []
  let seen : Map[String, Bool] = Map::new()
  for entry in @fs.read_dir(dir) {
    if !is_source_mbt_file(entry) {
      continue
    }
    let path = path_join(dir, entry)
    guard @fs.is_file(path) else { continue }
    let (file_ast, _) = @parser.parse_file(path)
    for spec in parse_entities_from_ast(file_ast) {
      if seen.contains(spec.name) {
        continue
      }
      seen.set(spec.name, true)
      merged.push(spec)
    }
  }
  merged
}

///|
/// 代码生成阶段：根据 MapperSpec 生成 struct、mapper 函数与方法实现
fn generate_mapper_code(
  spec : MapperSpec,
  entity_specs : Array[EntitySpec],
) -> String {
  let trait_name = spec.trait_name
  let impl_name = trait_name + "Impl"
  let entity_name = spec.entity_name
  let entity_spec = match entity_name {
    Some(name) => find_entity_spec(entity_specs, name)
    None => None
  }
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
      let save_entity_spec = match entity_spec {
        Some(spec) => Some(spec)
        None =>
          match find_entity_spec(entity_specs, m.params[0].1) {
            Some(spec) => Some(spec)
            None =>
              match spec.table_name {
                Some(table_name) =>
                  find_entity_spec_by_table(entity_specs, table_name)
                None => None
              }
          }
      }
      let auto_assigns : Array[String] = []
      match save_entity_spec {
        Some(save_spec) =>
          for field in save_spec.fields {
            if field_auto_create_time(field) || field_auto_update_time(field) {
              match auto_time_value_expr(field) {
                Some(expr) => auto_assigns.push(field.label + ": " + expr)
                None => ()
              }
            }
          }
        None => ()
      }
      let auto_stamp_code = if auto_assigns.length() > 0 {
        let assigns = auto_assigns.join(", ")
        (
          $|   let entity = {
          $|     ..entity,
          $|     \{assigns},
          $|   }
        )
      } else {
        ""
      }
      if m.returns_option {
        (
          $|\{auto_stamp_code}
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
          $|\{auto_stamp_code}
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
      let builder_code_with_fetch = match m.fetch_join {
        Some(join_sql) => {
          let join_escaped = join_sql.replace(old="\"", new="\\\"")
          match m.builder_code {
            Some(code) => Some(code + ".join(\"" + join_escaped + "\")")
            None => None
          }
        }
        None => m.builder_code
      }
      match m.builder_code {
        Some(_) =>
          match builder_code_with_fetch {
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
            None => panic()
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
    let all_entity_specs = collect_package_entity_specs(input_file.val)
    let mapper_specs = parse_mappers_from_ast(
      ast, source_content, all_entity_specs,
    )
    //
    let codes : Array[String] = []
    specs.each(spec => {
      let table = transform_entity_to_table(spec, source_content)
      let code = generate_entity_impl(spec.name, table)
      codes.push(code)
    })
    mapper_specs.each(ms => {
      let mcode = generate_mapper_code(ms, all_entity_specs)
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
