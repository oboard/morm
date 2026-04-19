---
outline: deep
---

# 分页

`morm` 为查询构建器和原生 SQL 提供统一分页 API。

## 核心类型

- `SortDirection`: `Asc` / `Desc`
- `Sort`: `{ property, direction }`
- `Pageable`: `{ page, size, sort? }`
- `Page[T]`: `{ content, total_elements, total_pages, number, size, first, last, empty }`

常用助手：

- `@morm.pageable(page, size)`
- `@morm.pageable_with_sort(page, size, sort)`
- `@morm.sort(property, direction)`
- `@morm.asc(property)` / `@morm.desc(property)`

`page` 采用 **1 基页码**（`1` 表示第一页）。

## 在查询构建器上应用分页

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))

let q = @morm.select_from("student")
  .where_gte("age", 18)
  .apply_pageable(pageable)
```

`Query::apply_pageable` 会设置：

- `limit = size`
- `offset = (page - 1) * size`
- 若存在 `sort`，追加对应 `order_by`

## 获取分页结果

使用 `paginate`：

```moonbit
let page = @morm.paginate(
  engine,
  q,
  pageable,
  decode=(row) => row,
)
```

使用 `paginate_raw`：

```moonbit
let page = @morm.paginate_raw(
  engine,
  "SELECT id, name FROM student WHERE age >= ?",
  [18],
  @morm.pageable(2, 10),
  decode=(row) => row,
)
```

## 计数 SQL 说明

`paginate` 和 `paginate_raw` 默认会从第一处 `FROM` 开始推导 `COUNT(*)` SQL。

如果你的 SQL 比较复杂（例如 CTE、嵌套子查询、分组投影），建议直接使用
`engine.exec_paginated(...)` 并显式传入 count SQL。

## 跨引擎兼容性

`paginate` 内部调用 `engine.exec_paginated(...)`，由各数据库引擎处理自身分页语法。

这样可以在 `morm` 层保持统一 API，同时兼顾方言差异。
