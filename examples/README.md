# Morm Examples

Each example is an independent MoonBit package with `is-main: true`.
You can run them directly and inspect printed output.

## Run

```bash
moon run examples/basic
moon run examples/enum
moon run examples/exec_raw
moon run examples/preload
moon run examples/mapper
moon run examples/curd
```

## Packages

- `basic`: create tables in SQLite `:memory:`, insert rows, and query results.
  This example focuses on Query Builder (`insert_into/select_from/update/delete_from`).
- `enum`: use a MoonBit enum in an entity, inspect the generated enum column metadata,
  and round-trip enum values through `@engine.to_param` / `@engine.from_param`.
- `exec_raw`: use `exec_raw` with bound params and print query output.
- `preload`: preload `belongs_to`, `has_many`, and `many_to_many` maps.
- `mapper`: mormgen-based mapper flow (`schema.mbt` -> `generated.mbt` -> runtime call).
- `curd`: complete CRUD with generated `save/find/update/delete` mapper methods.

To regenerate mapper code:

```bash
moon run mormgen -- examples/enum/schema.mbt -o examples/enum/generated.mbt
moon run mormgen -- examples/mapper/schema.mbt -o examples/mapper/generated.mbt
moon run mormgen -- examples/curd/user.mbt -o examples/curd/user.g.mbt
moon run mormgen -- examples/curd/user_mapper.mbt -o examples/curd/user_mapper.g.mbt
```
