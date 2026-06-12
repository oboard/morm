///|
pub(all) enum SQLiteValue {
  Null
  Integer(Int64)
  Real(Double)
  Text(String)
  Blob(Bytes)
} derive(Eq)

///|
pub impl Show for SQLiteValue with fn output(
  self : SQLiteValue,
  logger : &Logger,
) {
  logger.write_string(self.to_json().stringify())
}

///|
pub impl ToJson for SQLiteValue with fn to_json(self) -> Json {
  match self {
    Null => Json::null()
    Integer(v) => v.to_json()
    Real(v) => v.to_json()
    Text(v) => v.to_json()
    Blob(v) => v.to_json()
  }
}

///|
pub impl @json.FromJson for SQLiteValue with fn from_json(json, path) {
  match json {
    Null => Null
    True => Integer(1)
    False => Integer(0)
    Number(n, ..) =>
      if n.to_int().to_double() == n {
        Integer(n.to_int().to_int64())
      } else {
        Real(n)
      }
    String(s) => Text(s)
    _ =>
      raise JsonDecodeError(
        (path, "SQLiteValue::from_json: expected null/bool/number/string"),
      )
  }
}

///|
pub impl @morm/engine.ToParam for SQLiteValue with fn to_param(self) -> @morm/engine.Param {
  match self {
    Null => Null
    Integer(v) => Int64(v)
    Real(v) => Double(v)
    Text(v) => String(v)
    Blob(v) => Bytes(v)
  }
}
