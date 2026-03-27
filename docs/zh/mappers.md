---
outline: deep
---

# 映射器

映射器是面向应用层的查询入口。你声明一个带 `#morm.mapper` 注解的 trait，`mormgen` 再把它展开成普通 MoonBit 代码。

它的目标是减少重复查询样板，但不隐藏底层实际执行的 SQL 或 query builder。

## 基本写法

```moonbit
///|
#morm.mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
  async count_students_by_age(Self, age : Int) -> Int?
}
```

`mormgen` 会生成：

- `StudentMapperImpl`
- `StudentMapperImpl::new(engine)`
- 每个 trait 方法对应的实现

## 绑定方式

可以用下面两种方式绑定 mapper：

- `table="student"`
- `entity="Student"`

通常 `table=` 更直接；如果同包里能扫描到实体定义，生成器也可以反推出实体信息。

## 方法推导

没有写 `#morm.query` 时，生成器会根据方法名推导常见查询。

常见形式包括：

- `find_student_by_id`
- `find_student_by_name`
- `find_students_by_age_and_name`
- `count_students_by_age`
- `find_all`
- `all`

这个推导是保守的，只覆盖常见读查询。超出这个范围时，建议直接写显式 SQL 或 builder。

## 显式 SQL

如果你需要精确控制 SQL，可以使用 `#morm.query`。

```moonbit
///|
#morm.mapper(table="enrollment")
pub trait EnrollmentMapper {
  #morm.query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
}
```

这样做的特点是：

- SQL 由你完全控制
- 参数仍然是强类型的
- 结果解码仍由生成代码统一处理

## JOIN 扩展

`mormgen` 还识别：

- `#morm.fetch_graph(join="...")`
- `#morm.load_graph(join="...")`

它们的行为是给推导出来的 builder 追加 `.join(...)`。

这只是 SQL 拼装辅助，不是完整的 lazy-loading 图加载系统。

## 返回类型

当前 mapper 读方法支持这些返回形状：

- `T`
- `T?`
- `FixedArray[T]`
- `Array[T]`
- `@set.Set[T]`
- `@list.List[T]`
- `Map[K, T]`

其中：

- `T` 和 `T?` 读取第一行结果并解码
- `FixedArray[T]`、`Array[T]` 会逐行解码并保留顺序
- `@set.Set[T]` 会逐行解码后插入集合
- `@list.List[T]` 会逐行解码后构造成列表
- `Map[K, T]` 会逐行解码值，再用 key 建立映射

`Map[K, T]` 的 key 规则是：

- 如果 `T` 是可识别实体，优先使用实体主键字段
- 否则退回读取结果行里的 `"id"` 字段并解码为 `K`

因此 `Map[K, T]` 最适合返回实体结果，而且查询结果里应该包含主键列。

## 解码模型

当前生成的 mapper 不再依赖 `FromJson`。

查询结果会先以 `Map[String, @engine.Param]` 的行模型进入生成代码，再按字段或返回类型调用 `@engine.from_param(...)` 解码。

这意味着：

- 实体字段类型需要能从 `Param` 解码
- 非实体标量返回值也需要满足 `FromParam`
- 生成的实体 `_from(...)` 也是基于 `Map[String, Param]`

## 特殊 `save` 方法

`save` 是生成器识别的特殊方法。

```moonbit
///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}
```

生成行为是：

- 如果命中了自动时间字段，先重写实体
- 构建 `@morm.upsert_into(...).from(entity)`
- 通过引擎执行
- 把第一行结果解码成返回类型

## 特殊 `delete` 方法

`delete` 也是特殊方法：

```moonbit
///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async delete(Self, entity : Class) -> Bool
}
```

它会基于实体身份字段生成删除路径。

## 自动时间字段注入

对生成的 `save` 和部分 `update` 路径，mapper 可以在构建语句前自动补时间字段。

触发规则：

- 字段名是 `created_at`
- 字段名是 `updated_at`
- `#morm.auto_create_time`
- `#morm.auto_update_time`

取值规则：

- `PlainDateTime -> @morm.current_plain_date_time_utc()`
- `ZonedDateTime -> @morm.current_timestamp_utc()`

## 什么时候适合用 mapper

适合：

- 标准 CRUD 入口
- 简单列表和按条件查找
- 面向应用层的固定查询接口

不太适合：

- 强依赖特定数据库语法的 SQL
- 方法名推导已经变得别扭的复杂查询
- 需要定制冲突处理、返回规则或更新策略的写路径

这类场景通常更适合直接写 query builder 或 raw SQL。

## 调试方式

当生成的方法行为和预期不一致时，建议按这个顺序排查：

1. 看源 trait
2. 看生成出来的 `.g.mbt`
3. 看实际使用的 engine 实现

这是 `morm` 设计里预期的调试路径。

英文版本： [Mappers](/mappers)。
