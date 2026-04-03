# oboard/morm

`morm` is a lightweight ORM toolkit for MoonBit.

It is built around a simple split:

- entities describe schema
- `mormgen` generates plain MoonBit code
- query builders describe SQL intent
- engines render and execute real database behavior

The project deliberately avoids runtime reflection and hidden ORM state.

## What It Covers

`morm` provides:

- entity-to-table metadata generation with `#morm.entity`
- mapper generation from annotated traits
- typed query builders for `select`, `insert`, `upsert`, `update`, and `delete`
- multi-engine support through a shared `Engine` contract
- local time-type support for `PlainDate`, `PlainTime`, `PlainDateTime`, and `ZonedDateTime`
- direct MoonBit enum support in generated `ToParam` / `FromParam` impls and schema metadata
- generated auto timestamp handling for `created_at` / `updated_at` and explicit timestamp annotations
- transient entity fields via `#morm.transient` (kept in model, excluded from physical columns and `from(entity)` writes)

## Install

Add the package to your application's `moon.mod.json`:

```json
{
  "bin-deps": {
    "oboard/morm": "latest"
  }
}
```

## Generate Code

A typical package uses `pre-build` to generate `.g.mbt` files:

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

## Entity Example

```moonbit
///|
using @time {type PlainDateTime}

///|
#morm.entity
pub(all) struct Class {
  #morm.id
  #morm.default(autoincrement())
  id : Int64

  #morm.varchar(length="255")
  name : String

  created_at : PlainDateTime
  updated_at : PlainDateTime
} derive(ToJson, FromJson)
```

Payload-free MoonBit enums can also be used directly as entity fields. `mormgen`
will generate enum codecs and emit native enum DDL for engines that support it
(currently MySQL and PostgreSQL).

## Mapper Example

```moonbit
///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}

///|
#morm.mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_student_by_name(Self, name : String) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
}
```

Generated `save` methods can assign:

- `created_at`
- `updated_at`
- fields marked with `#morm.auto_create_time`
- fields marked with `#morm.auto_update_time`

`PlainDateTime` fields use `@morm.current_plain_date_time_utc()`, and `ZonedDateTime` fields use `@morm.current_timestamp_utc()`.

## Query Builder Example

```moonbit
let q = @morm.select_from("class")
  .where_eq("id", 1)
  .order_by(@morm.Desc("id"))
  .limit(1)
```

Execute through an engine:

```moonbit
let res = engine.exec(q)
```

## Migration Example

```moonbit
@morm.auto_migrate(engine, [Class::table()])
```

Migration execution stays engine-specific by design.

## Documentation

See the VitePress docs in [`docs/`](docs/):

- [Getting Started](docs/get-started.md)
- [Entities](docs/entities.md)
- [Mappers](docs/mappers.md)
- [Query Builders](docs/query-builders.md)
- [Time Types](docs/time.md)
- [Engines](docs/engines.md)
- [Migrations](docs/migrations.md)
- [Architecture](docs/architecture.md)
- [API Examples](docs/api-examples.md)
