---
outline: deep
---

# DuckDB 引擎

原生 DuckDB 引擎在 adapter 包内直接内置基于 [`f4ah6o/duckdb`](https://github.com/f4ah6o/duckdb.mbt) 的[原生绑定](../../engine/duckdb/README.md)，无需额外添加 `f4ah6o/duckdb` 依赖。编译前需要安装系统的 `libduckdb` 及头文件。

使用引擎的应用需要在自己的 `moon.pkg` 配置 `link.native.cc-link-flags`，包含 `libduckdb` 的路径及 `-lduckdb`（例如 macOS Homebrew 的 `-L/opt/homebrew/lib -lduckdb`）。

## 导入与使用

```moonbit
import {
  "oboard/morm" @morm,
  "oboard/morm/engine" @morm/engine,
  "oboard/morm/engine/duckdb" @duckdb,
}

let engine = match @duckdb.DuckDBEngine::open(":memory:") {
  Ok(engine) => engine
  Err(message) => abort(message)
}
let result = engine.exec_raw("SELECT ?::INTEGER AS answer", [@morm/engine.Int(42)])
engine.close()
```

`open` 接受 `:memory:` 或数据库文件路径，也可使用 `duckdb://` 前缀。只支持原生目标，参数占位符为 `?`。

## 迁移与限制

支持查询构建器、原生 SQL、分页和建表迁移。插入和 Upsert 返回数据行；自增列通过序列实现。迁移可重复执行，但不会修改已有列。全文索引和空间索引会返回失败结果。底层绑定将 JSON 列内容作为文本返回，需要对象时请手动解析；数据库错误可通过 `QueryResult.error` 获取。
本地绑定从原生结果列读取 `TIMESTAMPTZ`，转换为可由 `FromParam<ZonedDateTime>` 解析的 UTC 时间文本。无穷大等非有限时间仍不支持，可通过 `CAST(column AS VARCHAR)` 自行处理；普通 `TIMESTAMP` 正常解码。
