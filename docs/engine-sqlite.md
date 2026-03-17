---
outline: deep
---

# SQLite Engine

SQLite 引擎适合本地开发、单机工具和测试场景，部署简单、依赖最少。

## Package

```moonbit
using @oboard/morm/engine/sqlite3 as @sqlite3
```

## DSN 与连接

- 内存数据库：`:memory:`
- 文件数据库：`/absolute/path/to/app.db`

```moonbit
let engine = @sqlite3.SQLiteEngine::open(":memory:")
```

## 占位符与参数

- 使用 `?` 占位符
- 参数按顺序绑定

```moonbit
let res = engine.exec_raw(
  "SELECT * FROM user WHERE id = ?",
  [@engine.Int(1)],
)
```

## 事务行为

- 支持标准事务与保存点
- 事务语义由 SQLite 原生能力决定
- 测试与本地调试时推荐优先使用 SQLite 验证查询逻辑

## 迁移特性

- 支持 `migrate_table` 与 `@morm.auto_migrate`
- 对列变更与索引更新的处理遵循 SQLite DDL 能力边界

## 使用建议

- 单进程应用可直接使用
- 多进程并发写场景建议评估锁竞争
- 生产环境如需高并发写入，优先考虑 MySQL 或 PostgreSQL
