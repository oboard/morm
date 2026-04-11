///|
// mormgen source file: run from repo root:
// moon run mormgen -- examples/enum/schema.mbt -o examples/enum/generated.mbt

///|
pub(all) enum PostStatus {
  Draft
  Published
  Archived
} derive(ToJson, FromJson)

///|
pub impl Show for PostStatus with output(self : PostStatus, logger : &Logger) {
  let text = match self {
    Draft => "Draft"
    Published => "Published"
    Archived => "Archived"
  }
  logger.write_string(text)
}

///|
#morm.entity
pub(all) struct Post {
  #morm.id
  #morm.default(autoincrement())
  id : Int
  title : String
  status : PostStatus
} derive(ToJson, FromJson)
