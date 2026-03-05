---
outline: deep
---

# MongoDB Client

`MongoDBEngine` is not limited to ORM-generated queries.

Besides implementing `@engine.Engine`, it also exposes MongoDB-native helper methods so you can use it directly as a document client.

This is useful when:

- the operation is naturally document-oriented
- you want a raw MongoDB command
- the ORM builder shape is too SQL-like for the job

## Available Methods

Current native helpers on `MongoDBEngine`:

- `run_command_json(command)`
- `find(collection, filter, ...)`
- `find_one(collection, filter, ...)`
- `insert_one(collection, document)`
- `update_one(collection, filter, update, ...)`
- `delete_one(collection, filter)`
- `aggregate(collection, pipeline, ...)`
- `count_documents(collection, filter?)`
- `estimated_document_count(collection)`
- `distinct(collection, field, filter?)`
- `find_one_and_update(collection, filter, update, ...)`
- `find_one_and_delete(collection, filter)`
- `find_one_and_replace(collection, filter, replacement, ...)`
- `drop(collection)`
- `create_index(collection, keys, ...)`
- `create_indexes(collection, indexes)`
- `list_indexes(collection)`
- `list_index_names(collection)`
- `drop_index(collection, name)`
- `drop_indexes(collection)`

All of these use the same authenticated pooled connections as the ORM path.

## Raw Commands

Use `run_command_json` when you want full control over the command body:

```moonbit
let res = engine.run_command_json({
  "ping": 1,
})
```

It returns the raw command document from MongoDB.

## Direct Collection Queries

`find` and `find_one` are the main collection helpers:

```moonbit
let docs = match engine.find(
  "events",
  { "kind": "signup" },
  sort=Some({ "created_at": -1 }),
  limit=Some(20),
) {
  Ok(rows) => rows
  Err(_) => panic()
}
```

Unlike the ORM row path, these methods preserve MongoDB-native fields such as `_id`.

## Aggregation

For pipeline-based queries, use `aggregate`:

```moonbit
let rows = match engine.aggregate(
  "events",
  [
    { "$match": { "kind": "signup" } },
    { "$group": { "_id": "$user_id", "count": { "$sum": 1 } } },
  ],
) {
  Ok(rows) => rows
  Err(_) => panic()
}
```

`aggregate` also follows `getMore` cursors, so multi-batch pipelines are handled automatically.

## Count And Distinct

Two small helpers cover common metadata queries:

```moonbit
let total = match engine.count_documents("events", { "kind": "signup" }) {
  Ok(n) => n
  Err(_) => panic()
}

let users = match engine.distinct("events", "user_id") {
  Ok(values) => values
  Err(_) => panic()
}
```

If you want a quick collection-wide estimate without a filter, use:

```moonbit
let approx = match engine.estimated_document_count("events") {
  Ok(n) => n
  Err(_) => panic()
}
```

## Atomic Find-And-Modify

Use the `findAndModify` family when you want MongoDB's single-document atomic read-modify-write flow:

```moonbit
let updated = match engine.find_one_and_update(
  "counters",
  { "_id": "signup" },
  { "$inc": { "value": 1 } },
) {
  Ok(doc) => doc
  Err(_) => panic()
}
```

By default it returns the updated version of the document.

The same family also includes:

- `find_one_and_delete`
- `find_one_and_replace`

## Drop A Collection

To drop a collection directly:

```moonbit
ignore(engine.drop("events_tmp"))
```

## Index Management

`MongoDBEngine` also exposes the common collection index commands.

Create one index:

```moonbit
ignore(
  engine.create_index(
    "events",
    { "user_id": 1 },
    name=Some("idx_events_user_id"),
  ),
)
```

Create multiple indexes with raw spec documents:

```moonbit
ignore(
  engine.create_indexes(
    "events",
    [
      { "key": { "kind": 1 }, "name": "idx_events_kind" },
      { "key": { "created_at": -1 }, "name": "idx_events_created_at" },
    ],
  ),
)
```

List indexes:

```moonbit
let names = match engine.list_index_names("events") {
  Ok(names) => names
  Err(_) => panic()
}
```

Drop indexes:

```moonbit
ignore(engine.drop_index("events", "idx_events_kind"))
ignore(engine.drop_indexes("events"))
```

## Current Scope

This native API is intentionally focused on common single-command operations.

What it already gives you:

- pooled authenticated connections
- basic CRUD helpers
- aggregation
- raw commands
- cursor continuation via `getMore`
- collection index management

What is still future work:

- `bulk_write`
- sessions and transactions
- change streams
