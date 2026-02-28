---
outline: deep
---

# Getting Started

`morm` is a lightweight ORM toolkit for MoonBit. It focuses on three things:

- describe schema from normal MoonBit types
- generate boilerplate code instead of hiding behavior at runtime
- keep SQL execution engine-specific and explicit

`morm` is not a "full magic" ORM. You still decide what SQL runs, what your engine does, and when to bypass the helper layer.

## What You Get

With `morm`, you can:

- define entities with `#morm.*` attributes
- generate `table()` metadata from those entities
- build parameterized `select`, `insert`, `update`, `delete`, and `upsert` queries
- generate mapper implementations from annotated traits
- support multiple database engines behind one query model
- pass typed time values such as `PlainDateTime` and `ZonedDateTime`

## Install The Package

Add `oboard/morm` to your app's `moon.mod.json`:

```json
{
  "bin-deps": {
    "oboard/morm": "latest"
  }
}
```

If you use generated code, configure your package build to run `morm-gen` before compilation.

## Configure Code Generation

In your package `moon.pkg`, add `pre-build` rules so source files generate their companion `.g.mbt` files:

```moonbit
options(
  "pre-build": [
    {
      "command": "$mod_dir/.mooncakes/oboard/morm/morm-gen $input -o $output && moonfmt -w $output",
      "input": "entities.mbt",
      "output": "entities.g.mbt",
    },
    {
      "command": "$mod_dir/.mooncakes/oboard/morm/morm-gen $input -o $output && moonfmt -w $output",
      "input": "mapper.mbt",
      "output": "mapper.g.mbt",
    },
  ],
)
```

The generated files are ordinary MoonBit code. You can read them, diff them, and reason about them directly.

## Define Entities

Create `entities.mbt` and describe your models as normal structs.

```moonbit
///|
using @time {type PlainDateTime, type ZonedDateTime}

///|
#morm.entity
pub(all) struct Class {
  #morm.primary_key
  #morm.auto_increment
  id : Int64

  #morm.varchar(length="255")
  name : String

  #morm.foreign_key(references="teacher.id", on_delete="CASCADE")
  teacher_id : Int

  created_at : PlainDateTime
  updated_at : PlainDateTime
} derive(ToJson, FromJson)

///|
#morm.entity
pub(all) struct Student {
  #morm.primary_key
  #morm.auto_increment
  id : Int64

  #morm.varchar(length="255")
  name : String

  age : Int
  birth_date : ZonedDateTime
} derive(ToJson, FromJson)
```

After generation, each entity gets:

- `impl @morm.Entity`
- `Type::table() -> @morm.Table`

That metadata is what migrations, query builders, and generated mappers use.

## Nullability Rules

`morm` keeps nullability simple and type-driven:

- `T` means non-null column
- `T?` means nullable column
- primary keys are treated as non-null

Example:

```moonbit
///|
#morm.entity
pub(all) struct Teacher {
  #morm.primary_key
  #morm.auto_increment
  id : Int64
  name : String
  birth_date : @time.ZonedDateTime?
} derive(ToJson, FromJson)
```

Here `birth_date` becomes nullable because the field type is `ZonedDateTime?`.

## Supported Field Types

The default type mapping covers common MoonBit types and several time types:

- integer types map to integer column types
- `String` maps to string/text columns unless overridden by attributes
- `Bool` maps to boolean
- `Json` can map to `Json` / `JsonB`
- `@time.PlainDate` maps to `Date`
- `@time.PlainTime` maps to `Time`
- `@time.PlainDateTime` maps to `DateTime`
- `@time.ZonedDateTime` maps to `Timestamp`

For time fields:

- use `PlainDateTime` for application-level created/updated timestamps when you want stable cross-engine behavior
- use `ZonedDateTime` when you need an explicit offset preserved in your application data

## Common Entity Attributes

These are the attributes you will use most often:

| Attribute | Purpose |
| --- | --- |
| `#morm.entity` | Marks a struct as a managed entity |
| `#morm.primary_key` | Marks a field as the primary key |
| `#morm.auto_increment` | Marks a field as auto-increment |
| `#morm.varchar(length="255")` | Sets a varchar column |
| `#morm.char(length="1")` | Sets a fixed char column |
| `#morm.text` / `#morm.mediumtext` / `#morm.longtext` | Sets text-like columns |
| `#morm.decimal(precision="10", scale="2")` | Sets a decimal column |
| `#morm.boolean` | Forces boolean column type |
| `#morm.json` / `#morm.jsonb` | Uses JSON-capable columns |
| `#morm.date` / `#morm.time` / `#morm.datetime` / `#morm.timestamp` | Forces temporal column type |
| `#morm.foreign_key(...)` | Adds a foreign key constraint |
| `#morm.many_to_one(...)` | Models a relation that materializes as a foreign key column |
| `#morm.one_to_many(...)` | Models a collection side that is not emitted as a physical column |
| `#morm.auto_create_time` | Opts a field into generated create timestamp behavior |
| `#morm.auto_update_time` | Opts a field into generated update timestamp behavior |

## Generate Entity Code

Inside this repository, the direct command is:

```bash
moon run mormgen -- example/entities.mbt -o example/entities.g.mbt
```

Inside a consuming project, the `pre-build` hook usually handles this for you via the packaged `morm-gen` binary.

The generated file contains the fully expanded `@morm.Table` literal for each entity.

## Define Mappers

Create `mapper.mbt` and describe mapper traits:

```moonbit
///|
#morm.mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_student_by_name(Self, name : String) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
}

///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}
```

You can bind a mapper by:

- `table="student"` and let `mormgen` infer the entity from package entities
- `entity="Student"` explicitly
- old-style positional mapper annotation supported by the parser

`mormgen` generates:

- `StudentMapperImpl`
- `StudentMapperImpl::new(engine)`
- `impl StudentMapper for StudentMapperImpl`

## Method Name Derivation

If you omit `#morm.query`, `mormgen` derives queries from method names for common patterns:

- `find_student_by_id`
- `find_student_by_name`
- `find_students_by_age_and_name`
- `count_students_by_age`
- `find_all`
- `all`

This keeps simple read methods concise while staying explicit in generated code.

## Explicit SQL Methods

When naming rules are not enough, use `#morm.query`:

```moonbit
///|
#morm.mapper(table="enrollment")
pub trait EnrollmentMapper {
  #morm.query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
}
```

This gives you exact SQL control while still keeping typed params and typed result decoding.

## JOIN Helpers

Mapper methods can also attach joins with:

- `#morm.fetch_graph(join="...")`
- `#morm.load_graph(join="...")`

These are currently implemented as query builder `.join(...)` appends. They do not add a separate object graph identity map; they simply extend the SQL used for the generated method.

## Save And Delete

Generated mappers recognize special methods:

- `save(Self, entity : T)`
- `delete(Self, entity : T)`

`save` is implemented with `@morm.upsert_into(...).from(entity)`.

That means:

- on engines that support conflict updates, it behaves like an upsert
- the conflict target comes from the entity primary key or a unique index
- behavior is still visible in generated code, not hidden in runtime reflection

## Auto Timestamp Fields

Generated `save` methods support automatic timestamp filling.

By default:

- a field named `created_at` is treated as auto create time
- a field named `updated_at` is treated as auto update time

If you want custom field names, add:

- `#morm.auto_create_time`
- `#morm.auto_update_time`

Supported generated values:

- `PlainDateTime` gets `@morm.current_plain_date_time_utc()`
- `ZonedDateTime` gets `@morm.current_timestamp_utc()`

Example:

```moonbit
///|
#morm.entity
pub(all) struct AuditLog {
  #morm.primary_key
  id : Int64

  #morm.auto_create_time
  inserted_on : @time.PlainDateTime

  #morm.auto_update_time
  touched_on : @time.PlainDateTime
} derive(ToJson, FromJson)
```

Current behavior is straightforward: generated `save` rewrites the entity before `upsert`, so both auto fields are assigned before the statement is built. If you need stricter semantics such as "never rewrite `created_at` during update", define a custom mapper method or explicit SQL path for that case.

## Use Query Builders Directly

You can use `morm` without generated mappers.

```moonbit
let q = @morm.select_from("student")
  .where_eq("id", 1)
  .where_eq("name", "Alice")
  .limit(1)
```

Available builders:

- `@morm.select_from(table)`
- `@morm.insert_into(table)`
- `@morm.upsert_into(table)`
- `@morm.update(table)`
- `@morm.delete_from(table)`

These build `@engine.Statement` values and defer SQL rendering to the engine layer.

## Params And Time Values

Parameters are converted through the `@engine.ToParam` trait.

Out of the box, `morm` supports:

- numeric primitives
- `Bool`
- `String`
- `Bytes`
- `Json`
- `@time.PlainDate`
- `@time.PlainTime`
- `@time.PlainDateTime`
- `@time.ZonedDateTime`

Example:

```moonbit
let params : FixedArray[@engine.Param] = [
  @engine.to_param(1),
  @engine.to_param("Alice"),
  @engine.to_param(@morm.current_plain_date_time_utc()),
]
```

## Implement Or Use An Engine

`morm` does not hide database connectivity behind runtime magic. Execution happens through `@engine.Engine`.

An engine implementation is responsible for:

- rendering engine-specific SQL
- binding params
- executing statements
- returning rows as JSON-compatible values
- performing migration SQL for `auto_migrate`

This repository contains concrete engines for:

- MySQL
- PostgreSQL
- SQLite
- SQL Server
- Oracle

## Run Auto Migration

If your engine implements migration support, you can apply table metadata directly:

```moonbit
@morm.auto_migrate(engine, [
  Class::table(),
  Student::table(),
])
```

`auto_migrate` is intentionally thin. It forwards the schema JSON to the engine and lets the engine decide how to diff or apply changes.

## Recommended Workflow

For a typical project:

1. define entities in `entities.mbt`
2. define mapper traits in `mapper.mbt`
3. generate `.g.mbt` files during pre-build
4. implement or choose an engine
5. call generated mappers for routine CRUD and use query builders for custom flows
6. inspect generated code whenever behavior matters

## When To Avoid The ORM Layer

`morm` is intentionally easy to bypass. Prefer direct SQL or direct query builders when:

- you need complex reporting SQL
- you need engine-specific locking or hints
- you want exact conflict-update semantics
- you are doing bulk import/export work

That is part of the design, not a failure mode.

## Next Reading

- [Architecture](/architecture) explains the runtime boundaries
- [API Examples](/api-examples) shows concrete builders, params, entities, mappers, and migration usage
