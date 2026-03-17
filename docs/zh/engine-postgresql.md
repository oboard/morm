---
outline: deep
---

# PostgreSQL 引擎

PostgreSQL 适合复杂查询、扩展能力要求高和标准一致性要求高的系统。

## 包导入

```moonbit
using @oboard/morm/engine/postgres as @pgsql
```

## DSN 示例

```moonbit
postgres://postgres@127.0.0.1:5432/app_db
```

## 参数与事务

- 使用 `$1/$2/$3` 占位符
- 支持事务与保存点

## 使用建议

- JSON 查询密集场景优先 JSONB
- 复杂业务流程可结合 `exec_raw` 使用
