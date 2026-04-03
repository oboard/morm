---
outline: deep
---

# 实体

实体是 `morm` 的建模入口，使用 MoonBit struct 配合注解描述表结构。

## 常见注解

- `#morm.entity` 标记实体
- `#morm.id` 标记主键
- `#morm.default(autoincrement())` 自增键
- `#morm.foreign_key(...)` 外键
- `#morm.transient` 非持久字段

## 类型映射

- `T` 表示非空列
- `T?` 表示可空列
- 时间类型与 Json 类型均支持自动映射
- 无 payload 的 MoonBit `enum` 会直接映射为 ORM enum 列

## Enum 支持

下面这种枚举现在可以直接作为实体字段：

```moonbit
///|
pub(all) enum PostStatus {
  Draft
  Published
  Archived
} derive(ToJson, FromJson, Show)

///|
#morm.entity
pub(all) struct Post {
  #morm.id
  id : Int
  status : PostStatus
} derive(ToJson, FromJson)
```

`mormgen` 会自动生成：

- `impl @engine.ToParam for PostStatus`
- `impl @engine.FromParam for PostStatus`
- `ColumnType::Enum("PostStatus", [...])`

当前各引擎行为：

- MySQL 使用原生 `ENUM(...)`
- PostgreSQL 先建原生 enum type，再在表字段上引用
- SQLite / SQL Server / Oracle 暂时退化为字符串列类型

限制：

- 仅支持不带 payload 的 enum 作为数据库 enum
- 如果字段上显式写了 `#morm.varchar` / `#morm.text` 等类型注解，则以显式注解为准

完整参考见英文版 [Entities](/entities)。
