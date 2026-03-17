---
layout: home

hero:
  name: "morm"
  text: "MoonBit ORM Toolkit"
  tagline: "类型驱动建模、可读可查的代码生成、跨引擎一致的查询构建。"
  actions:
    - theme: brand
      text: 快速开始
      link: /get-started
    - theme: alt
      text: 架构设计
      link: /architecture
    - theme: alt
      text: 引擎总览
      link: /engines

features:
  - title: 实体优先建模
    details: "直接基于 MoonBit struct 定义实体，生成 table 元数据，类型和数据库结构天然同步。"
  - title: 强类型查询构建
    details: "用 select/insert/update/delete/upsert builder 写查询，不再手写易错 SQL 字符串。"
  - title: 多引擎统一入口
    details: "同一套语义可覆盖 SQLite、MySQL、PostgreSQL、SQL Server、Oracle、MongoDB。"
  - title: Mapper 自动生成
    details: "通过 mormgen 生成 mapper 实现，减少模板代码并保持调用接口清晰。"
  - title: JSON 与时间类型友好
    details: "对 Json、PlainDate/Time/DateTime、ZonedDateTime 提供一致参数与序列化路径。"
  - title: 引擎边界清晰
    details: "查询构建、SQL 渲染、执行与迁移职责分离，便于排障、扩展和维护。"
---

## 文档导览

- 新手入口：从 [Get Started](/get-started) 开始，按步骤完成实体定义、代码生成与查询执行
- 核心能力：在 [Entities](/entities)、[Mappers](/mappers)、[Query Builders](/query-builders) 逐层深入
- 引擎细节：查看 [Engines](/engines) 与各引擎专题页了解方言、连接、事务与迁移差异
- API 示例：在 [API Examples](/api-examples) 查看可直接复制改造的实战片段
