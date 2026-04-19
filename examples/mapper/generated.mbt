///|
pub impl @oboard/morm.Entity for User with table(_self) -> @oboard/morm.Table {
  User::table()
}

///|
pub fn User::table() -> @oboard/morm.Table {
  @oboard/morm.Table::{
    name: "user",
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
        name: "email",
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
        name: "active",
        column_type: Int,
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
pub fn User::_from(row : Map[String, @engine.Param]) -> User {
  let id_param = match row.get("id") {
    Some(value) => value
    None => panic()
  }
  let id : Int = (try! @engine.from_param(id_param) : Int)
  let email_param = match row.get("email") {
    Some(value) => value
    None => panic()
  }
  let email : String = (try! @engine.from_param(email_param) : String)
  let active_param = match row.get("active") {
    Some(value) => value
    None => panic()
  }
  let active : Int = (try! @engine.from_param(active_param) : Int)
  return User::{ id, email, active }
}

///|
pub impl @engine.FromParam for User with from_param(value) {
  match value {
    @engine.Object(obj) => {
      let row : Map[String, @engine.Param] = Map::new()
      for key in obj.keys() {
        if obj.get(key) is Some(value) {
          row.set(key, value)
        }
      }
      User::_from(row)
    }
    _ =>
      raise @engine.ParamDecodeError(
        "User::from_param: expected Json object row",
      )
  }
}

///|
pub struct UserMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn UserMapperImpl::new(engine : &@engine.Engine) -> UserMapperImpl {
  UserMapperImpl::{ engine, }
}

///|
pub impl UserMapper for UserMapperImpl with find_user_by_id(self, id : Int) -> User? {
  let q = @morm.select_from("user").where_eq("id", id)
  if self.engine.exec(q).rows is [result, ..] {
    return Some(User::_from(result))
  }
  None
}

///|
pub impl UserMapper for UserMapperImpl with find_users_by_active(
  self,
  active : Int,
) -> FixedArray[User] {
  self.engine.exec(@morm.select_from("user").where_eq("active", active)).rows.map(row => {
      User::_from(row)
    },
  )
}

///|
pub impl UserMapper for UserMapperImpl with find_users_page_by_active(
  self,
  active : Int,
  pageable : @engine.Pageable,
) -> @engine.Page[User] {
  @morm.paginate(
    self.engine,
    @morm.select_from("user").where_eq("active", active),
    pageable,
  )
}
