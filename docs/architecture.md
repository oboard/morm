---
outline: deep
---

# Architecture

`morm` is split into a few deliberately separate layers. The point is to keep behavior inspectable and to avoid putting engine-specific assumptions into the ORM layer.

## Design Principles

The library is built around these constraints:

- no runtime reflection
- type-driven nullability
- generated code over hidden metaprogramming
- explicit engine boundary
- SQL construction separated from SQL execution

This affects how entities, mappers, params, time types, and migrations are handled.

## High-Level Layers

At a high level, the system is:

1. source annotations on MoonBit structs and traits
2. `mormgen` parses those files and emits normal MoonBit code
3. query builders construct typed statement objects
4. engines render and execute engine-specific SQL
5. rows come back as JSON-shaped values and are decoded into user types

Nothing in the runtime layer tries to rediscover your types from metadata at execution time.

## Entity Layer

Entities are plain MoonBit structs annotated with `#morm.entity`.

Example responsibilities of the entity layer:

- define field names
- define field types
- define nullability through `T` vs `T?`
- mark keys and some schema overrides

`mormgen` converts that into `@morm.Table` metadata. That means schema structure is available as plain data:

- table name
- columns
- indexes
- foreign keys
- engine-level defaults such as charset/collation where relevant

Because the generated `table()` implementation is static code, there is no hidden schema cache or runtime schema introspection step inside the ORM.

## Mapper Layer

Mapper traits describe the application-facing methods you want.

The generator reads:

- the mapper annotation
- method names
- explicit `#morm.query(...)` attributes
- optional fetch/load join attributes

It then emits:

- a concrete `*MapperImpl`
- a constructor `::new(engine)`
- method bodies that build queries or execute raw SQL

This keeps the calling surface ergonomic while preserving full visibility. If generated SQL is wrong or too broad, you can inspect the `.g.mbt` file immediately.

## Query Builder Layer

The runtime query builders are plain structured objects. They describe intent, not SQL text.

Core builder entry points:

- `select_from`
- `insert_into`
- `upsert_into`
- `update`
- `delete_from`

These produce structured statements such as:

- `SelectStatement`
- `InsertStatement`
- `UpsertStatement`
- `UpdateStatement`
- `DeleteStatement`

The builder layer is responsible for:

- collecting filters
- ordering
- limits and offsets
- sets and values
- conflict targets and conflict updates for upsert

The builder layer is not responsible for:

- choosing placeholder syntax
- serializing binary protocol payloads
- executing on a socket
- guessing engine-specific date parsing

## Engine Layer

The engine layer is the real database boundary.

An `@engine.Engine` implementation owns:

- statement execution
- raw SQL execution
- statement rendering
- engine-specific placeholder rules
- parameter binding behavior
- migration execution

This separation is intentional. The ORM layer should not guess formatting rules that vary across engines.

That is especially important for time values:

- the ORM keeps typed time values in params
- engines stringify or bind them in the way their driver expects
- result decoding should be based on what the engine already parsed or returned

## Parameter System

Parameters are represented by `@engine.Param`.

The enum includes:

- scalar primitives
- `Decimal`
- `Date`
- `Time`
- `DateTime`
- `Timestamp`
- `Uuid`
- `Json`
- `String`
- `Bytes`

User values become params via the `@engine.ToParam` trait. This keeps parameter conversion type-driven and explicit.

Notable built-in conversions:

- `@time.PlainDate -> Param::Date`
- `@time.PlainTime -> Param::Time`
- `@time.PlainDateTime -> Param::DateTime`
- `@time.ZonedDateTime -> Param::Timestamp`

This matters for two reasons:

- query builders stay typed instead of becoming "stringly typed"
- engine code can branch on semantic param kinds rather than guessing from arbitrary strings

## Time Model

`morm` now uses a local `time` package and supports JSON serialization/deserialization directly on those types.

The practical model is:

- `PlainDate` for calendar date
- `PlainTime` for wall-clock time
- `PlainDateTime` for timestamp-like values without offset
- `ZonedDateTime` for timestamp-like values with offset

Why this split exists:

- many databases store "datetime" values without a timezone concept
- some use "timestamp" semantics or driver APIs that preserve offset better
- pushing everything into one string type would force parsing guesses in the wrong layer

For application defaults:

- `@morm.current_plain_date_time_utc()` returns a UTC-based `PlainDateTime`
- `@morm.current_timestamp_utc()` returns a UTC-based `ZonedDateTime`

## Auto Timestamp Generation

`mormgen` injects timestamp assignments in generated `save` methods.

Detection rules:

- field name `created_at` implies auto create time
- field name `updated_at` implies auto update time
- `#morm.auto_create_time` explicitly opts in
- `#morm.auto_update_time` explicitly opts in

Generation rules:

- `PlainDateTime` fields use `current_plain_date_time_utc()`
- `ZonedDateTime` fields use `current_timestamp_utc()`

Important current behavior:

- this happens in generated mapper code, not deep in runtime ORM internals
- the entity is rewritten before `upsert`
- therefore the generated `save` path is simple and predictable, but not "smart" enough to preserve `created_at` automatically on update-only paths

If you need more nuanced semantics, define custom methods rather than expecting hidden ORM state machines.

## Why Generated Code Matters

The library intentionally chooses code generation over reflection-heavy abstraction.

Benefits:

- easier debugging
- easier code review
- easier diffing in CI
- no hidden runtime registration
- no separate DSL to learn beyond attributes and normal MoonBit syntax

The tradeoff is explicit:

- you must regenerate files when source annotations change
- generated code becomes part of the build pipeline

That tradeoff is acceptable because it makes behavior inspectable and predictable.

## Name-Based Query Derivation

For simple methods, the parser can derive query builder code from method names.

Examples:

- `find_student_by_id`
- `find_students_by_age_and_name`
- `count_students_by_age`
- `find_all`
- `all`

This derivation is intentionally conservative. The moment your query shape is less obvious, use `#morm.query`.

## Explicit SQL Escape Hatch

When you attach `#morm.query("...")`, the generated method uses the SQL you wrote.

This is an architectural feature, not a fallback hack:

- the library does not try to re-parse your SQL into a pseudo-AST
- params are still bound through the typed parameter path
- result decoding is still centralized

You get exact SQL with less repetitive boilerplate.

## Relation Metadata

The project supports relation-oriented annotations such as:

- `#morm.foreign_key`
- `#morm.many_to_one`
- `#morm.one_to_many`

Current scope:

- relation metadata affects generated table metadata and some mapper ergonomics
- `many_to_one` can materialize to a foreign key column
- `one_to_many` is recognized as a logical relation and not emitted as a physical column

This is not trying to be a full identity-map ORM with transparent lazy loading.

## Migration Flow

`auto_migrate` is deliberately thin:

1. user passes an engine and an array of `Table`
2. `morm` serializes table metadata as JSON
3. engine receives that schema payload
4. engine performs its own migration logic

This keeps engine-specific migration behavior where it belongs.

It also means:

- SQL diffing strategy is engine-specific
- unsupported complex changes should be handled manually
- `auto_migrate` is best used for straightforward schema alignment, not arbitrary production migration policy

## Serialization Boundary

Entities usually derive:

- `ToJson`
- `FromJson`

That gives `morm` a stable transport shape for:

- turning entities into query params on write paths
- turning engine result rows into entities on read paths

The ORM runtime does not attempt to parse engine-specific date string formats out of generic JSON text anymore. That decision was intentionally pushed away from the ORM layer to avoid cross-engine ambiguity.

## Multi-Engine Strategy

This repository ships multiple engines because SQL dialect differences are real:

- placeholder syntax
- `RETURNING` support
- conflict/update syntax for upsert
- migration DDL differences
- driver parameter binding quirks

The architecture therefore uses:

- shared statement model
- engine-local rendering/execution

That is the central compatibility strategy.

## Practical Mental Model

When using `morm`, think of the stack like this:

- entities define schema
- mappers define app-facing operations
- builders define structured SQL intent
- engines define actual database behavior

If something surprises you, inspect the generated file first, then inspect the engine implementation. That is usually where the truth is.

## Where The Boundaries Are Strict

The codebase intentionally avoids these shortcuts:

- ORM-side guessing of engine-specific datetime string formats
- runtime reflection over arbitrary user structs
- automatic hidden network/database connection management
- pretending all SQL dialects are equivalent

Those restrictions are part of the design, not missing polish.

## Recommended Extension Points

If you need to extend the system, these are the safest directions:

1. add new attributes in `mormgen` and keep generation explicit
2. add `ToParam` implementations for new application-facing value types
3. extend a concrete engine for new rendering or migration behavior
4. add explicit mapper methods instead of overloading name derivation rules too far

## Summary

`morm` is best understood as:

- a schema metadata generator
- a typed statement builder
- a mapper code generator
- a small, explicit contract between your models and your engines

It is intentionally not a black-box runtime ORM.
