///|
pub impl @oboard/morm.Entity for Class with table(_self) -> @oboard/morm.Table {
  Class::table()
}

///|
pub fn Class::table() -> @morm.Table {
  @morm.Table::{
    name: "class",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
      {
        name: "name",
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
        name: "teacher_id",
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
      {
        name: "created_at",
        column_type: DateTime,
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
        name: "updated_at",
        column_type: DateTime,
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
    foreign_keys: [
      {
        name: "fk_Class_teacher_id",
        column: "teacher_id",
        referenced_table: "teacher",
        referenced_column: "id",
        on_delete: "CASCADE",
        on_update: "RESTRICT",
      },
    ],
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
pub fn Class::from_row(row : Json) -> Class {
  if row is Object(obj) {
    let id_json = match obj.get("id") {
      Some(value) => value
      None => panic()
    }
    let id : Int64 = (
      try! @engine.from_param(@engine.param_from_json_value(id_json)) : Int64)
    let name_json = match obj.get("name") {
      Some(value) => value
      None => panic()
    }
    let name : String = (
      try! @engine.from_param(@engine.param_from_json_value(name_json)) : String)
    let teacher_id_json = match obj.get("teacher_id") {
      Some(value) => value
      None => panic()
    }
    let teacher_id : Int = (
      try! @engine.from_param(@engine.param_from_json_value(teacher_id_json)) :
      Int)
    let created_at_json = match obj.get("created_at") {
      Some(value) => value
      None => panic()
    }
    let created_at : PlainDateTime = (
      try! @engine.from_param(@engine.param_from_json_value(created_at_json)) :
      PlainDateTime)
    let updated_at_json = match obj.get("updated_at") {
      Some(value) => value
      None => panic()
    }
    let updated_at : PlainDateTime = (
      try! @engine.from_param(@engine.param_from_json_value(updated_at_json)) :
      PlainDateTime)
    return Class::{ id, name, teacher_id, created_at, updated_at }
  }
  panic()
}

///|
pub impl @oboard/morm.Entity for Student with table(_self) -> @oboard/morm.Table {
  Student::table()
}

///|
pub fn Student::table() -> @morm.Table {
  @morm.Table::{
    name: "student",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
      {
        name: "name",
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
        name: "age",
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
      {
        name: "birth_date",
        column_type: Timestamp,
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
pub fn Student::from_row(row : Json) -> Student {
  if row is Object(obj) {
    let id_json = match obj.get("id") {
      Some(value) => value
      None => panic()
    }
    let id : Int64 = (
      try! @engine.from_param(@engine.param_from_json_value(id_json)) : Int64)
    let name_json = match obj.get("name") {
      Some(value) => value
      None => panic()
    }
    let name : String = (
      try! @engine.from_param(@engine.param_from_json_value(name_json)) : String)
    let age_json = match obj.get("age") {
      Some(value) => value
      None => panic()
    }
    let age : Int = (
      try! @engine.from_param(@engine.param_from_json_value(age_json)) : Int)
    let birth_date_json = match obj.get("birth_date") {
      Some(value) => value
      None => panic()
    }
    let birth_date : ZonedDateTime = (
      try! @engine.from_param(@engine.param_from_json_value(birth_date_json)) :
      ZonedDateTime)
    return Student::{ id, name, age, birth_date }
  }
  panic()
}

///|
pub impl @oboard/morm.Entity for Teacher with table(_self) -> @oboard/morm.Table {
  Teacher::table()
}

///|
pub fn Teacher::table() -> @morm.Table {
  @morm.Table::{
    name: "teacher",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
      {
        name: "name",
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
        name: "major",
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
        name: "age",
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
      {
        name: "birth_date",
        column_type: Timestamp,
        size: 0,
        nullable: true,
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
pub fn Teacher::from_row(row : Json) -> Teacher {
  if row is Object(obj) {
    let id_json = match obj.get("id") {
      Some(value) => value
      None => panic()
    }
    let id : Int64 = (
      try! @engine.from_param(@engine.param_from_json_value(id_json)) : Int64)
    let name_json = match obj.get("name") {
      Some(value) => value
      None => panic()
    }
    let name : String = (
      try! @engine.from_param(@engine.param_from_json_value(name_json)) : String)
    let major_json = match obj.get("major") {
      Some(value) => value
      None => panic()
    }
    let major : String = (
      try! @engine.from_param(@engine.param_from_json_value(major_json)) :
      String)
    let age_json = match obj.get("age") {
      Some(value) => value
      None => panic()
    }
    let age : Int = (
      try! @engine.from_param(@engine.param_from_json_value(age_json)) : Int)
    let birth_date_json = match obj.get("birth_date") {
      Some(value) => value
      None => panic()
    }
    let birth_date : ZonedDateTime? = match birth_date_json {
      Null => None
      _ =>
        Some(
          (
            try! @engine.from_param(
              @engine.param_from_json_value(birth_date_json),
            ) : ZonedDateTime),
        )
    }
    return Teacher::{ id, name, major, age, birth_date }
  }
  panic()
}

///|
pub impl @oboard/morm.Entity for Enrollment with table(_self) -> @oboard/morm.Table {
  Enrollment::table()
}

///|
pub fn Enrollment::table() -> @morm.Table {
  @morm.Table::{
    name: "enrollment",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [],
      },
      {
        name: "student_id",
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
      {
        name: "class_id",
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
      {
        name: "note",
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
    ],
    indexes: [],
    foreign_keys: [
      {
        name: "fk_Enrollment_student",
        column: "student_id",
        referenced_table: "student",
        referenced_column: "id",
        on_delete: "CASCADE",
        on_update: "RESTRICT",
      },
      {
        name: "fk_Enrollment_klass",
        column: "class_id",
        referenced_table: "class",
        referenced_column: "id",
        on_delete: "RESTRICT",
        on_update: "RESTRICT",
      },
    ],
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
pub impl @oboard/morm.Entity for StudentAggregate with table(_self) -> @oboard/morm.Table {
  StudentAggregate::table()
}

///|
pub fn StudentAggregate::table() -> @morm.Table {
  @morm.Table::{
    name: "studentaggregate",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
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
pub impl @oboard/morm.Entity for JsonDocument with table(_self) -> @oboard/morm.Table {
  JsonDocument::table()
}

///|
pub fn JsonDocument::table() -> @morm.Table {
  @morm.Table::{
    name: "jsondocument",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: BigInt,
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
        name: "payload",
        column_type: Json,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
        engine_options: [{ key: "json.storage", value: "blob" }],
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
pub fn JsonDocument::from_row(row : Json) -> JsonDocument {
  if row is Object(obj) {
    let id_json = match obj.get("id") {
      Some(value) => value
      None => panic()
    }
    let id : Int64 = (
      try! @engine.from_param(@engine.param_from_json_value(id_json)) : Int64)
    let payload_json = match obj.get("payload") {
      Some(value) => value
      None => panic()
    }
    let payload : Json = (
      try! @engine.from_param(@engine.param_from_json_value(payload_json)) :
      Json)
    return JsonDocument::{ id, payload }
  }
  panic()
}
