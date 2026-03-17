---
outline: deep
---

# 迁移

迁移负责把实体元数据同步为数据库结构。

## 使用方式

- 直接调用 `engine.migrate_table(table)`
- 或使用 `@morm.auto_migrate(engine, tables)`

## 注意事项

- 各引擎 DDL 能力不同，行为由引擎实现决定
- 复杂变更建议配合手写 SQL 迁移
- 线上迁移建议做灰度与回滚预案

英文详解： [Migrations](/migrations)。
