---
outline: deep
---

# Mappers

Mappers are the application-facing layer generated from annotated traits.

They exist to reduce repetitive query code without hiding what actually runs.

## Basic Mapper Trait

```moonbit
///|
#mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
  async count_students_by_age(Self, age : Int) -> Int?
}
```

`mormgen` reads this and emits:

- `StudentMapperImpl`
- `StudentMapperImpl::new(engine)`
- method implementations that build or execute queries

## Binding A Mapper

You can bind a mapper by:

- `table="student"`
- `entity="Student"`

Using `table=` is often the most direct option, and the generator can infer the entity by scanning package entities.

## Method Derivation

Without `#query`, the generator derives common query shapes from method names.

Examples:

- `find_student_by_id`
- `find_student_by_name`
- `find_students_by_age_and_name`
- `count_students_by_age`
- `find_all`
- `all`

This is intentionally conservative. It covers routine read patterns and stops there.

## Explicit SQL

For exact control, use `#query`.

```moonbit
///|
#mapper(table="enrollment")
pub trait EnrollmentMapper {
  #query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
}
```

This keeps:

- your SQL exact
- params typed
- result decoding centralized

## JOIN Extensions

`mormgen` also recognizes:

- `#fetch_graph(join="...")`
- `#load_graph(join="...")`

These append `.join(...)` to the derived builder path.

They are SQL composition helpers, not a full lazy-loading graph runtime.

## Special `save` Method

`save` is a recognized special method.

```moonbit
///|
#mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}
```

Generated behavior:

- rewrites the entity first if auto timestamp fields are configured
- builds `@morm.upsert_into(...).from(entity)`
- executes through the engine
- decodes the first returned row into the result type

## Special `delete` Method

`delete` is also recognized:

```moonbit
///|
#mapper(table="class")
pub trait ClassMapper {
  async delete(Self, entity : Class) -> Bool
}
```

This generates a delete path based on entity identity.

## Auto Timestamp Injection

For generated `save`, the mapper can assign timestamps before building the upsert.

Trigger rules:

- `created_at`
- `updated_at`
- `#auto_create_time`
- `#auto_update_time`

Value rules:

- `PlainDateTime -> @morm.current_plain_date_time_utc()`
- `ZonedDateTime -> @morm.current_timestamp_utc()`

## Async And Sync Shape

Mapper traits typically use `async` methods, and the generated implementation follows that shape.

The generated code stays straightforward:

- build query or call raw SQL
- execute via engine
- decode JSON rows

There is no hidden session or unit-of-work layer.

## When To Use Mappers

Mappers are a good fit for:

- standard CRUD entry points
- simple listing and lookup methods
- app-facing repository-like interfaces

Use explicit query builders or raw SQL instead when:

- SQL is too engine-specific
- the query is complex enough that method-name derivation becomes awkward
- write semantics need custom conflict/update rules

## Debugging Mapper Behavior

When a generated method is not doing what you expect:

1. inspect the source trait
2. inspect the generated `.g.mbt`
3. inspect the engine implementation used at runtime

That is the intended debugging path.
