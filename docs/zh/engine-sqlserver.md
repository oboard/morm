---
outline: deep
---

# SQL Server 引擎

SQL Server 适用于企业内网与微软技术栈场景。

## 包导入

```moonbit
using @oboard/morm/engine/sqlserver as @sqlserver
```

## DSN 示例

```moonbit
sqlserver://sa:password@127.0.0.1:1433/app_db
```

## 参数与事务

- 使用 `?` 占位符
- 支持标准事务语义

## 使用建议

- 明确 NVARCHAR/VARCHAR 选择
- 关注不同版本 SQL Server 兼容性
