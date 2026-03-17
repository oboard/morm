---
outline: deep
---

# Oracle Engine

Oracle is designed for environments with established enterprise-grade Oracle operations, strict governance, and long-lived mission-critical systems.

## Package Import

```moonbit
using @oboard/morm/engine/oracle as @oracle
```

## DSN and Connection

```moonbit
let engine = match
  @oracle.OracleEngine::open("oracle://system:password@127.0.0.1:1521/XEPDB1") {
  Ok(e) => e
  Err(_) => panic()
}
```

Use dedicated application users and avoid administrative accounts in normal runtime paths.

## Parameter Handling

- Oracle-compatible rendering strategy is handled by the engine
- All values use typed `@engine.Param` binding
- Runtime values should never be inlined into SQL strings

## Transactions

- Supports commit and rollback through the shared engine contract
- Multi-step workflows can be executed with explicit sequencing via `exec_raw`
- Keep transaction boundaries short in high-throughput services

## Migration Behavior

- `migrate_table` supports core table creation and schema alignment
- Oracle-specific objects such as sequences and triggers should be maintained with explicit migration scripts
- Prefer controlled migration batches for production rollouts

## Modeling and Operational Recommendations

- Keep naming conventions consistent across schema and generated code
- Define numeric precision and time semantics explicitly
- Align DBA standards, indexing policy, and execution plan reviews

## Security Practices

- use least-privilege users
- restrict schema-level permissions by service boundary
- enforce secure transport where required

## Troubleshooting

- identifier mismatch: verify quoted/unquoted naming conventions
- migration ordering issues: separate sequence/trigger/table changes explicitly
- type conversion surprises: standardize precision/scale and timestamp conventions early
