///|
// 索引类型
pub(all) enum IndexType {
  Primary
  Unique
  Index
  FullText
  Spatial
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)

///|
// 索引定义
pub(all) struct Index {
  name : String
  index_type : IndexType
  columns : FixedArray[String]
  comment : String
} derive(Show, ToJson, FromJson, Eq, Compare, Hash)
