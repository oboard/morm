---
outline: deep
---

# Pagination

`morm` provides a consistent page API on top of query builders and raw SQL.

## Core Types

- `SortDirection`: `Asc` / `Desc`
- `Sort`: `{ property, direction }`
- `Pageable`: `{ page, size, sort? }`
- `Page[T]`: `{ content, total_elements, total_pages, number, size, first, last, empty }`

Helpers:

- `@morm.pageable(page, size)`
- `@morm.pageable_with_sort(page, size, sort)`
- `@morm.sort(property, direction)`
- `@morm.asc(property)` / `@morm.desc(property)`

`page` is **1-based** (`1` is the first page).

## Apply Pagination To Query Builders

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))

let q = @morm.select_from("student")
  .where_gte("age", 18)
  .apply_pageable(pageable)
```

`Query::apply_pageable` sets:

- `limit = size`
- `offset = (page - 1) * size`
- optional `order_by` from `sort`

## Fetch A Typed Page

Use `paginate` with a decode function:

```moonbit
let page = @morm.paginate(
  engine,
  q,
  pageable,
  decode=(row) => row,
)
```

Use `paginate_raw` for raw SQL:

```moonbit
let page = @morm.paginate_raw(
  engine,
  "SELECT id, name FROM student WHERE age >= ?",
  [18],
  @morm.pageable(2, 10),
  decode=(row) => row,
)
```

## Counting Behavior

Both `paginate` and `paginate_raw` generate a count SQL by slicing from the first `FROM`.

For complex SQL (nested selects, CTEs, grouped projections), pass a dedicated count SQL through
`engine.exec_paginated(...)` if you need full control.

## Engine Compatibility

`paginate` delegates page execution to `engine.exec_paginated(...)`.

That lets each engine apply its own pagination dialect while keeping one page API in `morm`.
