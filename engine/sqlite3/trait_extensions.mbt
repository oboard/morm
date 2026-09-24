///|
pub extend SqliteError with Debug::{to_repr}

///|
pub extend SQLiteEngine with @morm/engine.Engine::{
  page,
  exec_raw,
  close,
  page_raw,
  exec,
  migrate_table,
}

///|
pub extend SQLiteValue with Eq::{not_equal, equal}

///|
pub extend SQLiteValue with Show::{to_string, output}

///|
pub extend SQLiteValue with ToJson::{to_json}

///|
pub extend SQLiteValue with @json.FromJson::{from_json}

///|
pub extend SQLiteValue with @morm/engine.ToParam::{to_param}
