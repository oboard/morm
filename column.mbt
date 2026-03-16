///|
pub type ColumnType = @table.ColumnType

///|
pub type ColumnEngineOption = @table.ColumnEngineOption

///|
pub type Column = @table.Column

///|
pub fn new_column(name : String, column_type : ColumnType) -> Column {
  {
    name,
    column_type,
    size: match column_type {
      VarChar(len) => len
      Char(len) => len
      Binary(len) => len
      VarBinary(len) => len
      _ => 0
    },
    nullable: true,
    default_value: None,
    auto_increment: false,
    primary_key: false,
    unique: false,
    comment: "",
    charset: None,
    collation: None,
    engine_options: [],
  }
}
