---
outline: deep
---

# 快速开始

`morm` 是 MoonBit 的轻量 ORM 工具包，核心目标是让结构定义、查询构建、引擎执行都清晰可查。

## 你会得到什么

- 基于实体定义自动生成 `table()` 元数据
- 使用强类型查询构建器组织 SQL 语义
- 通过 mapper 代码生成减少重复样板
- 在多引擎下复用一致的查询与参数模型

## 基础流程

1. 在 `moon.mod.json` 中加入 `oboard/morm`
2. 定义实体与 mapper trait
3. 使用 `mormgen` 生成 `.g.mbt`
4. 初始化引擎并执行迁移
5. 使用 query builder 或 mapper 执行业务查询

## 下一步

- 架构理解： [架构设计](/zh/architecture)
- 数据模型： [实体](/zh/entities)
- 查询能力： [查询构建器](/zh/query-builders)
- 引擎差异： [引擎总览](/zh/engines)

完整英文教程可参考 [English Get Started](/get-started)。
