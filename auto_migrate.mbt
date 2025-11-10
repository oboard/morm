///|
pub fn[E : @engine.Engine, T : Entity] auto_migrate(
  engine : E,
  entities : Array[T],
) -> Unit {
  // 保守策略：默认按 MySQL 方言生成；如需其它方言，可扩展接口或由 Engine 暴露。
  let dialect = Dialect::MySQL

  // 逐实体生成 CREATE 与 ALTER 语句并执行
  for entity in entities {
    let table = entity.table()

    // 1) 尝试创建表（不使用 IF NOT EXISTS，失败时由 Engine/Driver 处理；我们不抛异常）
    let create_sql = table.to_create_sql(dialect)
    ignore(engine.exec(create_sql, []))

    // 2) 使用 ALTER 构建器追加非 CREATE 覆盖的事项（如普通索引、表注释）
    let mut mut_alter = alter_table(table.name)
    if table.comment != "" {
      mut_alter = mut_alter.comment(table.comment)
    }
    for idx in table.indexes {
      match idx.index_type {
        // 主键与唯一已在 CREATE 中声明；普通索引在不同方言下常用独立语句
        Index => mut_alter = mut_alter.add_index(idx)
        _ => ()
      }
    }
    let alter_sql = mut_alter.to(dialect)
    if !alter_sql.is_empty() {
      ignore(engine.exec(alter_sql, []))
    }
  }
}
