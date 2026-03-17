---
outline: deep
---

# MongoDB 引擎

MongoDB 引擎既可通过统一 `Engine` 接口使用，也可走文档数据库原生能力。

## 包导入

```moonbit
using @oboard/morm/engine/mongodb as @mongodb
```

## DSN 示例

```moonbit
mongodb://127.0.0.1:27017/app_db
```

## 核心能力

- `exec_raw` 统一执行入口
- BSON/JSON 数据协同处理
- 文档查询与聚合场景支持

## 相关文档

- 英文版引擎页： [MongoDB Engine](/engine-mongodb)
- 原生客户端说明： [MongoDB Client](/mongodb-client)
