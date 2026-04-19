---
outline: deep
---

# Mappers

Mappers are the application-facing query layer. You declare an annotated trait, and `mormgen` expands it into ordinary MoonBit code.

The goal is to reduce repetitive query boilerplate without hiding the underlying SQL or query builder behavior.

## Basic Mapper Trait

```moonbit
///|
#morm.mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
  async count_students_by_age(Self, age : Int) -> Int?
}
```

`mormgen` emits:

- `StudentMapperImpl`
- `StudentMapperImpl::new(engine)`
- one generated implementation per trait method

## Binding A Mapper

You can bind a mapper with:

- `table="student"`
- `entity="Student"`

`table=` is usually the most direct form. If package entities can be discovered, the generator can also infer entity metadata from them.

## Method Derivation

Without `#morm.query`, the generator derives a conservative set of common query shapes from the method name.

Typical examples:

- `find_student_by_id`
- `find_student_by_name`
- `find_students_by_age_and_name`
- `count_students_by_age`
- `find_all`
- `all`

This is intentionally limited to routine read paths. If the naming starts to feel stretched, use explicit SQL or an explicit builder path instead.

## Explicit SQL

For exact control, use `#morm.query`.

```moonbit
///|
#morm.mapper(table="enrollment")
pub trait EnrollmentMapper {
  #morm.query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
}
```

This keeps:

- the SQL fully explicit
- params strongly typed
- result decoding centralized in generated code

## JOIN Extensions

`mormgen` also recognizes:

- `#morm.fetch_graph(join="...")`
- `#morm.load_graph(join="...")`

These append `.join(...)` to the derived builder path.

They are SQL composition helpers, not a full graph-loading runtime.

## Return Types

Mapper read methods currently support these return shapes:

- `T`
- `T?`
- `FixedArray[T]`
- `Array[T]`
- `@set.Set[T]`
- `@list.List[T]`
- `Map[K, T]`
- `@engine.Page[T]` (requires a `Pageable` parameter)

Behavior:

- `T` and `T?` decode the first returned row
- `FixedArray[T]` and `Array[T]` decode rows in order
- `@set.Set[T]` decodes rows and inserts them into a set
- `@list.List[T]` decodes rows and builds a list
- `Map[K, T]` decodes values row by row and then builds a keyed map

For `Map[K, T]`, key selection works like this:

- if `T` is a recognized entity, use its primary-key field
- otherwise fall back to reading `"id"` from the result row and decoding it as `K`

In practice, `Map[K, T]` works best for entity results where the query includes the primary-key column.

## Pageable Code Generation

`mormgen` can generate pageable mapper methods directly.

Example trait:

```moonbit
///|
#morm.mapper(table="user")
pub trait UserMapper {
  async find_users_page_by_active(
    Self,
    active : Int,
    pageable : @engine.Pageable,
  ) -> @engine.Page[User]
}
```

Generated implementation shape:

```moonbit
pub impl UserMapper for UserMapperImpl with find_users_page_by_active(
  self,
  active : Int,
  pageable : @engine.Pageable,
) -> @engine.Page[User] {
  let q = @morm.select_from("user").where_eq("active", active)
  @morm.paginate(
    self.engine,
    q,
    pageable,
    decode=(row) => User::_from(row),
  )
}
```

If you use explicit SQL via `#morm.query`, generation switches to `@morm.paginate_raw(...)`.

A full runnable sample is available in:

- `examples/mapper/schema.mbt`
- `examples/mapper/generated.mbt`
- `examples/mapper/main.mbt`

## Decoding Model

Generated mappers no longer depend on `FromJson`.

Query rows now enter generated code as `Map[String, @engine.Param]`, and decoding is performed through `@engine.from_param(...)` at the field or return-type level.

That means:

- entity field types must be decodable from `Param`
- non-entity scalar return types must also satisfy `FromParam`
- generated entity `_from(...)` functions are based on `Map[String, Param]`

## Special `save` Method

`save` is a recognized special method.

```moonbit
///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}
```

Generated behavior:

- rewrites the entity first when auto timestamp rules apply
- builds `@morm.upsert_into(...).from(entity)`
- executes through the engine
- decodes the first returned row into the declared return type

## Special `delete` Method

`delete` is also recognized:

```moonbit
///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async delete(Self, entity : Class) -> Bool
}
```

This generates a delete path based on entity identity.

## Auto Timestamp Injection

Generated `save` methods, and some generated `update` paths, can assign time fields before building the statement.

Trigger rules:

- field named `created_at`
- field named `updated_at`
- `#morm.auto_create_time`
- `#morm.auto_update_time`

Value rules:

- `PlainDateTime -> @morm.current_plain_date_time_utc()`
- `ZonedDateTime -> @morm.current_timestamp_utc()`

## When To Use Mappers

Mappers are a good fit for:

- standard CRUD entry points
- simple lookup and listing methods
- stable application-facing query interfaces

Use explicit query builders or raw SQL when:

- the SQL is highly engine-specific
- derived naming becomes awkward
- write behavior needs custom conflict, return, or update rules

## Debugging Mapper Behavior

When a generated method is not doing what you expect, inspect things in this order:

1. the source trait
2. the generated `.g.mbt`
3. the concrete engine implementation used at runtime

That is the intended debugging path.
