///|
#external
pub type Connection

///|
#external
priv type PreparedStatement

///|
#external
priv type NativeResult

///|
priv suberror DuckDBError {
  Message(String)
}

///|
priv struct QueryResult {
  columns : Array[String]
  column_types : Array[ColumnType]
  rows : Array[Array[String]]
  nulls : Array[Array[Bool]]
}

///|
priv enum ColumnType {
  Boolean
  TinyInt
  SmallInt
  Integer
  BigInt
  UTinyInt
  USmallInt
  UInteger
  UBigInt
  Float
  Double
  Timestamp
  HugeInt
  UHugeInt
  Blob
  Decimal
  TimestampS
  TimestampMs
  TimestampNs
  TimestampTz
  IntegerLiteral
  Unknown
}

///|
fn column_type_from_id(id : Int) -> ColumnType {
  match id {
    1 => Boolean
    2 => TinyInt
    3 => SmallInt
    4 => Integer
    5 => BigInt
    6 => UTinyInt
    7 => USmallInt
    8 => UInteger
    9 => UBigInt
    10 => Float
    11 => Double
    12 => Timestamp
    16 => HugeInt
    18 => Blob
    19 => Decimal
    20 => TimestampS
    21 => TimestampMs
    22 => TimestampNs
    31 => TimestampTz
    32 => UHugeInt
    38 => IntegerLiteral
    _ => Unknown
  }
}
