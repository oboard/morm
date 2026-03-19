///|
test "soft delete query helpers" {
  let scoped = @morm.select_from_scoped("users")
  let (sql1, params1) = @engine.render_query_sql(scoped)
  inspect(sql1, content="SELECT * FROM users WHERE deleted = ?")
  inspect(params1.to_json().stringify(), content="[false]")

  let del = @morm.soft_delete_by_id("users", "id", 42)
  let (sql2, params2) = @engine.render_query_sql(del)
  inspect(sql2, content="UPDATE users SET deleted = ? WHERE id = ?")
  inspect(params2.to_json().stringify(), content="[true,42]")

  let restore = @morm.restore_by_id("users", "id", 42, deleted_col="is_deleted")
  let (sql3, params3) = @engine.render_query_sql(restore)
  inspect(sql3, content="UPDATE users SET is_deleted = ? WHERE id = ?")
  inspect(params3.to_json().stringify(), content="[false,42]")
}

///|
test "hook callback helpers" {
  let before = @morm.before_create(1, x => x + 1)
  inspect(before, content="2")
  let after = @morm.after_update(before, x => x * 2)
  inspect(after, content="4")
  let deleted = @morm.before_delete(after, x => x - 1)
  inspect(deleted, content="3")
  let found = @morm.after_find(deleted, x => x + 10)
  inspect(found, content="13")
}

///|
test "table diff helpers" {
  let old_table = @morm.new_table("users", columns=[
    @morm.new_column("id", Int),
    @morm.new_column("name", VarChar(255)),
  ])
  let old_table = @morm.add_index(
    old_table,
    @morm.new_index("idx_name", ["name"]),
  )
  let old_table = @morm.add_foreign_key(
    old_table,
    @morm.new_foreign_key("fk_users_org", "org_id", "org", "id"),
  )

  let new_table = @morm.new_table("users", columns=[
    @morm.new_column("id", BigInt),
    @morm.new_column("email", VarChar(255)),
  ])
  let new_table = @morm.add_index(
    new_table,
    @morm.new_unique_index("idx_email", ["email"]),
  )
  let new_table = @morm.add_foreign_key(
    new_table,
    @morm.new_foreign_key("fk_users_dept", "dept_id", "dept", "id"),
  )

  let diff = @morm.diff_table(old_table, new_table)
  inspect(diff.columns.added.length(), content="1")
  inspect(diff.columns.removed.length(), content="1")
  inspect(diff.columns.changed.length(), content="1")
  inspect(diff.indexes.added.length(), content="1")
  inspect(diff.indexes.removed.length(), content="1")
  inspect(diff.foreign_keys.added.length(), content="1")
  inspect(diff.foreign_keys.removed.length(), content="1")
}

///|
test "driver registry helpers" {
  inspect(
    @morm.resolve_driver_name("jdbc:mysql://root@127.0.0.1:3306/test"),
    content="Some(\"mysql\")",
  )
  inspect(
    @morm.resolve_driver_name("postgres://postgres@127.0.0.1:5432/test"),
    content="Some(\"pgsql\")",
  )
  @morm.register_driver_scheme("dm", "oracle")
  inspect(
    @morm.resolve_driver_name("dm://sysdba@127.0.0.1:5236/test"),
    content="Some(\"oracle\")",
  )
  @morm.unregister_driver_scheme("dm")
  inspect(
    @morm.resolve_driver_name("dm://sysdba@127.0.0.1:5236/test"),
    content="None",
  )
}
