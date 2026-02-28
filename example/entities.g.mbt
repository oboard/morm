///|
pub impl @oboard/morm.Entity for Class with table(_self) -> @oboard/morm.Table {
  Class::table()
}

///|
pub fn Class::table() -> @morm.Table {
  @morm.Table::{
    name: "class",
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
      {
        name: "name",
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
      },
      {
        name: "teacher_id",
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
      },
      {
        name: "created_at",
        column_type: @morm.ColumnType::DateTime,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
      {
        name: "updated_at",
        column_type: @morm.ColumnType::DateTime,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
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
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
  }
}

///|
pub impl @oboard/morm.Entity for Student with table(_self) -> @oboard/morm.Table {
  Student::table()
}

///|
pub fn Student::table() -> @morm.Table {
  @morm.Table::{
    name: "student",
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
      {
        name: "name",
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
      },
      {
        name: "age",
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
      },
      {
        name: "birth_date",
        column_type: @morm.ColumnType::Timestamp,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
    ],
    indexes: [],
    foreign_keys: [],
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
  }
}

///|
pub impl @oboard/morm.Entity for Teacher with table(_self) -> @oboard/morm.Table {
  Teacher::table()
}

///|
pub fn Teacher::table() -> @morm.Table {
  @morm.Table::{
    name: "teacher",
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
      {
        name: "name",
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
      },
      {
        name: "major",
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
      },
      {
        name: "age",
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
      },
      {
        name: "birth_date",
        column_type: @morm.ColumnType::Timestamp,
        size: 0,
        nullable: true,
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
    ],
    indexes: [],
    foreign_keys: [],
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
  }
}

///|
pub impl @oboard/morm.Entity for Enrollment with table(_self) -> @oboard/morm.Table {
  Enrollment::table()
}

///|
pub fn Enrollment::table() -> @morm.Table {
  @morm.Table::{
    name: "enrollment",
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::BigInt,
        size: 0,
        nullable: false,
        auto_increment: true,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
      {
        name: "student_id",
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
      },
      {
        name: "class_id",
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
      },
      {
        name: "note",
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
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
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
    columns: [
      {
        name: "id",
        column_type: @morm.ColumnType::BigInt,
        size: 0,
        nullable: false,
        auto_increment: false,
        primary_key: true,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        default_value: None,
      },
    ],
    indexes: [],
    foreign_keys: [],
    engine: "InnoDB",
    charset: "utf8mb4",
    collation: "utf8mb4_unicode_ci",
    comment: "",
    auto_increment: 1,
  }
}
