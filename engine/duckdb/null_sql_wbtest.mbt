///|
test "duckdb renders null predicates and returning statements" {
  let select_query = @morm/engine.Statement(
    Select({
      select: "*",
      from: "items",
      joins: [],
      where_: [{ col: "id", value: Null, ty: Eq, }],
      order_by: [],
      limit: None,
      offset: None,
    }),
  )
  let (sql, params) = render_duckdb(select_query)
  inspect(sql, content="SELECT * FROM items WHERE id IS NULL")
  inspect(params.length(), content="0")

  let upsert_query = @morm/engine.Statement(
    Upsert({
      table: "items",
      sets: [
        { col: "id", value: Int(1), },
        { col: "name", value: String("new"), },
      ],
      conflict_target: ["id"],
      update_sets: [{ col: "name", value: String("updated"), }],
    }),
  )
  let (sql, params) = render_duckdb(upsert_query)
  inspect(
    sql,
    content="INSERT INTO items (id, name) VALUES (?, ?) ON CONFLICT (id) DO UPDATE SET name = ? RETURNING *",
  )
  json_inspect(params, content=[1, "new", "updated"])
}
