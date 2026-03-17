---
outline: deep
---

# MySQL 引擎

MySQL 适用于常见 OLTP 业务，生态成熟，部署广泛。

## 包导入

```moonbit
using @oboard/morm/engine/mysql as @mysql
```

## DSN 示例

```moonbit
mysql://root:password@127.0.0.1:3306/app_db
```

## 参数与事务

- 使用 `?` 占位符
- 支持 `BEGIN/COMMIT/ROLLBACK`
- 事务中连接保持绑定，避免状态错乱

## 使用建议

- 字符集统一 utf8mb4
- 时间字段建议统一时区策略
