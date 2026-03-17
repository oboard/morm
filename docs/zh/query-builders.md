---
outline: deep
---

# 查询构建器

查询构建器负责表达查询意图，最终交给引擎渲染并执行。

## 支持能力

- `select_from`
- `insert_into`
- `update`
- `delete_from`
- `upsert_into`

## 推荐实践

- 业务层尽量表达语义，不拼接 SQL 字符串
- 复杂 SQL 使用 `exec_raw` 与构建器混合
- 参数统一使用 `@engine.Param` 体系

英文详解： [Query Builders](/query-builders)。
