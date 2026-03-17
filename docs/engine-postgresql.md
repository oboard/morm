---
outline: deep
---

# PostgreSQL Engine

PostgreSQL 引擎适合对标准一致性、扩展能力和复杂查询有要求的场景。

## Package

```moonbit
using @oboard/morm/engine/postgres as @pgsql
```

## DSN 与连接

```moonbit
let engine = match
  @pgsql.PgSQLEngine::open("postgres://postgres@127.0.0.1:5432/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

## 占位符与参数

- 使用 `$1`, `$2`, `$3` 风格占位符
- 参数类型保持 `@engine.Param` 的语义化绑定

## 事务行为

- 支持事务、保存点与回滚到保存点
- 适合复杂业务事务拆分与组合

## 迁移特性

- 支持 `migrate_table` 自动处理常见 DDL
- JSON / JSONB、时间列等能力可在 schema 中明确声明

## 使用建议

- 对 JSON 查询较多时优先使用 JSONB 列
- 对审计或时间线查询，建议配合 `timestamp` 与索引设计
- 复杂 SQL 可以通过 `exec_raw` 与查询构建混合使用
