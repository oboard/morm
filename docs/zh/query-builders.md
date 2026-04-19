---
outline: deep
---

# 查询构建器

`morm` 的查询构建器用于表达查询语义，不直接拼接 SQL 字符串。

这样可以保持参数绑定和方言渲染分层清晰。

## Select

基础查询：

```moonbit
let q = @morm.select_from("student")
```

添加筛选条件：

```moonbit
let q = @morm.select_from("student")
  .where_eq("id", 1)
  .where_ne("name", "Bob")
  .where_gte("age", 18)
  .where_lte("age", 30)
  .where_like("name", "A%")
```

添加排序：

```moonbit
let q = @morm.select_from("student")
  .order_by(@morm.desc("id"))
```

添加分页：

```moonbit
let q = @morm.select_from("student")
  .limit(20)
  .offset(40)
```

或者使用页码助手：

```moonbit
let q = @morm.select_from("student").page(3, 20)
```

或者使用 `Pageable`（推荐）：

```moonbit
let pageable = @morm.pageable_with_sort(1, 20, @morm.desc("id"))
let q = @morm.select_from("student")
  .where_gte("age", 18)
  .apply_pageable(pageable)
```

`Pageable.page` 采用 1 基页码（`1` 为第一页）。

## Select 指定列

```moonbit
let q = @morm.select_raw("student", "count(*)")
  .where_eq("age", 18)
```

## Insert

显式插入：

```moonbit
let q = @morm.insert_into("student")
  .columns(["name", "age"])
  .values([
    @engine.to_param("Alice"),
    @engine.to_param(18),
  ])
```

实体插入：

```moonbit
let q = @morm.insert_into("student").from(student)
```

## Upsert

```moonbit
let q = @morm.upsert_into("student")
  .set("id", 1)
  .set("name", "Alice")
  .on_conflict(["id"])
  .do_update_set("name", "Alice")
```

## Update

```moonbit
let q = @morm.update("student")
  .set("name", "Alice Updated")
  .where_eq("id", 1)
```

## Delete

```moonbit
let q = @morm.delete_from("student")
  .where_eq("id", 1)
```

## 渲染与执行

所有构建器都实现了 `@engine.QueryBuilder`，可以直接传给：

```moonbit
let res = engine.exec(q)
```

也可以执行原生 SQL：

```moonbit
let res = engine.exec_raw(
  "SELECT * FROM student WHERE id = ?",
  [1],
)
```

分页返回结构（`Page`、`Pageable`、`paginate`）见 [分页](/zh/pagination)。
