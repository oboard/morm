---
outline: deep
---

# API 示例

本页给出常见能力的最小可用示例。

## QueryBuilder 执行

```moonbit
let q = @morm.select_from("student")
  .where_eq("id", 1)
  .order_by(@morm.desc("id"))
  .limit(1)

let res = engine.exec(q)
```

## Pageable 分页

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))

let q = @morm.select_from("student")
  .where_gte("age", 18)

let page = @morm.paginate(
  engine,
  q,
  pageable,
)
```

## 原生 SQL 分页

```moonbit
let page = @morm.paginate_raw(
  engine,
  "SELECT id, name FROM student WHERE age >= ?",
  [18],
  @morm.pageable(2, 10),
)
```

## 迁移

```moonbit
@morm.auto_migrate(engine, [Student::table()])
```

进一步说明：

1. [快速开始](/zh/get-started)
2. [查询构建器](/zh/query-builders)
3. [分页](/zh/pagination)
4. [引擎总览](/zh/engines)
