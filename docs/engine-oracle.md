---
outline: deep
---

# Oracle Engine

Oracle 引擎适合已有 Oracle 数据资产、对企业级稳定性和生态依赖较强的场景。

## Package

```moonbit
using @oboard/morm/engine/oracle as @oracle
```

## DSN 与连接

```moonbit
let engine = match
  @oracle.OracleEngine::open("oracle://system:password@127.0.0.1:1521/XEPDB1") {
  Ok(e) => e
  Err(_) => panic()
}
```

## 占位符与参数

- 使用 Oracle 兼容的参数渲染策略
- 参数统一走 `@engine.Param`，避免字符串拼接注入风险

## 事务行为

- 支持事务提交与回滚
- 对多语句过程可通过 `exec_raw` 明确控制执行顺序

## 迁移特性

- 支持 `migrate_table` 的核心建表能力
- Oracle 特定对象（如序列、触发器）建议单独维护迁移脚本

## 使用建议

- 命名长度与大小写策略尽量统一
- 对数字与时间列类型提前约定，减少跨系统映射歧义
- 结合 DBA 规范管理权限、索引与执行计划
