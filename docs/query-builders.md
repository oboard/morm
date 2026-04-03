---
outline: deep
---

# Query Builders

`morm` query builders construct structured statements, not opaque SQL strings.

This keeps parameter binding typed and lets each engine render dialect-specific SQL later.

## Select

Start with:

```moonbit
let q = @morm.select_from("student")
```

Add filters:

```moonbit
let q = @morm.select_from("student")
  .where_eq("id", 1)
  .where_ne("name", "Bob")
  .where_gte("age", 18)
  .where_lte("age", 30)
  .where_like("name", "A%")
```

Add ordering:

```moonbit
let q = @morm.select_from("student")
  .order_by(Desc("id"))
```

Add joins:

```moonbit
let q = @morm.select_from("enrollment")
  .join("LEFT JOIN student ON student.id = enrollment.student_id")
```

Add pagination:

```moonbit
let q = @morm.select_from("student")
  .limit(20)
  .offset(40)
```

Or page helper:

```moonbit
let q = @morm.select_from("student").page(3, 20)
```

## Select Raw Columns

If you do not want `SELECT *`, use:

```moonbit
let q = @morm.select_raw("student", "count(*)")
  .where_eq("age", 18)
```

This is how count-style derived mapper methods are built.

## Insert

Explicit insert:

```moonbit
let q = @morm.insert_into("student")
  .columns(["name", "age"])
  .values([
    @engine.to_param("Alice"),
    @engine.to_param(18),
  ])
```

Entity-based insert:

```moonbit
let q = @morm.insert_into("student").from(student)
```

The entity-based path uses `ToJson` plus table metadata column order.

Batch insert (single SQL with multi-row values):

```moonbit
let q = @morm.insert_into("student")
  .columns(["id", "name"])
  .values_many([
    [@engine.Int(1), @engine.String("Alice")],
    [@engine.Int(2), @engine.String("Bob")],
  ])
```

## Upsert

Start with:

```moonbit
let q = @morm.upsert_into("student")
```

Set values manually:

```moonbit
let q = @morm.upsert_into("student")
  .set("id", 1)
  .set("name", "Alice")
```

Set conflict target:

```moonbit
let q = @morm.upsert_into("student")
  .set("id", 1)
  .set("name", "Alice")
  .on_conflict(["id"])
```

Add conflict updates:

```moonbit
let q = @morm.upsert_into("student")
  .set("id", 1)
  .set("name", "Alice")
  .on_conflict(["id"])
  .do_update_set("name", "Alice")
```

Entity-based upsert:

```moonbit
let q = @morm.upsert_into("student").from(student)
```

For `.from(entity)`, the conflict target comes from entity table metadata:

- primary key first
- otherwise the first unique index

## Update

```moonbit
let q = @morm.update("student")
  .set("name", "Alice Updated")
  .set("age", 19)
  .where_eq("id", 1)
```

`UpdateQuery::set` accepts any value that implements `@engine.ToParam`.

The same applies to:

- `Query::where_*`
- `UpdateQuery::where_*`
- `DeleteQuery::where_*`
- `UpsertQuery::set`
- `UpsertQuery::do_update_set`

By contrast, APIs like `InsertQuery::values(...)` and `engine.exec_raw(..., params)` expect `FixedArray[@engine.Param]`, so those places still need explicit `@engine.to_param(...)`.

Entity-based update:

```moonbit
let q = @morm.update("student").from(student)
```

This writes all entity fields into the `SET` list.

## Delete

Condition-based delete:

```moonbit
let q = @morm.delete_from("student")
  .where_eq("id", 1)
```

Entity-based delete:

```moonbit
let q = @morm.delete_from("student").from(student)
```

Entity-driven delete uses the entity primary key value if available.

## Soft-Delete Scope

`select_from_scoped` is a convenience helper for the boolean soft-delete convention:

```moonbit
let q = @morm.select_from_scoped("student", deleted_col="deleted")
  .where_eq("id", 1)
```

This adds the implicit predicate `deleted = false`.

## Rendering And Execution

All builders implement `@engine.QueryBuilder`, so they can be passed to:

```moonbit
let res = engine.exec(q)
```

The engine is responsible for:

- rendering SQL
- binding params
- executing the statement

That is why builders stay engine-neutral.
