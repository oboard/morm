///|
struct InsertAutoUser {
  id : Int
  name : String
  active : Bool
} derive(ToJson, FromJson)

///|
impl Entity for InsertAutoUser with table(_self) -> Table {
  new_table("insert_auto_user", columns=[
    { ..new_column("id", Int), primary_key: true, auto_increment: true },
    { ..new_column("name", VarChar(255)), nullable: false },
    { ..new_column("active", Boolean), nullable: false },
  ])
}

///|
impl @engine.FromParam for InsertAutoUser with from_param(_value) {
  raise @engine.ParamDecodeError("InsertAutoUser::from_param is unused")
}

///|
test "insert from skips auto increment columns" {
  let user = { id: 42, name: "Alice", active: true }
  let (sql, params) = @engine.render_query_sql(
    insert_into("insert_auto_user").from(user),
  )
  inspect(
    sql,
    content="INSERT INTO insert_auto_user (name, active) VALUES (?, ?)",
  )
  inspect(params.length(), content="2")
}

///|
test "insert from many skips auto increment columns" {
  let users : FixedArray[InsertAutoUser] = [
    { id: 42, name: "Alice", active: true },
    { id: 43, name: "Bob", active: false },
  ]
  let (sql, params) = @engine.render_query_sql(
    insert_into("insert_auto_user").from_many(users),
  )
  inspect(
    sql,
    content="INSERT INTO insert_auto_user (name, active) VALUES (?, ?), (?, ?)",
  )
  inspect(params.length(), content="4")
}
