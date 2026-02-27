///|
pub fn[E : @engine.Engine] auto_migrate(
  engine : E,
  tables : Array[Table],
) -> Unit {
  // 仅传递 schema，SQL 生成与执行全部由引擎实现。
  for entity in tables {
    ignore(engine.migrate_table(entity.to_json()))
  }
}
