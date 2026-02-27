# GORM/JDBC Gap Todo (Current Round)

## Scope
- Compare GORM capability baseline and JDBC ecosystem expectations with current morm.
- Implement a realistic first batch that is already shippable.

## Completed
- [x] Added transaction SQL abstraction to `@engine.Engine`:
  - `tx_begin_sql`
  - `tx_commit_sql`
  - `tx_rollback_sql`
  - `tx_savepoint_sql`
  - `tx_rollback_to_savepoint_sql`
- [x] Added async transaction helpers in `engine`:
  - `tx_begin`
  - `tx_commit`
  - `tx_rollback`
  - `tx_savepoint`
  - `tx_rollback_to_savepoint`
- [x] Added richer filter operators aligned with common GORM usage:
  - `where_ne` (`!=`)
  - `where_like` (`LIKE`)
  - supported in `Query`/`UpdateQuery`/`DeleteQuery`
  - renderer and sqlite engine mapping updated
- [x] Extended compatibility DSN schemes:
  - `MySQLEngine`: `mysql://`, `mariadb://`, `tidb://`
  - `PgSQLEngine`: `postgres://`, `postgresql://`, `gaussdb://`, `cockroachdb://`
- [x] Added compatibility tests for DSN schemes.

## Next Batch
- [x] Add association APIs (`has one`, `has many`, `belongs to`, `many2many`) and preload.
- [x] Add hook callbacks (`before/after create/update/delete/find`).
- [x] Add soft delete convention and default scoped query behavior.
- [x] Add richer migration diff support (alter column/index/constraint diff).
- [x] Add pluggable dialect/driver registry for more JDBC-style database coverage.

## Notes
- Current round implements the above as MVP APIs with test coverage.
