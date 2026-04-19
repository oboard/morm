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

///|
fn privilege_test_table() -> @table.Table {
  {
    name: "article",
    schema: Some("app"),
    catalog: None,
    columns: [
      {
        name: "id",
        column_type: @table.Int,
        size: 0,
        nullable: false,
        default_value: None,
        auto_increment: true,
        primary_key: true,
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
    if_not_exists: true,
    engine: None,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: [
      { key: "pgsql.schema.authorization", value: "app_owner" },
      { key: "pgsql.table.owner", value: "app_owner" },
      {
        key: "pgsql.grant.schema",
        value: "role=app_reader;privileges=USAGE;grant_option=false",
      },
      {
        key: "pgsql.grant.table",
        value: "role=app_reader;privileges=SELECT;grant_option=false",
      },
      {
        key: "pgsql.grant.table_sequence",
        value: "role=app_writer;privileges=USAGE, SELECT;grant_option=true",
      },
      {
        key: "pgsql.grant.sequence",
        value: "role=app_reader;privileges=USAGE;grant_option=false",
      },
      {
        key: "pgsql.default_grant.table",
        value: "role=app_reader;privileges=SELECT;grant_option=false;for_role=app_owner",
      },
      {
        key: "pgsql.default_grant.sequence",
        value: "role=app_writer;privileges=USAGE, SELECT;grant_option=true;for_role=app_owner",
      },
    ],
  }
}

///|
test "postgres renders schema ownership and privilege DDL" {
  let table = privilege_test_table()
  inspect(
    pg_schema_sqls(table).to_json().stringify(),
    content=(
      #|["CREATE SCHEMA IF NOT EXISTS app AUTHORIZATION app_owner","GRANT USAGE ON SCHEMA app TO app_reader"]
    ),
  )
  inspect(
    pg_post_create_sqls(table).to_json().stringify(),
    content=(
      #|["ALTER TABLE app.article OWNER TO app_owner","GRANT SELECT ON TABLE app.article TO app_reader","DO $$ DECLARE seq_name text; BEGIN seq_name := pg_get_serial_sequence('app.article', 'id'); IF seq_name IS NOT NULL THEN EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE ' || seq_name || ' TO app_writer WITH GRANT OPTION'; END IF; END $$;","GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO app_reader","ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app GRANT SELECT ON TABLES TO app_reader","ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA app GRANT USAGE, SELECT ON SEQUENCES TO app_writer WITH GRANT OPTION"]
    ),
  )
}
