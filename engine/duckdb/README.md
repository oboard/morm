# DuckDB native binding

The DuckDB engine embeds adapted native bindings from [f4ah6o/duckdb.mbt](https://github.com/f4ah6o/duckdb.mbt), version 0.6.3 at commit `55d9240`. The upstream Apache-2.0 license is retained in [LICENSE](./LICENSE).

The MoonBit layer only exposes connection, query, and prepared-statement operations needed by the adapter; the upstream native C stub is included alongside it. The C binding decodes `TIMESTAMPTZ` from its native result column instead of the upstream empty text conversion. This package links to an independently installed `libduckdb` and does not bundle DuckDB itself.
