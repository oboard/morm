---
outline: deep
---

# SQLite 引擎

SQLite 适合本地开发、桌面工具和测试环境，依赖简单、上手成本低。

## 包导入

```moonbit
using @oboard/morm/engine/sqlite3 as @sqlite3
```

## 连接方式

- `:memory:` 内存数据库
- 文件路径数据库

## 参数与占位符

- 使用 `?` 占位符
- 参数按顺序绑定

## 适用建议

- 单进程读写优先
- 高并发写入场景建议评估 MySQL 或 PostgreSQL
