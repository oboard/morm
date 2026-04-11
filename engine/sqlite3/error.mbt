///|
pub suberror SqliteError {
  SqliteError((Int, SourceLoc))
}

///|
pub impl Show for SqliteError with output(self : SqliteError, logger : &Logger) {
  match self {
    SqliteError((code, _)) => logger.write_string("SqliteError(\{code})")
  }
}

///|
extern "c" fn sqlite3_errmsg(conn : Connection) -> Bytes = "moonbit_sqlite3_errmsg"

///|
pub fn Connection::get_errmsg(conn : Connection) -> String {
  let utf8str = sqlite3_errmsg(conn)
  @encoding/utf8.decode_lossy(utf8str)
}
