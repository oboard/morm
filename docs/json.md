# JSON Columns

`morm` treats `Json` and `JsonB` as first-class column types, but the final
storage type is chosen by each engine.

## Default Mapping

- MySQL: `JSON`
- PostgreSQL: `Json -> JSON`, `JsonB -> JSONB`
- SQLite: `TEXT`
- SQL Server: `NVARCHAR(MAX)`
- Oracle: `CLOB`

When a database does not have a strong native JSON type, the engine picks the
best fallback for that backend, such as text, blob, or engine-specific binary
storage.

## Column Override

You can override the default storage strategy with annotations:

```moonbit
#entity
pub(all) struct JsonDocument {
  #id
  id : Int64

  #json(storage="blob")
  payload : Json
} derive(ToJson, FromJson)
```

Supported `storage=` values:

- `json`
- `jsonb`
- `text`
- `string`
- `blob`
- `bson`

## Engine-Specific Results

The exact final DDL still depends on the current engine. For example:

- PostgreSQL: `jsonb` usually maps to `JSONB`
- SQLite: `blob` maps to `BLOB`
- SQL Server: `blob` / `bson` maps to `VARBINARY(MAX)`
- Oracle: `blob` / `bson` maps to `BLOB`

This keeps the default portable while still allowing per-column tuning when a
specific database needs a different JSON storage layout.
