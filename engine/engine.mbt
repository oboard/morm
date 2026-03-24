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
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Where {
  col : String
  value : Param
  ty : WhereType
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) enum OrderBy {
  Asc(String)
  Desc(String)
} derive(Eq, Show, ToJson, FromJson)

///|
pub(all) struct Set {
  col : String
  value : Param
} derive(Eq, Show, ToJson, FromJson)

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
  /// Close the database connection.
  close(Self) -> Unit
}
