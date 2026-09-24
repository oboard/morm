///|
pub extend WhereType with Eq::{not_equal, equal}

///|
pub extend WhereType with ToJson::{to_json}

///|
pub extend WhereType with @json.FromJson::{from_json}

///|
pub extend WhereType with Show::{to_string, output}

///|
pub extend Where with Eq::{not_equal, equal}

///|
pub extend Where with ToJson::{to_json}

///|
pub extend Where with @json.FromJson::{from_json}

///|
pub extend Where with Show::{to_string, output}

///|
pub extend OrderBy with Eq::{not_equal, equal}

///|
pub extend OrderBy with ToJson::{to_json}

///|
pub extend OrderBy with @json.FromJson::{from_json}

///|
pub extend OrderBy with Show::{to_string, output}

///|
pub extend SortDirection with Debug::{to_repr}

///|
pub extend SortDirection with Eq::{not_equal, equal}

///|
pub extend SortDirection with ToJson::{to_json}

///|
pub extend SortDirection with @json.FromJson::{from_json}

///|
pub extend SortDirection with Show::{to_string, output}

///|
pub extend Sort with Debug::{to_repr}

///|
pub extend Sort with Eq::{not_equal, equal}

///|
pub extend Sort with ToJson::{to_json}

///|
pub extend Sort with @json.FromJson::{from_json}

///|
pub extend Sort with Show::{to_string, output}

///|
pub extend Pageable with Debug::{to_repr}

///|
pub extend Pageable with Eq::{not_equal, equal}

///|
pub extend Pageable with ToJson::{to_json}

///|
pub extend Pageable with @json.FromJson::{from_json}

///|
pub extend Pageable with Show::{to_string, output}

///|
pub extend Page with Eq::{not_equal, equal}

///|
pub extend Page with ToJson::{to_json}

///|
pub extend Page with @json.FromJson::{from_json}

///|
pub extend Page with Show::{to_string, output}

///|
pub extend Set with Eq::{not_equal, equal}

///|
pub extend Set with ToJson::{to_json}

///|
pub extend Set with @json.FromJson::{from_json}

///|
pub extend Set with Show::{to_string, output}

///|
pub extend Param with Show::{to_string, output}

///|
pub extend ParamDecodeError with Eq::{not_equal, equal}

///|
pub extend ParamDecodeError with ToJson::{to_json}

///|
pub extend ParamDecodeError with Show::{to_string, output}

///|
pub extend Param with @json.FromJson::{from_json}

///|
pub extend Param with Eq::{not_equal, equal}

///|
pub extend Param with ToJson::{to_json}

///|
pub extend Param with FromParam::{from_param}

///|
pub extend Page with FromParam::{from_param}

///|
pub extend Param with ToParam::{to_param}

///|
pub extend QueryResult with ToJson::{to_json}

///|
pub extend QueryResult with @json.FromJson::{from_json}

///|
pub extend QueryResult with Eq::{not_equal, equal}

///|
pub extend QueryResult with Show::{to_string, output}

///|
pub extend SelectStatement with Eq::{not_equal, equal}

///|
pub extend SelectStatement with ToJson::{to_json}

///|
pub extend SelectStatement with @json.FromJson::{from_json}

///|
pub extend SelectStatement with Show::{to_string, output}

///|
pub extend InsertStatement with Eq::{not_equal, equal}

///|
pub extend InsertStatement with ToJson::{to_json}

///|
pub extend InsertStatement with @json.FromJson::{from_json}

///|
pub extend InsertStatement with Show::{to_string, output}

///|
pub extend UpsertStatement with Eq::{not_equal, equal}

///|
pub extend UpsertStatement with ToJson::{to_json}

///|
pub extend UpsertStatement with @json.FromJson::{from_json}

///|
pub extend UpsertStatement with Show::{to_string, output}

///|
pub extend UpdateStatement with Eq::{not_equal, equal}

///|
pub extend UpdateStatement with ToJson::{to_json}

///|
pub extend UpdateStatement with @json.FromJson::{from_json}

///|
pub extend UpdateStatement with Show::{to_string, output}

///|
pub extend DeleteStatement with Eq::{not_equal, equal}

///|
pub extend DeleteStatement with ToJson::{to_json}

///|
pub extend DeleteStatement with @json.FromJson::{from_json}

///|
pub extend DeleteStatement with Show::{to_string, output}

///|
pub extend Statement with Eq::{not_equal, equal}

///|
pub extend Statement with ToJson::{to_json}

///|
pub extend Statement with @json.FromJson::{from_json}

///|
pub extend Statement with Show::{to_string, output}

///|
pub extend TxOp with Eq::{not_equal, equal}

///|
pub extend TxOp with ToJson::{to_json}

///|
pub extend TxOp with @json.FromJson::{from_json}

///|
pub extend TxOp with Show::{to_string, output}

///|
pub extend Query with Eq::{not_equal, equal}

///|
pub extend Query with ToJson::{to_json}

///|
pub extend Query with @json.FromJson::{from_json}

///|
pub extend Query with Show::{to_string, output}

///|
pub extend Query with QueryBuilder::{to_query}
