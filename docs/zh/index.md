---
layout: home

hero:
  name: "morm"
  text: "MoonBit ORM 工具包"
  tagline: "类型驱动建模、可读代码生成、跨引擎一致查询。"
  actions:
    - theme: brand
      text: 快速开始
      link: /zh/get-started
    - theme: alt
      text: 架构设计
      link: /zh/architecture
    - theme: alt
      text: 引擎专题
      link: /zh/engines

features:
  - title: 实体优先
    details: "直接从 MoonBit struct 生成 table 元数据，领域模型与数据库结构保持一致。"
  - title: 强类型查询
    details: "通过查询构建器完成增删改查，避免手写 SQL 拼接错误。"
  - title: 多引擎支持
    details: "统一 API 可覆盖 SQLite、MySQL、PostgreSQL、SQL Server、Oracle 与 MongoDB。"
  - title: Mapper 生成
    details: "使用 mormgen 从 trait 生成 mapper 实现，减少重复模板代码。"
  - title: JSON 与时间类型
    details: "对 Json 与 PlainDate/Time/DateTime/ZonedDateTime 提供一致处理路径。"
  - title: 清晰职责边界
    details: "查询构建、SQL 渲染、执行与迁移分层明确，便于调试与扩展。"
---

## 文档导览

- 入门路径：[快速开始](/zh/get-started)
- 核心能力：[实体](/zh/entities)、[映射器](/zh/mappers)、[查询构建器](/zh/query-builders)、[分页](/zh/pagination)
- 引擎细节：[引擎总览](/zh/engines) 与各引擎专题
- 示例参考：[API 示例](/zh/api-examples)
