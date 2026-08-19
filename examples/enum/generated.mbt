///|
pub impl @morm/engine.ToParam for PostStatus with fn to_param(self) -> @morm/engine.Param {
  try! @morm/engine.enum_to_param(self)
}

///|
pub impl @morm/engine.FromParam for PostStatus with fn from_param(value) {
  try! @morm/engine.enum_from_param(value)
}

///|
pub impl @morm.Entity for Post with fn table(_self) -> @morm.Table {
  Post::table()
}

///|
pub fn Post::table() -> @morm.Table {
  {
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
        engine_options: { "pk.strategy": ["auto_increment"] },
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
        engine_options: Map([]),
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
        engine_options: Map([]),
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
    engine_options: Map([]),
  }
}

///|
pub fn Post::_from(row : Map[String, @morm/engine.Param]) -> Post {
  let id_param = match row.get("id") {
    Some(value) => value
    None => panic()
  }
  let id : Int = (try! @morm/engine.from_param(id_param) : Int)
  let title_param = match row.get("title") {
    Some(value) => value
    None => panic()
  }
  let title : String = (try! @morm/engine.from_param(title_param) : String)
  let status_param = match row.get("status") {
    Some(value) => value
    None => panic()
  }
  let status : PostStatus = (
    try! @morm/engine.from_param(status_param) : PostStatus)
  return { id, title, status }
}

///|
pub impl @morm/engine.FromParam for Post with fn from_param(value) {
  match value {
    Object(obj) => {
      let row : Map[String, @morm/engine.Param] = Map([])
      for key in obj.keys() {
        if obj.get(key) is Some(value) {
          row.set(key, value)
        }
      }
      Post::_from(row)
    }
    _ => raise ParamDecodeError("Post::from_param: expected Json object row")
  }
}
