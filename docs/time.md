---
outline: deep
---

# Time Types

`morm` has first-class support for local time types and their JSON / parameter conversion behavior.

## Supported Types

The local `time` package includes:

- `PlainDate`
- `PlainTime`
- `PlainDateTime`
- `ZonedDateTime`

These are used directly by the engine parameter system and by entity JSON round-trips.

## Param Mapping

The engine layer defines built-in `ToParam` implementations:

- `PlainDate -> Param::Date`
- `PlainTime -> Param::Time`
- `PlainDateTime -> Param::DateTime`
- `ZonedDateTime -> Param::Timestamp`

This means you can pass time values directly to builders:

```moonbit
let q = @morm.update("class")
  .set("updated_at", @morm.current_plain_date_time_utc())
  .where_eq("id", 1)
```

## JSON Mapping

The local time types also implement:

- `ToJson`
- `@json.FromJson`

This matters because entities commonly derive `ToJson` / `FromJson`, and those derived implementations need time fields to round-trip cleanly.

## Current Time Helpers

`morm` exports two convenience helpers:

- `@morm.current_plain_date_time_utc()`
- `@morm.current_timestamp_utc()`

Use them when you want runtime-generated UTC timestamps with explicit type intent.

## Choosing `PlainDateTime` vs `ZonedDateTime`

Use `PlainDateTime` when:

- the database column is effectively a datetime without offset semantics
- you want stable cross-engine created/updated timestamp behavior
- the value is mostly operational metadata, not user-facing calendar data

Use `ZonedDateTime` when:

- offset matters in your domain model
- you want to preserve timezone/offset information in application data

For most `created_at` / `updated_at` fields, `PlainDateTime` is the practical default.

## ORM Boundary

`morm` intentionally does not parse arbitrary engine-specific datetime strings back into typed time values in the ORM layer.

Why:

- different engines and drivers format temporal values differently
- ORM-side guessing creates cross-engine ambiguity
- the engine layer is the right place for engine-specific decoding decisions

The ORM layer keeps time values typed on the way in, and leaves engine-specific parsing concerns out of generic write-path conversion.

## Auto Timestamp Integration

Generated mapper `save` methods use time helpers based on field type:

- `PlainDateTime -> current_plain_date_time_utc()`
- `ZonedDateTime -> current_timestamp_utc()`

This is how `created_at`, `updated_at`, `#morm.auto_create_time`, and `#morm.auto_update_time` are implemented in generated code.
