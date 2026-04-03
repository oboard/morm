///|
fn enum_test_table() -> @table.Table {
  {
    name: "article",
    schema: None,
    catalog: None,
    columns: [
      {
        name: "status",
        column_type: @table.Enum("status", ["Draft", "Published"]),
        size: 0,
        nullable: false,
        default_value: Some("'Draft'"),
        auto_increment: false,
        primary_key: false,
        unique: false,
        comment: "",
        charset: None,
        collation: None,
        engine_options: [],
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
    engine_options: [],
  }
}

///|
test "postgres emits enum type DDL before create table" {
  let table = enum_test_table()
  inspect(
    pg_enum_type_sqls(table)[0],
    content=(
      #|DO $$ BEGIN CREATE TYPE status AS ENUM ('Draft', 'Published'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    ),
  )
  inspect(
    pg_create_table_sql(table).contains(
      "status status NOT NULL DEFAULT 'Draft'",
    ),
    content="true",
  )
}
