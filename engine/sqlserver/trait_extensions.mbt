///|
pub extend SQLServerEngine with @morm/engine.Engine::{
  page,
  exec_raw,
  close,
  page_raw,
  exec,
  migrate_table,
}
