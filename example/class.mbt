///|
#morm.entity
pub(all) struct Class {
  #morm.primary_key
  #morm.auto_increment
  id : Int
  #morm.varchar(length="255")
  name : String

  // 外键：引用 Teacher(id)
  #morm.foreign_key(references="teacher.id", on_delete="CASCADE")
  teacher_id : Int
} derive(ToJson, FromJson)
