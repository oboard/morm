---
outline: deep
---

# SQL Server Engine

SQL Server 引擎适用于企业内网、微软技术栈或已有 SQL Server 基础设施的系统。

## Package

```moonbit
using @oboard/morm/engine/sqlserver as @sqlserver
```

## DSN 与连接

```moonbit
let engine = match
  @sqlserver.SQLServerEngine::open("sqlserver://sa:password@127.0.0.1:1433/app_db") {
  Ok(e) => e
  Err(_) => panic()
}
```

## 占位符与参数

- 使用 `?` 占位符
- 由引擎在底层协议层完成参数传递与类型映射

## 事务行为

- 支持标准事务语义
- 批量 SQL 与事务组合场景可通过 `exec_raw` 执行

## 迁移特性

- 支持 `migrate_table` 处理主流表结构演进
- 对 SQL Server 特有 DDL 建议使用补充 SQL 做精细化控制

## 使用建议

- 明确 NVARCHAR/VARCHAR 语义，避免字符集差异
- 注意 SQL Server 版本差异带来的函数和语法兼容性
- 生产环境优先使用最小权限账户连接
