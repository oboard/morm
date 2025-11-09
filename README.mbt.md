# oboard/morm

## Attributes 使用指南

下表列出当前支持的 `#morm` 属性、用法示例与效果说明。

| 属性 | 示例 | 说明 |
|---|---|---|
| `#morm.entity` | 置于 `struct` 顶部 | 声明该结构体为 ORM 实体，生成 `impl @morm.Entity` |
| `#morm.primary_key` | 放在某字段上一行 | 将该列标记为主键，并设置 `nullable=false` |
| `#morm.auto_increment` | 放在主键字段上一行 | 将该列设置为自增，同时 `primary_key=true`、`nullable=false` |
| `#morm.not_null` | 放在字段上一行 | 设置该列非空；若为主键，此标记可省略 |
| `#morm.varchar` | `#morm.varchar(length="255")` | 将该列类型设为 `VarChar(255)`；若未提供参数，默认 255 |
| `#morm.char` | `#morm.char(length="1")` | 将该列类型设为 `Char(1)`；若未提供参数，默认 1 |
| `#morm.text` | 纯标签 | 将该列类型设为 `Text` |
| `#morm.mediumtext` | 纯标签 | 将该列类型设为 `MediumText` |
| `#morm.longtext` | 纯标签 | 将该列类型设为 `LongText` |
| `#morm.binary` | `#morm.binary(length="1")` | 将该列类型设为 `Binary(1)`；若未提供参数，默认 1 |
| `#morm.varbinary` | `#morm.varbinary(length="255")` | 将该列类型设为 `VarBinary(255)`；若未提供参数，默认 255 |
| `#morm.blob` | 纯标签 | 将该列类型设为 `Blob` |
| `#morm.tinyint` | 纯标签 | 将该列类型设为 `TinyInt` |
| `#morm.smallint` | 纯标签 | 将该列类型设为 `SmallInt` |
| `#morm.int` | 纯标签 | 将该列类型设为 `Int` |
| `#morm.bigint` | 纯标签 | 将该列类型设为 `BigInt` |
| `#morm.float` | 纯标签 | 将该列类型设为 `Float` |
| `#morm.double` | 纯标签 | 将该列类型设为 `Double` |
| `#morm.decimal` | `#morm.decimal(precision="10", scale="2")` | 将该列类型设为 `Decimal(10,2)`；若未提供参数，默认 `10,2` |
| `#morm.boolean` | 纯标签 | 将该列类型设为 `Boolean` |
| `#morm.json` | 纯标签 | 将该列类型设为 `Json` |
| `#morm.jsonb` | 纯标签 | 将该列类型设为 `JsonB` |
| `#morm.uuid` | 纯标签 | 将该列类型设为 `VarChar(36)` |
| `#morm.datetime` | 纯标签 | 将该列类型设为 `DateTime` |
| `#morm.date` | 纯标签 | 将该列类型设为 `Date` |
| `#morm.time` | 纯标签 | 将该列类型设为 `Time` |
| `#morm.timestamp` | 纯标签 | 将该列类型设为 `Timestamp` |
| `#morm.foreign_key` | 放在外键字段上一行 | 将该字段解析为外键，约束名：`fk_<表名>_<列名>`，引用列默认 `id`；引用表按列名约定或类型名推断 |
| `#morm.on_delete_cascade` | 与 `#morm.foreign_key` 同用 | 外键 `on_delete` 设为 `CASCADE` |
| `#morm.on_update_cascade` | 与 `#morm.foreign_key` 同用 | 外键 `on_update` 设为 `CASCADE` |

说明：目前生成器未读取编译器暴露的参数字典，长度/精度等参数采用保守默认与示例形式；未来将增强为真正读取参数值并完全可配置。

## 示例用法

```moonbit
///|
#morm.entity
pub(all) struct Class {
  #morm.primary_key
  #morm.auto_increment
  id : Int
  #morm.varchar(length="255")
  name : String
  #morm.foreign_key
  #morm.on_delete_cascade
  teacher_id : Int
} derive(ToJson)
```

生成器运行：

```
moon run generator -- example
```

会在 `example/` 生成 `class.g.mbt`，并在 `Table.foreign_keys` 中包含 `teacher_id` 外键约束。