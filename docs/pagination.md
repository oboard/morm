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

## Build Query + Pageable

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))

let q = @morm.select_from("student")
  .where_gte("age", 18)
```

## Fetch A Typed Page

Use `paginate` directly (it decodes rows via `T : @engine.FromParam`):

```moonbit
let page = @morm.paginate(
  engine,
  q,
  pageable,
)
```

Use `paginate_raw` for raw SQL:

```moonbit
let page = @morm.paginate_raw(
  engine,
  "SELECT id, name FROM student WHERE age >= ?",
  [18],
  @morm.pageable(2, 10),
)
```

## Counting Behavior

Both `paginate` and `paginate_raw` generate a count SQL by slicing from the first `FROM`.

For complex SQL (nested selects, CTEs, grouped projections), prefer explicit tailored SQL.

## Engine Compatibility

`paginate` delegates data-page SQL to engine-side `page/page_raw`, so each engine can apply
its own pagination dialect while keeping one API in `morm`.
