# oboard/morm

MoonBit 生态下的轻量级 ORM。目标很直接：

- 用尽量少的属性和 API 覆盖大部分常见场景
- 保持实现透明，允许随时绕过 ORM 手写 SQL
- 不使用运行时反射，不隐式修改用户语义


## Quick Start

1. 在你的应用 `moon.mod.json` 中添加依赖：

```json
  "bin-deps": {
    "oboard/morm": "latest"
  },
```

2. 在你的 `moon.pkg` 添加

```moonbit nocheck
options(
  "pre-build": [
    {
      "command": "$mod_dir/.mooncakes/oboard/morm/morm-gen $input -o $output && moonfmt -w $output",
      "input": "entities.mbt",
      "output": "entities.g.mbt",
    },
    {
      "command": "$mod_dir/.mooncakes/oboard/morm/morm-gen $input -o $output && moonfmt -w $output",
      "input": "mapper.mbt",
      "output": "mapper.g.mbt",
    },
  ],
)
```

3. 在你的 `entities.mbt` 中定义实体：


通过在 `struct` 上加少量 `#morm.*` 属性，可以自动生成：

- `impl @morm.Entity` 与 `table()` 元数据
- 各数据库方言下的建表 / 迁移 SQL
- 基于 `#morm.query` 的类型安全 Mapper 方法（含 `save` / `delete`）
- 统一返回 `(String, FixedArray[@engine.Param])` 的参数化 SQL 构造器

核心设计取舍：

- **类型驱动**：字段的可空性由 `T` / `T?` 决定，而不是依赖大量注解
- **方言内建**：支持 MySQL / PostgreSQL / Sqlite / SQLServer / Oracle 的建表和占位符差异
- **SQL 优先**：`Query/Insert/Update/Delete/Upsert` 只负责构造参数化 SQL，不绑定执行层
- **生成代码**：所有内容都生成成普通 MoonBit 代码（见 `example/*.g.mbt`），可以直接查看和修改

该库主要解决三个问题：

- 统一建表与迁移 SQL 的生成
- 统一各数据库方言的语法差异
- 统一 SQL 参数绑定方式

业务层的查询依然以显式 SQL 为主，由用户自己控制每一条语句。

你还需要自己实现一个满足 `@oboard/morm/engine.Engine` 的驱动，用来真正连到 MySQL / PostgreSQL / Sqlite 等数据库。`example/generator_test.mbt` 里有一个简化版的 `MySQLEngine` 示例。

## 实体建模与可空性

一个典型实体定义如下（摘自 `example/entities.mbt`）：

```moonbit nocheck
///|
#morm.entity(name="teacher")
pub(all) struct Teacher {
  #morm.primary_key
  #morm.auto_increment
  #morm.bigint
  id : Int
  #morm.varchar(length="255")
  name : String
  #morm.varchar(length="255")
  major : String
  age : Int
  #morm.datetime
  birth_date : String?
} derive(ToJson, FromJson)
```

当前版本关于可空性的规则非常简单：

- 字段类型为 `T`（非 `Option`）时：列默认 **NOT NULL**
- 字段类型为 `T?`（Option[T]）时：列默认 **NULLABLE**
- 主键永远视为非空，即便你写成 `id : Int?`，也会被当成 NOT NULL 主键

属性 `#morm.not_null` 目前不再参与可空性判断，仅作为保留标签；真实行为完全由类型决定。

## Attributes 使用指南

下表列出当前支持的 `#morm` 属性、用法示例与效果说明。

| 属性 | 示例 | 说明 |
|---|---|---|
| `#morm.entity` | 置于 `struct` 顶部 | 声明该结构体为 ORM 实体，生成 `impl @morm.Entity` |
| `#morm.primary_key` | 放在某字段上一行 | 将该列标记为主键；主键总是非空 |
| `#morm.auto_increment` | 放在主键字段上一行 | 将该列设置为自增，同时 `primary_key=true`、`nullable=false` |
| `#morm.primary_key(strategy="...")` | `#morm.primary_key(strategy="uuid")` | 声明主键生成策略，当前会写入列 engine option：`pk.strategy=<value>`；支持 `manual` / `auto_increment` / `uuid` |
| `#morm.not_null` | 放在字段上一行 | 当前版本仅作标记，实际可空性仍由类型 `T` / `T?` 决定 |
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
| `#morm.date` | `#morm.date(format="yyyy/MM/dd")` | 将该列类型设为 `Date`；可选 `format` 影响该字段参数的 `to_json`/字符串输出 |
| `#morm.time` | `#morm.time(format="HH-mm-ss")` | 将该列类型设为 `Time`；可选 `format` 影响该字段参数的 `to_json`/字符串输出 |
| `#morm.timestamp` | `#morm.timestamp(format="yyyy-MM-dd HH:mm:ss Z")` | 将该列类型设为 `Timestamp`；可选 `format` 影响该字段参数的 `to_json`/字符串输出 |
| `#morm.foreign_key` | 放在外键字段上一行 | 将该字段解析为外键，约束名：`fk_<表名>_<列名>`，引用列默认 `id`；引用表按列名约定或类型名推断 |
| `#morm.on_delete_cascade` | 与 `#morm.foreign_key` 同用 | 外键 `on_delete` 设为 `CASCADE` |
| `#morm.on_update_cascade` | 与 `#morm.foreign_key` 同用 | 外键 `on_update` 设为 `CASCADE` |
| `#morm.transient` | 纯标签 | 字段仅保留在实体中，不会生成数据库列，也不会参与 `insert/update/upsert ... from(entity)` |

说明：目前生成器尚未读取编译器暴露的参数字典，长度/精度等参数采用保守默认与示例形式；未来会增强为真正读取参数值并完全可配置。

## 代码生成：mormgen CLI

仓库包含一个生成器二进制 `mormgen`（见 `main/main.mbt`），负责把带 `#morm.*` 的源码翻译成实体和 mapper 实现。用法：

```text
mormgen -i <input_file> -o <output_file>
```

典型流程（对应 `example/`）：

```bash
# 生成实体的 table() 实现
mormgen example/entities.mbt -o example/entities.g.mbt

# 生成 mapper 实现
mormgen example/mapper.mbt -o example/mapper.g.mbt
```

`entities.g.mbt` 会包含每个实体的 `impl @morm.Entity` 和 `table()`，`mapper.g.mbt` 会包含 mapper struct、`Struct::new` 工厂函数以及基于 `#morm.query` 的方法实现。

## Mapper 与查询

在实体定义之外，你可以用 `#morm.mapper` 声明一个 mapper 接口（见 `example/mapper.mbt`）：

```moonbit nocheck
#morm.mapper(entity="Student")
pub trait StudentMapper {
  #morm.query("SELECT * FROM students WHERE id = ?")
  pub fn find_student_by_id(Self, id : Int) -> Student?

  #morm.query("SELECT count(*) FROM students WHERE age = ?")
  pub fn count_students_by_age(Self, age : Int) -> Int?
}
```

生成器会为你生成：

- `pub struct StudentMapperImpl { engine : &@engine.Engine }`
- `pub fn StudentMapperImpl::new(engine : &@engine.Engine) -> StudentMapperImpl`
- 对应的 `impl StudentMapper for StudentMapperImpl`，内部用参数化 SQL 调用 `engine.exec` / `engine.query`
- 额外的通用方法：`save` 和 `delete`，直接基于实体的主键和唯一索引做 UPSERT / DELETE

使用方式示例（简化）：

```moonbit nocheck
///|
let engine = MySQLEngine::open("mysql://...")

///|
let mapper = StudentMapperImpl::new(engine)

///|
let stu = mapper.find_student_by_id(1)

///|
let n = mapper.count_students_by_age(18)

///|
let saved = mapper.save(stu)

///|
let deleted = mapper.delete(stu)
```

## SQL 构造器与渲染

`morm.mbt` 提供一组查询构造器：

- `select_from(table)`
- `insert_into(table)`
- `update(table)`
- `delete_from(table)`
- `upsert_into(table)`

通过 `to_statement()` + `@engine.render_default_sql(...)` 得到 SQL 和参数：

```moonbit nocheck
let q = @morm.select_from("students")
  .where_eq("id", 1)
  .where_eq("name", "Alice")
  .order_by(Desc("id"))
  .offset(5)
  .limit(5)
let (sql, params) = @engine.render_default_sql(q.to_statement())
```

`sql` 会是：

```text
SELECT * FROM students WHERE id = ? AND name = ? ORDER BY id DESC LIMIT 5 OFFSET 5
```

`params` 则是对应顺序的 JSON 数组。

UPSERT 使用 `upsert_into(table)`，并且：

- 在 PostgreSQL / Sqlite 下附带 `RETURNING *`，直接返回插入/更新后的行
- 在不支持 `RETURNING` 的方言（如 MySQL）下，`save` 会用主键或唯一索引回读一行，保证你最终拿到一条完整记录

## 自动迁移（Auto-migrate）

`auto_migrate` 可以根据实体的 `table()` 定义生成并执行建表 / 修改表 SQL。示例见 `example/generator_test.mbt`：

```moonbit nocheck
let engine = MySQLEngine::open("mysql://root:123456@localhost:3306/test")
@morm.auto_migrate(engine, [Student::table()])
engine.close()
```

当前版本偏保守，只覆盖基础场景；复杂 schema 变更建议显式写迁移。

## 运行测试与示例

仓库内置了一些针对 SQL 生成和生成器的测试与示例：

```bash
# 运行全部测试
moon test
```
