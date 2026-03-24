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
        column_type: Int,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
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
pub fn User::from_row(row : Map[String, @engine.Param]) -> User {
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
  User::{ id, email, active }
}
