---
outline: deep
---

# PostgreSQL Engine

PostgreSQL is ideal when you need strong consistency, rich SQL features, and advanced data modeling capabilities.

## Package Import

```moonbit
using @oboard/morm/engine/postgres as @pgsql
```

## DSN and Connection

```moonbit
let engine = match
  @pgsql.PgSQLEngine::open("postgres://postgres@127.0.0.1:5432/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

For production, use dedicated users and explicit SSL settings that match your environment.

## Placeholders and Parameters

- Uses `$1`, `$2`, `$3` positional placeholders
- Parameter values are represented via `@engine.Param`
- Safe parameter binding avoids SQL injection from dynamic values

## Transactions and Savepoints

- Supports full transaction lifecycle
- Supports savepoints and rollback-to-savepoint
- Well suited for complex multi-step business operations

## Schema Ownership and Authorization

Use entity annotations to set PostgreSQL schema ownership:

```moonbit
#morm.postgres.schema("app_schema", authorization="app_owner")
pub(all) struct Product {
  #morm.id
  id : Int64
  ...
}
```

## Table Options

```moonbit
#morm.postgres.table(
  name="products",
  owner="app_user",
  tablespace="pg_default",
  unlogged=false,
  on_commit="PRESERVE ROWS"
)
pub(all) struct Product { ... }
```

Supported options:
- `owner` - set table owner role
- `tablespace` - specify tablespace
- `unlogged` - create as unlogged table
- `on_commit` - `PRESERVE ROWS`, `DELETE ROWS`, or `DROP`

## Grant Permissions

Use `#morm.postgres.grant` for permission management:

```moonbit
#morm.postgres.grant(role="reader", table="SELECT", with_grant_option=true)
#morm.postgres.grant(role="writer", table="SELECT,INSERT,UPDATE,DELETE")
#morm.postgres.grant(role="app", sequence="USAGE,SELECT", for_role="owner")
#morm.postgres.grant(role="public", schema="USAGE", default_table="SELECT")
```

Supported grant types:
- `schema` - schema-level privileges
- `table` - table-level privileges
- `sequence` - sequence privileges
- `default_table` / `default_sequence` - default privileges

## Migration Behavior

- `migrate_table` handles common schema management operations
- `@morm.auto_migrate` can apply table metadata-driven updates
- Engine-specific advanced DDL should remain explicit migration SQL

## JSON and Time Recommendations

- Prefer JSONB for high-frequency JSON querying
- Make timezone handling explicit for timestamp-heavy domains
- Index filtering and join columns early for predictable plans

## Performance Notes

- Excellent for analytical joins and transactional services
- Validate query plans with `EXPLAIN` before shipping heavy queries
- Keep lock scope small in high-contention write paths

## Security Practices

- use least-privilege users and schema separation
- enforce TLS for remote network paths
- bind all runtime values as parameters

## Troubleshooting

- slow JSON filters: add GIN/BTREE indexes based on access pattern
- lock contention: reduce long transactions and tune statement order
- migration mismatch: diff metadata and live schema before production migration
