---
outline: deep
---

# MySQL Engine

MySQL 引擎面向典型 OLTP 场景，兼顾性能与运维生态。

## Package

```moonbit
using @oboard/morm/engine/mysql as @mysql
```

## DSN 与连接

```moonbit
let engine = match
  @mysql.MySQLEngine::open("mysql://root:password@127.0.0.1:3306/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

## 占位符与参数

- 使用 `?` 占位符
- 参数顺序必须与 SQL 中占位符顺序一致

## 事务行为

- 支持 `BEGIN` / `COMMIT` / `ROLLBACK`
- 事务期间连接会保持绑定，避免跨连接状态不一致

## 迁移特性

- `migrate_table` 支持自动建表与常见列定义同步
- 复杂索引与引擎级参数建议在迁移后追加定制 SQL

## 使用建议

- 字符集建议统一 UTF-8（utf8mb4）
- 时间类型建议结合 `@morm/time` 明确应用层时区语义
- 线上连接数建议配合连接池参数按并发规模配置
