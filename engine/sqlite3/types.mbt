///|
pub(all) enum SQLiteValue {
  Null
  Integer(Int64)
  Real(Double)
  Text(String)
  Blob(Bytes)
} derive(Eq, Show)

///|
pub impl ToJson for SQLiteValue with to_json(self) -> Json {
  match self {
    Null => Json::null()
    Integer(v) => v.to_json()
    Real(v) => v.to_json()
    Text(v) => v.to_json()
    Blob(v) => v.to_json()
  }
}

///|
pub impl @json.FromJson for SQLiteValue with from_json(json, path) {
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
      raise @json.JsonDecodeError(
        (path, "SQLiteValue::from_json: expected null/bool/number/string"),
      )
  }
}

///|
pub impl @engine.ToParam for SQLiteValue with to_param(self) -> @engine.Param {
  match self {
    Null => @engine.Null
    Integer(v) => @engine.Int64(v)
    Real(v) => @engine.Double(v)
    Text(v) => @engine.String(v)
    Blob(v) => @engine.Bytes(v)
  }
}
