///|
pub impl Entity for Teacher with table(_self) -> Table {
  Table::new("Teacher", columns=[
    Column::new("id", Int) |> primary_key |> auto_increment |> not_null,
    Column::new("name", VarChar(255)),
    Column::new("major", VarChar(255)),
    Column::new("age", Int),
    Column::new("birth_date", DateTime),
  ])
}
