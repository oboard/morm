---
outline: deep
---

# Entities

Entities are the schema source of truth in `morm`.

You describe a table as a normal MoonBit struct, annotate it with `#entity`, and let `mormgen` generate `table()` metadata from it.

## Minimal Example

```moonbit
///|
#entity
pub(all) struct Student {
  #id
  #default(autoincrement())
  id : Int64

  #varchar(length="255")
  name : String

  age : Int
} derive(ToJson, FromJson)
```

This is enough for `mormgen` to generate:

- `impl @morm.Entity for Student`
- `Student::table() -> @morm.Table`

## Required Conventions

For smooth integration, entity types should usually:

- be plain structs
- derive `ToJson`
- derive `FromJson`

Why:

- write paths convert entities through `ToJson`
- read paths decode result rows back through `FromJson`

## Nullability

Nullability is type-driven.

- `T` means non-null
- `T?` means nullable

Example:

```moonbit
///|
#entity
pub(all) struct Teacher {
  #id
  id : Int64
  name : String
  birth_date : @time.ZonedDateTime?
} derive(ToJson, FromJson)
```

`birth_date` is nullable because the field type is optional.

## Primary Keys

Use `#id` to mark the primary key field.

```moonbit
#id
id : Int64
```

Use `#default(autoincrement())` when the engine should treat it as an auto-incrementing key.

```moonbit
#id
#default(autoincrement())
id : Int64
```

You can also declare a primary-key generation strategy inline:

```moonbit
#id(strategy="uuid")
id : String
```

Currently this annotation is emitted as column engine option `pk.strategy=<value>`.
`mormgen` also supports `strategy="auto_increment"` and `strategy="manual"`.

## String And Text Columns

Use these attributes to force string-related SQL types:

- `#varchar(length="255")`
- `#char(length="1")`
- `#text`
- `#mediumtext`
- `#longtext`

Example:

```moonbit
#varchar(length="255")
name : String
```

## Numeric Columns

Common numeric attributes:

- `#tinyint`
- `#smallint`
- `#int`
- `#bigint`
- `#float`
- `#double`
- `#decimal(precision="10", scale="2")`

These are useful when you need specific DDL semantics rather than relying on default type mapping.

## JSON And Binary Columns

For document-like or raw storage:

- `#json`
- `#jsonb`
- `#binary(length="...")`
- `#varbinary(length="...")`
- `#blob`

## Time Columns

Time-related annotations:

- `#date`
- `#time`
- `#datetime`
- `#timestamp`

But in most cases, the field type itself is enough:

- `@time.PlainDate -> Date`
- `@time.PlainTime -> Time`
- `@time.PlainDateTime -> DateTime`
- `@time.ZonedDateTime -> Timestamp`

## Recommended Time Types

Use:

- `PlainDateTime` for `created_at` / `updated_at` in most apps
- `ZonedDateTime` when offset matters in your domain model

This keeps schema intent aligned with actual application semantics.

## Foreign Keys

Use `#foreign_key` for explicit foreign key constraints.

```moonbit
#foreign_key(references="teacher.id", on_delete="CASCADE")
teacher_id : Int
```

This produces:

- a normal scalar column
- matching foreign key metadata in `Table.foreign_keys`

## Relation Annotations

`morm` also recognizes relation-style annotations:

- `#many_to_one(...)`
- `#one_to_many(...)`

Example:

```moonbit
#many_to_one(references="student.id", fk="student_id", on_delete="CASCADE")
student : Student
```

This can materialize the relation as a foreign-key column in generated metadata.

For one-to-many:

```moonbit
#one_to_many(mapped_by="student")
enrollments : FixedArray[Int]
```

This is treated as a logical relation and is not emitted as a physical table column.

## Transient Fields

Use `#transient` when a field should stay in the entity model but not be persisted as a database column.

```moonbit
#transient
display_name : String?
```

Transient fields are excluded from generated table columns and from `insert/update/upsert ... from(entity)` write paths.

## Auto Timestamp Fields

Entity fields can participate in generated timestamp logic.

Convention-based:

- `created_at`
- `updated_at`

Explicit opt-in:

- `#auto_create_time`
- `#auto_update_time`

Example:

```moonbit
///|
#entity
pub(all) struct AuditRow {
  #id
  id : Int64

  #auto_create_time
  inserted_on : @time.PlainDateTime

  #auto_update_time
  touched_on : @time.PlainDateTime
} derive(ToJson, FromJson)
```

These annotations do not change the schema by themselves. They affect generated mapper `save` methods.

## Generated Table Metadata

Generated `table()` returns a full `@morm.Table` value with:

- `name`
- `columns`
- `indexes`
- `foreign_keys`
- engine/comment/charset metadata fields

This value is used by:

- `auto_migrate`
- tests
- custom tooling that wants to inspect schema shape

## Testing Entity Metadata

A common pattern is to assert on generated metadata in tests:

```moonbit
let table = Student::table()
assert_eq(table.name, "student")
assert_eq(table.columns[0].name, "id")
```

This keeps schema drift visible in CI.
