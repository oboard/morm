///|
pub struct BenchUser {
  id : Int
  email : String
  active : Int
} derive(ToJson, FromJson)

///|
pub struct BenchPost {
  id : Int
  user_id : Int
  title : String
  published : Int
} derive(ToJson, FromJson)

///|
pub impl @morm.Entity for BenchUser with table(_self) -> @morm.Table {
  BenchUser::table()
}

///|
pub impl @morm.Entity for BenchPost with table(_self) -> @morm.Table {
  BenchPost::table()
}

///|
pub fn BenchUser::table() -> @morm.Table {
  @morm.add_index(
    @morm.new_table("bench_user", columns=[
      { ..@morm.new_column("id", Int), primary_key: true, nullable: false },
      {
        ..@morm.new_column("email", VarChar(255)),
        unique: true,
        nullable: false,
      },
      { ..@morm.new_column("active", Int), nullable: false },
    ]),
    @morm.new_index("idx_bench_user_active", ["active"]),
  )
}

///|
pub fn BenchPost::table() -> @morm.Table {
  @morm.add_index(
    @morm.new_table("bench_post", columns=[
      { ..@morm.new_column("id", Int), primary_key: true, nullable: false },
      { ..@morm.new_column("user_id", Int), nullable: false },
      { ..@morm.new_column("title", VarChar(255)), nullable: false },
      { ..@morm.new_column("published", Int), nullable: false },
    ]),
    @morm.new_index("idx_bench_post_user_id", ["user_id"]),
  )
}

///|
fn bench_row_param(
  row : Map[String, @engine.Param],
  key : String,
) -> @engine.Param raise @engine.ParamDecodeError {
  match row.get(key) {
    Some(value) => value
    None =>
      raise @engine.ParamDecodeError(
        "benchmark row decode: missing column \{key}",
      )
  }
}

///|
fn bench_row_int(
  row : Map[String, @engine.Param],
  key : String,
) -> Int raise @engine.ParamDecodeError {
  match bench_row_param(row, key) {
    Int(value) => value
    Int16(value) => value.to_int()
    Int64(value) => value.to_int()
    BigInt(value) => value.to_int()
    UInt16(value) => value.to_int()
    Byte(value) => value.to_int()
    Json(Number(value, ..)) => value.to_int()
    _ =>
      raise @engine.ParamDecodeError(
        "benchmark row decode: expected Int-compatible column \{key}",
      )
  }
}

///|
fn bench_row_string(
  row : Map[String, @engine.Param],
  key : String,
) -> String raise @engine.ParamDecodeError {
  match bench_row_param(row, key) {
    String(value) => value
    Json(String(value)) => value
    _ =>
      raise @engine.ParamDecodeError(
        "benchmark row decode: expected String-compatible column \{key}",
      )
  }
}

///|
pub fn BenchUser::_from(row : Map[String, @engine.Param]) -> BenchUser {
  try! BenchUser::decode_from(row)
}

///|
fn BenchUser::decode_from(
  row : Map[String, @engine.Param],
) -> BenchUser raise @engine.ParamDecodeError {
  let id = bench_row_int(row, "id")
  let email = bench_row_string(row, "email")
  let active = bench_row_int(row, "active")
  { id, email, active }
}

///|
pub fn BenchPost::_from(row : Map[String, @engine.Param]) -> BenchPost {
  try! BenchPost::decode_from(row)
}

///|
fn BenchPost::decode_from(
  row : Map[String, @engine.Param],
) -> BenchPost raise @engine.ParamDecodeError {
  let id = bench_row_int(row, "id")
  let user_id = bench_row_int(row, "user_id")
  let title = bench_row_string(row, "title")
  let published = bench_row_int(row, "published")
  { id, user_id, title, published }
}

///|
pub impl @engine.FromParam for BenchUser with from_param(value) {
  match value {
    @engine.Object(obj) => BenchUser::decode_from(obj)
    @engine.Json(Object(obj)) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(v) {
          row.set(key, @engine.to_param(v))
        }
      }
      BenchUser::decode_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "BenchUser::from_param: expected object row",
      )
  }
}

///|
pub impl @engine.FromParam for BenchPost with from_param(value) {
  match value {
    @engine.Object(obj) => BenchPost::decode_from(obj)
    @engine.Json(Object(obj)) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(v) {
          row.set(key, @engine.to_param(v))
        }
      }
      BenchPost::decode_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "BenchPost::from_param: expected object row",
      )
  }
}
