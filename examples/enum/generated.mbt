///|
pub impl @engine.ToParam for PostStatus with to_param(self) -> @engine.Param {
  try! @engine.enum_to_param(self)
}

///|
pub impl @engine.FromParam for PostStatus with from_param(value) {
  try! @engine.enum_from_param(value)
}

///|
pub impl @oboard/morm.Entity for Post with table(_self) -> @oboard/morm.Table {
  Post::table()
}

///|
pub fn Post::table() -> @oboard/morm.Table {
  @oboard/morm.Table::{
    name: "post",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: Int,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [{ key: "pk.strategy", value: "auto_increment" }],
      },
      {
        name: "title",
        column_type: VarChar(255),
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
      {
        name: "status",
        column_type: Enum("PostStatus", ["Draft", "Published", "Archived"]),
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
    ],
    indexes: [],
    foreign_keys: [],
    temporary: false,
    if_not_exists: true,
    engine: None,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: [],
  }
}

///|
pub fn Post::_from(row : Map[String, @engine.Param]) -> Post {
  let id_param = match row.get("id") {
    Some(value) => value
    None => panic()
  }
  let id : Int = (try! @engine.from_param(id_param) : Int)
  let title_param = match row.get("title") {
    Some(value) => value
    None => panic()
  }
  let title : String = (try! @engine.from_param(title_param) : String)
  let status_param = match row.get("status") {
    Some(value) => value
    None => panic()
  }
  let status : PostStatus = (try! @engine.from_param(status_param) : PostStatus)
  return Post::{ id, title, status }
}

///|
pub impl @engine.FromParam for Post with from_param(value) {
  match value {
    @engine.Json(Object(obj)) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(value) {
          row.set(key, @engine.to_param(value))
        }
      }
      Post::_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "Post::from_param: expected Json object row",
      )
  }
}
