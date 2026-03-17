---
outline: deep
---

# 时间类型

`morm` 对时间类型提供跨引擎参数与序列化支持。

## 支持类型

- `PlainDate`
- `PlainTime`
- `PlainDateTime`
- `ZonedDateTime`

## 使用建议

- 业务时间建议统一时区策略
- 创建/更新时间字段配合自动时间注解
- 跨服务系统明确时间精度与格式

英文详解： [Time Types](/time)。
