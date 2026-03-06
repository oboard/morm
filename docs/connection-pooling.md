---
outline: deep
---

# Connection Pooling

Network engines in `morm` now share a small common connection-pool core.

This applies to:

- MongoDB
- MySQL
- PostgreSQL

The goal is simple:

- reuse authenticated network connections instead of reconnecting for every query
- cap concurrent open connections per engine instance
- keep transaction state pinned to one physical connection when a transaction is active

## Why It Exists

Without pooling, every query pays for:

- TCP connection setup
- protocol handshake
- database authentication

That is expensive for normal request traffic and makes transactions hard to model correctly.

With pooling, idle connections are reused and only bad or excess connections are closed.

## Pool Model

The shared pool lives in `@engine.ConnectionPool`.

Internally it uses:

- `@async.Queue` for idle connections
- `@async.Semaphore` for the max-open cap

The current design is intentionally small:

- `borrow(open_conn)`
- `release(conn, close_conn, reusable=true)`
- `close(close_conn)`

The pool is generic. It does not know SQL, BSON, or any database protocol details.

## What Stays Engine-Specific

The pool is shared, but connection behavior is still implemented per engine:

- how to open a connection
- how to authenticate
- how to run one request on an existing connection
- when a connection is still safe to reuse

This keeps protocol logic local to each driver while avoiding duplicated pooling logic.

## Transaction Pinning

For `MySQL` and `PostgreSQL`, an active transaction is pinned to one borrowed connection.

That means:

1. `@engine.tx_begin(engine)` borrows one connection and keeps it.
2. All later `exec_raw` / `exec_query` calls on that same engine instance run on the same socket.
3. `@engine.tx_commit(engine)` or `@engine.tx_rollback(engine)` returns the connection to the pool.

This is the minimum requirement for correct transaction behavior.

Current boundary:

- one engine instance supports one active transaction at a time
- if you need concurrent transactions, use separate engine instances

## MongoDB

`MongoDBEngine` also uses the shared pool.

Pooling is active for:

- `hello`
- authentication
- CRUD commands
- cursor `getMore`

MongoDB session-based transactions are still future work.

## Operational Notes

- Pool size is currently fixed inside each engine constructor.
- `close()` closes idle pooled connections and any active pinned transaction connection.
- A broken connection is discarded instead of being returned to the idle queue.

Future work that fits naturally here:

- configurable pool size in DSN or constructor options
- idle timeout and stale connection eviction
- metrics
- background health checks
