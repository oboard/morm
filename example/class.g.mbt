///|
pub impl @morm.Entity for Class with table(_self) -> @morm.Table {
  Class::table()
}

///|
pub fn Class::table() -> @morm.Table {
  try! @json.from_json({
    "name": "class",
    "columns": [
      {
        "name": "id",
        "column_type": "Int",
        "size": 0,
        "nullable": false,
        "auto_increment": true,
        "primary_key": true,
        "unique": false,
        "comment": "",
      },
      {
        "name": "name",
        "column_type": ["VarChar", 255],
        "size": 0,
        "nullable": true,
        "auto_increment": false,
        "primary_key": false,
        "unique": false,
        "comment": "",
      },
      {
        "name": "teacher_id",
        "column_type": "Int",
        "size": 0,
        "nullable": true,
        "auto_increment": false,
        "primary_key": false,
        "unique": false,
        "comment": "",
      },
    ],
    "indexes": [],
    "foreign_keys": [
      {
        "name": "fk_Class_teacher_id",
        "column": "teacher_id",
        "referenced_table": "teacher",
        "referenced_column": "id",
        "on_delete": "CASCADE",
        "on_update": "RESTRICT",
      },
    ],
    "engine": "InnoDB",
    "charset": "utf8mb4",
    "collation": "utf8mb4_unicode_ci",
    "comment": "",
    "auto_increment": 1,
  })
}
