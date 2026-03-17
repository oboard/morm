---
outline: deep
---

# Oracle 引擎

Oracle 适合已有 Oracle 数据资产和企业级治理体系的组织。

## 包导入

```moonbit
using @oboard/morm/engine/oracle as @oracle
```

## DSN 示例

```moonbit
oracle://system:password@127.0.0.1:1521/XEPDB1
```

## 参数与事务

- 参数统一走 `@engine.Param`
- 支持事务提交与回滚

## 使用建议

- 提前约定命名与类型规范
- 序列、触发器等对象建议配套专门迁移脚本
