---
outline: deep
---

# MySQL Engine

MySQL is a strong default for transactional web services, with broad tooling support and predictable operational behavior.

## Package Import

```moonbit
using @oboard/morm/engine/mysql as @mysql
```

## DSN and Connection

```moonbit
let engine = match
  @mysql.MySQLEngine::open("mysql://root:password@127.0.0.1:3306/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

Use dedicated application credentials instead of root in production.

## Placeholders and Parameters

- Uses `?` placeholders
- Parameter order must match placeholder position
- Parameter values flow through `@engine.Param`

## Transactions

- Supports `BEGIN` / `COMMIT` / `ROLLBACK`
- Connection pinning during transaction helps preserve state consistency
- Suitable for mixed reads/writes in service-style workloads

## Migration Behavior

- `migrate_table` handles common schema creation and sync flows
- `@morm.auto_migrate` can bootstrap service startup schema steps
- Keep complex online schema changes as explicit migration SQL

## Operational Recommendations

- Prefer `utf8mb4` and a consistent collation strategy
- Keep timezone semantics explicit at application boundaries
- Tune pool size based on worker count and DB capacity

## Performance and Scaling Notes

- Works well for high-throughput OLTP with proper indexing
- Validate query plans for large joins and frequent filters
- Keep transactions short to reduce lock contention

## Security Practices

- Use least-privilege DB users
- Enforce TLS where network boundaries require it
- Avoid string-concatenated SQL, always bind params

## Troubleshooting

- deadlocks under load: add retries and reduce transaction scope
- encoding issues: verify database/table/connection charset alignment
- migration drift: compare generated table metadata with actual schema before rollout
