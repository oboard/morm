///|
// mormgen source file: run from repo root:
// moon run mormgen -- examples/enum/schema.mbt -o examples/enum/generated.mbt

///|
pub(all) enum PostStatus {
  Draft
  Published
  Archived
} derive(ToJson, FromJson, Show)

///|
#morm.entity
pub(all) struct Post {
  #morm.id
  #morm.default(autoincrement())
  id : Int
  title : String
  status : PostStatus
} derive(ToJson, FromJson)
