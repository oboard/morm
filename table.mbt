///|
pub type Table = @table.Table

///|
pub type ForeignKey = @table.ForeignKey

///|
pub fn new_table(
  name : String,
  columns? : FixedArray[Column],
  engine? : String,
) -> Table {
  {
    name,
    schema: None,
    catalog: None,
    columns: columns.unwrap_or([]),
    indexes: [],
    foreign_keys: [],
    temporary: false,
    if_not_exists: true,
    engine,
    charset: None,
    collation: None,
    tablespace: None,
    comment: "",
    auto_increment: None,
    engine_options: {},
  }
}

///|
pub fn table_primary_key(table : Table) -> String? {
  table.columns.fold(init=None, (acc, col) => {
    if col.primary_key {
      Some(col.name)
    } else {
      acc
    }
  })
}

///|
pub fn table_has_primary_key(table : Table) -> Bool {
  table_primary_key(table) is Some(_)
}
