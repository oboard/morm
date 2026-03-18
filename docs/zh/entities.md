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

完整参考见英文版 [Entities](/entities)。
