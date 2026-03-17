---
outline: deep
---

# 映射器

映射器用于把常见查询模式声明成 trait，再由 `mormgen` 生成实现。

## 工作方式

1. 编写带注解的 mapper trait
2. 运行生成器生成 `.g.mbt`
3. 通过 `MapperImpl::new(engine)` 注入引擎使用

## 适用场景

- 常见按主键、按字段查询
- 领域操作的固定查询模板
- 希望统一错误处理和参数规范的团队项目

英文版本： [Mappers](/mappers)。
