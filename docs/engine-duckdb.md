---
outline: deep
---

# DuckDB Engine

The native DuckDB engine embeds an [adapted copy](../engine/duckdb/README.md) of the [`f4ah6o/duckdb`](https://github.com/f4ah6o/duckdb.mbt) MoonBit binding in the adapter package. You do not need to add a separate `f4ah6o/duckdb` dependency. Install `libduckdb` and its headers before compiling native code; the binding links against the system library.

In a consuming application's `moon.pkg`, provide linker flags pointing to the installed library (adjust the path for your platform):

```moonbit
options(
  link: {
    "native": {
      "cc-link-flags": "-L/opt/homebrew/lib -Wl,-rpath,/opt/homebrew/lib -lduckdb",
    },
  },
)
```

## Package Import

```moonbit
import {
  "oboard/morm" @morm,
  "oboard/morm/engine" @morm/engine,
  "oboard/morm/engine/duckdb" @duckdb,
}
```

## Connect and Query

```moonbit
let engine = match @duckdb.DuckDBEngine::open(":memory:") {
  Ok(engine) => engine
  Err(message) => abort(message)
}
let result = engine.exec_raw(
  "SELECT ?::INTEGER AS answer",
  [@morm/engine.Int(42)],
)
engine.close()
```

Pass a file path to `open` for persistent storage. `duckdb://` can optionally prefix the path, for example `duckdb:///tmp/app.duckdb` or `duckdb://:memory:`. The driver supports native builds only; use `?` positional placeholders with `@morm/engine.Param` values.

## Schema and Queries

The engine implements `exec`, `exec_raw`, `page`, `page_raw`, and `migrate_table`. Generated `INSERT` and `UPSERT` statements return their inserted or updated rows. Upserts use `ON CONFLICT`; schema migration creates missing tables, sequences for auto-increment columns, and ordinary or unique indexes. Re-running migration does not alter existing columns. Unsupported full-text and spatial indexes return a failed `QueryResult`.

Parameters use prepared statements. DuckDB's binding exposes values as text with column types, so integers, booleans, decimals, and blobs are decoded to `Param` values. For JSON values, the binding exposes text rather than a distinct JSON type; parse returned JSON strings when object values are needed. SQL execution errors are available in `QueryResult.error`.

The embedded binding decodes `TIMESTAMPTZ` directly from the native result column and returns a UTC timestamp string, which `FromParam<ZonedDateTime>` can parse. Non-finite timestamps remain unsupported; cast these to `VARCHAR` and handle the resulting text explicitly. `TIMESTAMP` values without a time zone decode normally.
