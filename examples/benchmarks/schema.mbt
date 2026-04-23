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
pub fn BenchUser::_from(row : Map[String, @engine.Param]) -> BenchUser {
  let id : Int = try! @engine.from_param(row.get("id").unwrap())
  let email : String = try! @engine.from_param(row.get("email").unwrap())
  let active : Int = try! @engine.from_param(row.get("active").unwrap())
  { id, email, active }
}

///|
pub fn BenchPost::_from(row : Map[String, @engine.Param]) -> BenchPost {
  let id : Int = try! @engine.from_param(row.get("id").unwrap())
  let user_id : Int = try! @engine.from_param(row.get("user_id").unwrap())
  let title : String = try! @engine.from_param(row.get("title").unwrap())
  let published : Int = try! @engine.from_param(row.get("published").unwrap())
  { id, user_id, title, published }
}

///|
pub impl @engine.FromParam for BenchUser with from_param(value) {
  match value {
    @engine.Object(obj) => BenchUser::_from(obj)
    @engine.Json(Object(obj)) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(v) {
          row.set(key, @engine.to_param(v))
        }
      }
      BenchUser::_from(row)
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
    @engine.Object(obj) => BenchPost::_from(obj)
    @engine.Json(Object(obj)) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(v) {
          row.set(key, @engine.to_param(v))
        }
      }
      BenchPost::_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "BenchPost::from_param: expected object row",
      )
  }
}
