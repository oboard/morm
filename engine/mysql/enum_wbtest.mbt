///|
fn enum_test_table() -> @table.Table {
  {
    name: "article",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "status",
        column_type: @table.Enum("Status", ["Draft", "Published"]),
        size: 0,
        nullable: false,
        default_value: Some("'Draft'"),
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        engine_options: {},
      },
    ],
    indexes: [],
    foreign_keys: [],
    temporary: false,
    if_not_exists: false,
    engine: None,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: {},
  }
}

///|
test "mysql renders native enum column type" {
  let sql = mysql_create_table_sql(enum_test_table())
  inspect(
    sql.contains("status ENUM('Draft', 'Published') NOT NULL DEFAULT 'Draft'"),
    content="true",
  )
}
