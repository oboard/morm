# Morm Benchmarks

This package contains MoonBit benchmarks for the same query families shown on
Prisma's benchmark dashboard:

- `find_all`: return all records.
- `filter_paginate_sort`: return a filtered, sorted and paginated page.
- `nested_find_all`: return records with a relation.
- `find_first` and `nested_find_first`.
- `find_unique` and `nested_find_unique`.
- `create` and `nested_create`.
- `update` and `nested_update`.
- `upsert`.
- `delete`.

There are two groups:

- `morm/render/*` measures morm query-builder and SQL rendering overhead.
- `morm/sqlite/*` measures end-to-end in-memory SQLite latency through morm's
  query builder and generated-mapper style APIs.

Run:

```bash
moon bench -p oboard/morm/examples/benchmarks --target native
```

For a Prisma-dashboard-style JSON report with fixed 500-iteration sampling and
`mean_us`, `median_us`, `iqr_us`, `stddev_us`, and `p99_us`, run:

```bash
moon run examples/benchmarks --target native --release
```

The MoonBit benchmark summary reports mean, standard deviation, min/max range,
and run counts. For Prisma-style comparison, use the named benchmarks as row
keys and compare the MoonBit median/IQR/std-dev fields from
`@bench.single_bench` JSON if you need raw machine-readable summaries. Prisma's
public table reports median values over 500 iterations and shows IQR and
standard deviation for spread.
