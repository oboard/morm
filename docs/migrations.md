---
outline: deep
---

# Migrations

`morm` supports schema-driven migration through generated `Table` metadata plus an engine migration hook.

## Basic Usage

```moonbit
@morm.auto_migrate(engine, [
  Class::table(),
  Student::table(),
  Teacher::table(),
])
```

This is the public API entry point for schema synchronization.

## What `auto_migrate` Actually Does

`auto_migrate` is intentionally thin.

It:

1. receives an engine
2. receives an array of `Table`
3. serializes each table as JSON
4. calls the engine migration method

It does not implement a universal SQL diff algorithm in the ORM layer.

## Why Migration Logic Lives In The Engine

DDL behavior varies substantially across databases:

- column type syntax
- default handling
- index changes
- foreign key syntax
- table alter capabilities

Because of that, `morm` keeps migration decisions engine-specific.

## Best Use Cases

`auto_migrate` is a good fit for:

- local development setup
- test database bootstrapping
- straightforward schema alignment

For more complex production changes, explicit migration scripts are still the safer option.

## Generated Table Metadata

Migration depends entirely on generated metadata from `Type::table()`.

That means when entity definitions change:

1. regenerate the `.g.mbt` file
2. rebuild
3. run migration

If you forget regeneration, migration will use stale schema metadata.

## Testing Migration Expectations

Even if you do not run real migrations in unit tests, you can still assert on generated schema shape:

```moonbit
let table = Class::table()
assert_eq(table.columns[3].name, "created_at")
assert_eq(table.columns[3].column_type, @morm.ColumnType::DateTime)
```

This is often enough to catch unintended schema changes before runtime.
