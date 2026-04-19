///|
fn[T : ToJson] write_json_show(value : T, logger : &Logger) -> Unit {
  logger.write_string(value.to_json().stringify())
}

///|
pub fn bytes_to_hex(data : Bytes) -> String {
  let out = @buffer.new(size_hint=data.length() * 2)
  for b in data {
    let v = b.to_int()
    let hi = (v >> 4) & 0x0f
    let lo = v & 0x0f
    out.write_string(
      if hi < 10 {
        "\{hi}"
      } else {
        "\{('a'.to_int() + hi - 10).to_char()}"
      },
    )
    out.write_string(
      if lo < 10 {
        "\{lo}"
      } else {
        "\{('a'.to_int() + lo - 10).to_char()}"
      },
    )
  }
  out.to_string()
}

///|
pub fn decode_json_column(
  value : Json,
  storage : String,
) -> Json raise ParamDecodeError {
  match storage {
    "bson" =>
      match @bson.json_bytes_to_bytes(value) {
        Some(data) =>
          @bson.from_bytes(data) catch {
            @bson.BsonError(msg) =>
              raise ParamDecodeError("BSON decode error: \{msg}")
          }
        None => value
      }
    _ => value
  }
}

///|
pub fn param_row_from_json(row : Json) -> Map[String, Param] {
  let out : Map[String, Param] = Map::new()
  if row is Object(obj) {
    for key in obj.keys() {
      if obj.get(key) is Some(value) {
        out.set(key, to_param(value))
      }
    }
  }
  out
}

///|
pub(all) enum WhereType {
  Eq
  Ne
  Gt
  Lt
  Gte
  Lte
  Like
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for WhereType with output(self : WhereType, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) struct Where {
  col : String
  value : Param
  ty : WhereType
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Where with output(self : Where, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) enum OrderBy {
  Asc(String)
  Desc(String)
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for OrderBy with output(self : OrderBy, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(all) enum SortDirection {
  Asc
  Desc
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for SortDirection with output(
  self : SortDirection,
  logger : &Logger,
) {
  match self {
    Asc => logger.write_string("Asc")
    Desc => logger.write_string("Desc")
  }
}

///|
pub(all) struct Sort {
  property : String
  direction : SortDirection
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Sort with output(self : Sort, logger : &Logger) {
  match self.direction {
    Asc => logger.write_string("Sort(\{self.property} Asc)")
    Desc => logger.write_string("Sort(\{self.property} Desc)")
  }
}

///|
pub(all) struct Pageable {
  page : Int
  size : Int
  sort : Sort?
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Pageable with output(self : Pageable, logger : &Logger) {
  match self.sort {
    Some(s) =>
      logger.write_string(
        "Pageable(page=\{self.page}, size=\{self.size}, sort=\{s})",
      )
    None =>
      logger.write_string("Pageable(page=\{self.page}, size=\{self.size})")
  }
}

///|
pub(all) struct Page[T] {
  content : FixedArray[T]
  total_elements : Int
  total_pages : Int
  number : Int
  size : Int
  first : Bool
  last : Bool
  empty : Bool
} derive(Eq, ToJson, FromJson)

///|
pub impl[T] Show for Page[T] with output(self, logger) {
  logger.write_string(
    "Page(content=\{self.content.length()}, total_elements=\{self.total_elements}, total_pages=\{self.total_pages}, number=\{self.number}, size=\{self.size})",
  )
}

///|
pub(all) struct Set {
  col : String
  value : Param
} derive(Eq, ToJson, FromJson)

///|
pub impl Show for Set with output(self : Set, logger : &Logger) {
  write_json_show(self, logger)
}

///|
pub(open) trait QueryBuilder {
  to_query(Self) -> Query
}

///|
pub(open) trait Engine {
  /// Execute a normalized query model (statement/raw/transaction).
  async exec(Self, query : &QueryBuilder) -> QueryResult
  ///|
  /// Convenience wrapper for raw SQL; internally equivalent to exec(Query::Raw(...)).
  async exec_raw(Self, sql : String, params : FixedArray[Param]) -> QueryResult
  ///|
  /// Apply table migration from schema model.
  async migrate_table(Self, table_schema : @table.Table) -> QueryResult
  ///|
  /// Execute a paginated query and return a Page of results.
  /// The engine is responsible for applying dialect-specific pagination SQL.
  /// The count_query should return a single row with a single column representing total count.
  async exec_paginated(
    Self,
    query : &QueryBuilder,
    count_sql : String,
    page : Int,
    size : Int,
  ) -> Page[Map[String, Param]]
  ///|
  /// Close the database connection.
  close(Self) -> Unit
}
