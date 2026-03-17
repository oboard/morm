---
outline: deep
---

# MongoDB Engine

MongoDB 引擎既支持通过统一 `Engine` 接口执行语句，也支持原生文档客户端能力。

## Package

```moonbit
using @oboard/morm/engine/mongodb as @mongodb
```

## DSN 与连接

```moonbit
let engine = match
  @mongodb.MongoDBEngine::open("mongodb://127.0.0.1:27017/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

## 执行模型

- `exec_raw` 接收语句或命令并返回统一 `QueryResult`
- 文档结果以 JSON 结构返回，便于直接映射到业务结构
- 对 BSON 字段可与 `@oboard/morm/bson` 配合处理

## 事务与一致性

- 事务相关语义通过引擎统一接口暴露
- 实际可用能力取决于 MongoDB 部署模式与版本配置

## 迁移特性

- 支持表结构元数据接入统一迁移流程
- 文档数据库下的演进通常结合应用层版本化策略进行

## 原生客户端能力

除了统一 ORM 接口外，还可以使用 MongoDB 专属能力，详见：

- [MongoDB Client](./mongodb-client.md)

该页面覆盖聚合、distinct、计数、findOneAndUpdate 等文档场景常用能力。

## 使用建议

- 文档结构变更建议使用渐进兼容策略
- 对高频查询字段建立索引并持续观察执行计划
- 明确 `_id` 与业务唯一键的职责边界
