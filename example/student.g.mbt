///|
pub impl Entity for Student with table(_self) -> Table {
  Table::new("Student", columns=[
    Column::new("id", Int) |> primary_key |> auto_increment |> not_null,
    Column::new("name", VarChar(255)),
    Column::new("age", Int),
    Column::new("birth_date", DateTime),
  ])
}
