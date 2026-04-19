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

## 构建查询 + Pageable

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))

let q = @morm.select_from("student")
  .where_gte("age", 18)
```

## 获取分页结果

使用 `paginate`（通过 `T : @engine.FromParam` 自动解码）：

```moonbit
let page = @morm.paginate(
  engine,
  q,
  pageable,
)
```

使用 `paginate_raw`：

```moonbit
let page = @morm.paginate_raw(
  engine,
  "SELECT id, name FROM student WHERE age >= ?",
  [18],
  @morm.pageable(2, 10),
)
```

## 计数 SQL 说明

`paginate` 和 `paginate_raw` 默认会从第一处 `FROM` 开始推导 `COUNT(*)` SQL。

如果你的 SQL 比较复杂（例如 CTE、嵌套子查询、分组投影），建议写更明确的 SQL。

## 跨引擎兼容性

`paginate` 会把分页数据查询委托给引擎侧的 `page/page_raw`，由各数据库引擎处理自身分页语法。

这样可以在 `morm` 层保持统一 API，同时兼顾方言差异。
