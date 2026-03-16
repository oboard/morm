///|
pub impl @oboard/morm.Entity for User with table(_self) -> @oboard/morm.Table {
  User::table()
}

///|
pub fn User::table() -> @morm.Table {
  @morm.Table::{
    name: "user",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::Int,
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
        column_type: @morm.ColumnType::VarChar(255),
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
        column_type: @morm.ColumnType::Int,
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
pub fn User::from_row(row : Json) -> User {
  if row is Object(obj) {
    let id_json = match obj.get("id") {
      Some(value) => value
      None => panic()
    }
    let id : Int = (
      try! @engine.from_param(@engine.param_from_json_value(id_json)) : Int)
    let email_json = match obj.get("email") {
      Some(value) => value
      None => panic()
    }
    let email : String = (
      try! @engine.from_param(@engine.param_from_json_value(email_json)) :
      String)
    let active_json = match obj.get("active") {
      Some(value) => value
      None => panic()
    }
    let active : Int = (
      try! @engine.from_param(@engine.param_from_json_value(active_json)) : Int)
    return User::{ id, email, active }
  }
  panic()
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
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(User::from_row(result))
  }
  None
}

///|
pub impl UserMapper for UserMapperImpl with find_users_by_active(
  self,
  active : Int,
) -> FixedArray[User] {
  let q = @morm.select_from("user").where_eq("active", active)
  @engine.exec_query(self.engine, q).rows.map(row => User::from_row(row))
}
