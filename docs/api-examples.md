---
outline: deep
---

# API Examples

This page shows concrete `morm` usage patterns with real API names from the library.

## Core Imports

Typical code imports look like:

```moonbit
using @oboard/morm as @morm
using @oboard/morm/engine as @engine
using @oboard/morm/time as @time
```

The exact package aliases are up to you, but these names make examples easy to read.

## Entity Definition Example

```moonbit
///|
using @time {type PlainDateTime, type ZonedDateTime}

///|
#entity
pub(all) struct Class {
  #id
  #default(autoincrement())
  id : Int64

  #varchar(length="255")
  name : String

  #foreign_key(references="teacher.id", on_delete="CASCADE")
  teacher_id : Int

  created_at : PlainDateTime
  updated_at : PlainDateTime
} derive(ToJson, FromJson)

///|
#entity
pub(all) struct Teacher {
  #id
  #default(autoincrement())
  id : Int64
  name : String
  major : String
  age : Int
  birth_date : ZonedDateTime?
} derive(ToJson, FromJson)
```

Generated entity code gives you:

```moonbit
let table = Class::table()
```

`table` is an `@morm.Table` value that can be passed to migration helpers or inspected in tests.

## Basic Query Builder Examples

### Simple Select

```moonbit
let q = @morm.select_from("student")
```

This builds a select query that defaults to `SELECT * FROM student`.

### Select With Filters

```moonbit
let q = @morm.select_from("student")
  .where_eq("id", 1)
  .where_eq("name", "Alice")
```

### Select With Comparison Operators

```moonbit
let q = @morm.select_from("student")
  .where_gte("age", 18)
  .where_lt("age", 30)
  .where_like("name", "A%")
```

### Ordering, Limit, And Offset

```moonbit
let q = @morm.select_from("student")
  .order_by(@morm.Desc("id"))
  .limit(20)
  .offset(40)
```

### JOIN

```moonbit
let q = @morm.select_from("enrollment")
  .join("LEFT JOIN student ON student.id = enrollment.student_id")
  .where_eq("enrollment.id", 1)
```

## Insert Examples

### Insert From Individual Values

```moonbit
let q = @morm.insert_into("student")
  .columns(["name", "age"])
  .values([
    @engine.to_param("Alice"),
    @engine.to_param(18),
  ])
```

### Insert From Entity

```moonbit
let student : Student = {
  id: 1,
  name: "Alice",
  age: 18,
  birth_date: @morm.current_timestamp_utc(),
}

let q = @morm.insert_into("student").from(student)
```

When `.from(entity)` is used, the entity is converted through `ToJson`, then fields are turned into params.

## Upsert Examples

### Upsert From Entity

```moonbit
let q = @morm.upsert_into("class").from(entity)
```

The conflict target is inferred from:

- the primary key if present
- otherwise the first unique index found in table metadata

### Upsert With Explicit Conflict Update

```moonbit
let q = @morm.upsert_into("student")
  .set("id", 1)
  .set("name", "Alice")
  .on_conflict(["id"])
  .do_update_set("name", "Alice")
```

Exact emitted SQL is engine-specific.

## Update Examples

```moonbit
let q = @morm.update("student")
  .set("name", "Alice Updated")
  .set("age", 19)
  .where_eq("id", 1)
```

## Delete Examples

### Delete By Condition

```moonbit
let q = @morm.delete_from("student")
  .where_eq("id", 1)
```

### Delete From Entity

```moonbit
let q = @morm.delete_from("student").from(student)
```

The entity-driven delete path uses the entity's table metadata and key fields.

## Scoped Select Example

If you use a soft-delete column, `select_from_scoped` is available:

```moonbit
let q = @morm.select_from_scoped("student", deleted_col="deleted")
  .where_eq("id", 1)
```

This helper applies the built-in boolean convention `deleted = false` before adding your extra filters.

## Parameter Conversion Examples

### Primitive Params

```moonbit
let p1 = @engine.to_param(1)
let p2 = @engine.to_param(true)
let p3 = @engine.to_param("Alice")
```

### JSON Param

```moonbit
let payload = {
  "name": "Alice".to_json(),
  "age": 18.to_json(),
}.to_json()

let p = @engine.to_param(payload)
```

### Time Params

```moonbit
let created_at = @morm.current_plain_date_time_utc()
let published_at = @morm.current_timestamp_utc()

let p1 = @engine.to_param(created_at)
let p2 = @engine.to_param(published_at)
```

These become:

- `Param::DateTime` for `PlainDateTime`
- `Param::Timestamp` for `ZonedDateTime`

## JSON Round-Trip With Time Types

The local time package supports JSON encoding and decoding directly.

```moonbit
let ts = @morm.current_timestamp_utc()
let json = ts.to_json()
let parsed : @time.ZonedDateTime = try! @json.from_json(json)
```

This is useful when your entity derives `ToJson` and `FromJson` and includes time fields.

## Auto Timestamp Examples

### Convention-Based Fields

```moonbit
///|
#entity
pub(all) struct AuditRow {
  #id
  id : Int64
  created_at : @time.PlainDateTime
  updated_at : @time.PlainDateTime
} derive(ToJson, FromJson)
```

If a generated mapper has:

```moonbit
async save(Self, entity : AuditRow) -> AuditRow
```

then `mormgen` injects timestamp assignment code before the `upsert`.

### Custom Field Names

```moonbit
///|
#entity
pub(all) struct AuditRow {
  #id
  id : Int64

  #auto_create_time
  inserted_on : @time.PlainDateTime

  #auto_update_time
  touched_on : @time.ZonedDateTime
} derive(ToJson, FromJson)
```

Generated values depend on the field type:

- `PlainDateTime -> @morm.current_plain_date_time_utc()`
- `ZonedDateTime -> @morm.current_timestamp_utc()`

## Mapper Examples

### Derived Query Methods

```moonbit
///|
#mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
  async count_students_by_age(Self, age : Int) -> Int?
  async find_all(Self) -> FixedArray[Student]
}
```

These are generated from method names without explicit SQL strings.

### Raw SQL Mapper Method

```moonbit
///|
#mapper(table="enrollment")
pub trait EnrollmentMapper {
  #query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
}
```

### JOIN Mapper Method

```moonbit
///|
#mapper(table="enrollment")
pub trait EnrollmentMapper {
  #fetch_graph(join="LEFT JOIN student ON student.id = enrollment.student_id")
  async find_with_student_by_id(Self, id : Int) -> Enrollment?
}
```

This extends the generated query builder with `.join(...)`.

### Special Save Method

```moonbit
///|
#mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}
```

This method is generated as an upsert-backed save path and can apply auto timestamp fields before building the query.

### Special Delete Method

```moonbit
///|
#mapper(table="class")
pub trait ClassMapper {
  async delete(Self, entity : Class) -> Bool
}
```

`delete` is treated as a recognized special method by the generator.

## Using A Generated Mapper

```moonbit
let mapper = StudentMapperImpl::new(engine)

let student = mapper.find_student_by_id(1)
let adults = mapper.find_students_by_age(18)
```

The concrete `engine` value must satisfy the `@engine.Engine` trait.

## Raw Engine Execution

If you do not want the query builder path, call raw SQL directly on the engine.

```moonbit
let res = engine.exec_raw(
  "SELECT * FROM student WHERE id = ?",
  [@engine.to_param(1)],
)
```

This is useful when:

- the SQL is too specialized for name derivation
- you need engine-specific syntax
- you are debugging a database issue

## Migration Example

```moonbit
@morm.auto_migrate(engine, [
  Class::table(),
  Student::table(),
  Teacher::table(),
])
```

The engine receives schema JSON and performs the actual migration logic. `morm` does not impose one universal DDL diff strategy.

## Inspecting Generated Metadata

You can assert on metadata in tests:

```moonbit
let table = Class::table()
assert_eq(table.name, "class")
assert_eq(table.columns.length(), 5)
assert_eq(table.columns[3].name, "created_at")
assert_eq(table.columns[3].column_type, @morm.ColumnType::DateTime)
```

This is a good way to keep schema expectations explicit.

## Recommended Patterns

Prefer these patterns:

- use generated mappers for simple app-facing CRUD
- use explicit `#query` when SQL matters
- use `PlainDateTime` for `created_at` / `updated_at` unless offset is a real domain requirement
- inspect `.g.mbt` output when behavior becomes non-trivial
- keep engine-specific behavior in the engine package, not in entity code

## Patterns To Avoid

Avoid these assumptions:

- assuming all engines render identical upsert SQL
- assuming ORM runtime will parse arbitrary date strings back into time values
- assuming auto timestamp generation preserves create-time semantics on update-only paths
- assuming relation annotations imply a full transparent object graph loader

## End-To-End Example

```moonbit
let class_mapper = ClassMapperImpl::new(engine)

let entity : Class = {
  id: 1,
  name: "Databases",
  teacher_id: 7,
  created_at: @morm.current_plain_date_time_utc(),
  updated_at: @morm.current_plain_date_time_utc(),
}

let saved = class_mapper.save(entity)

let res = @engine.exec_query(
  engine,
  @morm.select_from("class").where_eq("id", saved.id),
)
let rows = res.rows
```

This combines:

- generated mapper construction
- automatic save/upsert logic
- typed time values
- direct query builder usage for follow-up reads

## CLI Examples

Inside this repository:

```bash
moon run mormgen -- example/entities.mbt -o example/entities.g.mbt
moon run mormgen -- example/mapper.mbt -o example/mapper.g.mbt
```

Inside a dependent project, the packaged binary is typically called by your `pre-build` hook:

```bash
$mod_dir/.mooncakes/oboard/morm/morm-gen entities.mbt -o entities.g.mbt
```

## Final Note

The fastest way to understand any `morm` API is:

1. look at your source annotations
2. look at the generated `.g.mbt`
3. look at the engine implementation that actually executes the statement

That is the intended debugging workflow.
