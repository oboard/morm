///|
pub suberror SqliteError {
  SqliteError((Int, SourceLoc))
}

///|
pub impl Debug for SqliteError with to_repr(self) {
  match self {
    SqliteError((code, _)) =>
      Repr::ctor("SqliteError", [(None, Repr::integer(code.to_string()))])
  }
}

///|
pub fn SqliteError::message(self : SqliteError) -> String {
  match self {
    SqliteError((code, _)) => "SqliteError(\{code})"
  }
}

///|
extern "c" fn sqlite3_errmsg(conn : Connection) -> Bytes = "moonbit_sqlite3_errmsg"

///|
pub fn Connection::get_errmsg(conn : Connection) -> String {
  let utf8str = sqlite3_errmsg(conn)
  @encoding/utf8.decode_lossy(utf8str)
}
