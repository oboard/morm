///|
#external
pub type Connection

///|
#external
priv type ConnectionRef

///|
extern "c" fn ConnectionRef::malloc() -> ConnectionRef = "moonbit_sqlite3_mkref"

///|
extern "c" fn ConnectionRef::read(self : ConnectionRef) -> Connection = "moonbit_sqlite3_readref"

///|
#owned(filename)
extern "c" fn sqlite3_open(filename : Bytes, out : ConnectionRef) -> Int = "sqlite3_open"

///|
extern "c" fn sqlite3_close(conn : Connection) -> Int = "sqlite3_close"

///|
#callsite(autofill(loc))
pub fn Connection::open(
  filename : String,
  loc~ : SourceLoc,
) -> Connection raise SqliteError {
  let buf = @buffer.new(size_hint=filename.length() * 2)
  buf.write_bytes(@encoding/utf8.encode(filename))
  buf.write_byte(0x00)
  let filename = buf.contents()
  let out = ConnectionRef::malloc()
  let rescode = sqlite3_open(filename, out)
  if rescode == SQLITE_OK {
    let sqlite3_object = out.read()
    return sqlite3_object
  } else {
    raise SqliteError((rescode, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::close(
  self : Connection,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_close(self)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
