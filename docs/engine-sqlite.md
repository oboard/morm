---
outline: deep
---

# SQLite Engine

SQLite is the simplest engine in `morm`: zero network setup, instant startup, and excellent ergonomics for local development, CI, and small single-node deployments.

## Package Import

```moonbit
using @oboard/morm/engine/sqlite3 as @sqlite3
```

## Connection Modes

- In-memory database: `:memory:`
- File-backed database: `/absolute/path/to/app.db`

```moonbit
let engine = @sqlite3.SQLiteEngine::open(":memory:")
```

Use file-backed mode for persistent local apps and tests that need state between process runs.

## Parameter Binding and Placeholders

- Uses `?` placeholders
- Binds parameters in positional order
- Works with the shared `@engine.Param` value model

```moonbit
let create_res = engine.exec_raw(
  "CREATE TABLE user (id INTEGER PRIMARY KEY, name TEXT NOT NULL)",
  [],
)
let query_res = engine.exec_raw(
  "SELECT * FROM user WHERE id = ?",
  [@engine.Int(1)],
)
```

## Transactions

SQLite engine supports standard transaction helpers through the common engine interface:

- `tx_begin`
- `tx_commit`
- `tx_rollback`
- savepoints for nested transactional workflows

For high write concurrency, remember SQLite locking behavior is file-based and differs from server databases.

## Migration Behavior

SQLite supports `migrate_table` and `@morm.auto_migrate`, but DDL capabilities are still constrained by SQLite itself.

Practical guidance:

- Table creation and additive schema changes are straightforward
- Complex column rewrites may require manual migration SQL
- Keep migration steps explicit in production rollouts

## Performance Notes

- Very fast for local and embedded workloads
- Minimal operational overhead
- Not ideal for heavy multi-process write traffic

## Recommended Use Cases

- Local development and test suites
- CLI and desktop applications
- Lightweight internal tools

## When to Choose Another Engine

Consider MySQL or PostgreSQL if you need:

- sustained concurrent writes across many workers
- stronger server-side operational controls
- larger-scale production replication strategies

## Troubleshooting

- `database is locked`: reduce long write transactions and retry safely
- data not persisted: switch from `:memory:` to file-backed path
- migration mismatch: inspect generated table metadata and run controlled manual SQL for edge cases
