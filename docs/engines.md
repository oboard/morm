---
outline: deep
---

# Engines

The engine layer is where SQL becomes real database behavior.

`morm` itself does not try to hide this boundary.

## Engine Responsibilities

An engine implementation is responsible for:

- rendering statements to SQL text
- binding parameters
- executing SQL
- returning result rows
- applying migration requests

This separation is deliberate. Builders stay generic; engines handle dialect and driver specifics.

## Built-In Engine Packages

This repository includes engine packages for:

- MongoDB
- MySQL
- PostgreSQL
- SQLite
- SQL Server
- Oracle

Each engine adapts:

- placeholder syntax
- upsert behavior
- returning-row behavior
- migration strategy

For network engines, connection reuse is also engine-owned but built on top of a shared pool core.
See [Connection Pooling](./connection-pooling.md).

## Shared Execution Path

The common execution helper is:

```moonbit
let res = @engine.exec_query(engine, q)
```

Where:

- `engine` implements `@engine.Engine`
- `q` implements `@engine.QueryBuilder`

There is also raw execution:

```moonbit
let res = engine.exec_raw(
  "SELECT * FROM student WHERE id = ?",
  [@engine.to_param(1)],
)
```

## Why Engines Own Temporal Formatting

Date and time behavior is not uniform across databases.

That is why:

- the ORM layer does not guess engine-specific datetime text formats
- the engine layer owns SQL rendering and binding
- engine-specific result decoding should also stay engine-specific

This avoids pushing dialect assumptions into generic ORM code.

## Migration Hook

`@morm.auto_migrate` simply forwards `Table` metadata to the engine:

```moonbit
@morm.auto_migrate(engine, [Student::table()])
```

The engine decides how to:

- create missing tables
- compare schemas
- emit DDL

So migration behavior is intentionally engine-owned.

## Implementing A Custom Engine

If you write your own engine, keep it aligned with the same contract:

1. accept `Param` values semantically, not as preformatted strings
2. render SQL from statements in one place
3. keep driver-specific conversions local
4. return rows in a JSON-compatible shape that application decoding can consume

That keeps the rest of the stack stable.

## MongoDB As A Native Client

`MongoDBEngine` can be used through the ORM layer, but it also exposes Mongo-native helper methods for direct document work:

- `run_command_json`
- `find`
- `find_one`
- `insert_one`
- `update_one`
- `delete_one`

These methods are useful when:

- you need raw MongoDB commands
- you want direct collection access outside generated mappers
- the operation does not map cleanly onto SQL-like ORM builders

Example:

```moonbit
let engine = match @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/app") {
  Ok(e) => e
  Err(_) => panic()
}

ignore(engine.insert_one("events", { "kind": "signup", "user_id": 7 }))

let docs = match engine.find("events", { "user_id": 7 }, limit=Some(20)) {
  Ok(rows) => rows
  Err(_) => panic()
}
```

Unlike the ORM row path, these client helpers keep MongoDB-native fields such as `_id` intact.
