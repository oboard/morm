---
outline: deep
---

# MongoDB Engine

MongoDB in `morm` supports both the unified `Engine` abstraction and document-native workflows for teams that need schema flexibility and JSON-first data operations.

## Package Import

```moonbit
using @oboard/morm/engine/mongodb as @mongodb
```

## DSN and Connection

```moonbit
let engine = match
  @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

Common DSN pattern:

```text
mongodb://<host>:<port>/<database>
```

## Execution Model

- `exec_raw` provides a unified execution entrypoint with `QueryResult`
- Document query results are returned in JSON-friendly shapes
- BSON values can be processed with `@oboard/morm/bson`

## Engine and Native Capability Boundary

Use the shared engine contract when you want consistent behavior across SQL and MongoDB backends.  
Use MongoDB-native APIs for advanced document operations such as pipeline-heavy aggregations or command-specific control.

## Transactions and Consistency

- Transaction semantics are exposed through the shared engine interface
- Availability depends on deployment mode and MongoDB server capabilities
- Keep consistency assumptions explicit in application-layer workflows

## Schema Evolution

- `morm` can route metadata-driven migration flow through the common API
- In document stores, evolution is usually versioned in application logic
- Prefer additive, backward-compatible field evolution in live systems

## Data Modeling Recommendations

- define clear ownership between `_id` and business unique keys
- index frequently filtered and sorted fields
- avoid deeply unbounded nested documents for hot paths

## Performance Notes

- aggregate pipelines should be tested with realistic production-like data volume
- large document updates can become write-amplified; keep update scope focused
- monitor query plans and index usage continuously

## Security Practices

- use dedicated least-privilege users
- enforce authentication and network isolation
- avoid passing unchecked user expressions directly to raw query commands

## Troubleshooting

- missing index symptoms: high latency on filter-heavy queries
- transaction limitations: verify deployment topology and server feature support
- migration mismatch: treat document schema changes as staged app-level transitions

## Related Documentation

- MongoDB native client usage: [MongoDB Client](./mongodb-client.md)
