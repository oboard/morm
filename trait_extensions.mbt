///|
pub extend DbError with ToJson::{to_json}

///|
pub extend DbError with Show::{to_string, output}

///|
pub extend Query with Eq::{not_equal, equal}

///|
pub extend Query with ToJson::{to_json}

///|
pub extend Query with @json.FromJson::{from_json}

///|
pub extend Query with Show::{to_string, output}

///|
pub extend AssociationKind with Eq::{not_equal, equal}

///|
pub extend AssociationKind with ToJson::{to_json}

///|
pub extend AssociationKind with @json.FromJson::{from_json}

///|
pub extend AssociationKind with Show::{to_string, output}

///|
pub extend Association with Eq::{not_equal, equal}

///|
pub extend Association with ToJson::{to_json}

///|
pub extend Association with @json.FromJson::{from_json}

///|
pub extend Association with Show::{to_string, output}

///|
pub extend Query with @morm/engine.QueryBuilder::{to_query}

///|
pub extend InsertQuery with Eq::{not_equal, equal}

///|
pub extend InsertQuery with ToJson::{to_json}

///|
pub extend InsertQuery with @json.FromJson::{from_json}

///|
pub extend InsertQuery with Show::{to_string, output}

///|
pub extend InsertQuery with @morm/engine.QueryBuilder::{to_query}

///|
pub extend UpsertQuery with Eq::{not_equal, equal}

///|
pub extend UpsertQuery with ToJson::{to_json}

///|
pub extend UpsertQuery with @json.FromJson::{from_json}

///|
pub extend UpsertQuery with Show::{to_string, output}

///|
pub extend UpsertQuery with @morm/engine.QueryBuilder::{to_query}

///|
pub extend UpdateQuery with Eq::{not_equal, equal}

///|
pub extend UpdateQuery with ToJson::{to_json}

///|
pub extend UpdateQuery with @json.FromJson::{from_json}

///|
pub extend UpdateQuery with Show::{to_string, output}

///|
pub extend UpdateQuery with @morm/engine.QueryBuilder::{to_query}

///|
pub extend DeleteQuery with Eq::{not_equal, equal}

///|
pub extend DeleteQuery with ToJson::{to_json}

///|
pub extend DeleteQuery with @json.FromJson::{from_json}

///|
pub extend DeleteQuery with Show::{to_string, output}

///|
pub extend DeleteQuery with @morm/engine.QueryBuilder::{to_query}

///|
pub extend TxQuery with Eq::{not_equal, equal}

///|
pub extend TxQuery with ToJson::{to_json}

///|
pub extend TxQuery with @json.FromJson::{from_json}

///|
pub extend TxQuery with Show::{to_string, output}

///|
pub extend TxQuery with @morm/engine.QueryBuilder::{to_query}

///|
pub extend ColumnDiff with ToJson::{to_json}

///|
pub extend ColumnDiff with Eq::{not_equal, equal}

///|
pub extend ColumnDiff with Show::{to_string, output}

///|
pub extend IndexDiff with ToJson::{to_json}

///|
pub extend IndexDiff with @json.FromJson::{from_json}

///|
pub extend IndexDiff with Eq::{not_equal, equal}

///|
pub extend IndexDiff with Show::{to_string, output}

///|
pub extend ForeignKeyDiff with ToJson::{to_json}

///|
pub extend ForeignKeyDiff with @json.FromJson::{from_json}

///|
pub extend ForeignKeyDiff with Eq::{not_equal, equal}

///|
pub extend ForeignKeyDiff with Show::{to_string, output}

///|
pub extend TableDiff with ToJson::{to_json}

///|
pub extend TableDiff with Eq::{not_equal, equal}

///|
pub extend TableDiff with Show::{to_string, output}
