---
outline: deep
---

# SQL Server Engine

SQL Server is a strong fit for Microsoft-centric enterprise environments and existing SQL Server operational ecosystems.

## Package Import

```moonbit
using @oboard/morm/engine/sqlserver as @sqlserver
```

## DSN and Connection

```moonbit
let engine = match
  @sqlserver.SQLServerEngine::open("sqlserver://sa:password@127.0.0.1:1433/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

Use dedicated service credentials and avoid `sa` for normal application traffic.

## Placeholders and Parameters

- Uses `?` placeholders
- Parameters are transmitted through engine-level typed binding
- Keep values in `@engine.Param` instead of string interpolation

## Transactions

- Supports standard transaction control semantics
- Suitable for batched SQL operations via `exec_raw`
- Works with the shared transaction helper flow in `morm`

## Migration Behavior

- `migrate_table` supports common schema evolution tasks
- `@morm.auto_migrate` can bootstrap baseline schema updates
- Use explicit migration scripts for SQL Server-specific advanced DDL

## Operational Recommendations

- Choose NVARCHAR vs VARCHAR intentionally for multilingual data
- Validate compatibility across SQL Server versions in your deployment target
- Keep least-privilege DB accounts and role boundaries clear

## Performance Notes

- Index highly filtered columns and join keys
- Avoid oversized transactions in hot tables
- Profile heavy reports separately from OLTP workloads

## Security Practices

- enforce encrypted network channels where required
- avoid dynamic SQL concatenation
- review granted roles regularly

## Troubleshooting

- collation mismatch: align collation at DB, table, and query boundaries
- lock escalation: reduce batch sizes and transaction duration
- migration failures: split complex DDL into ordered, explicit migration steps
