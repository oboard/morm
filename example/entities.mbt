///|
#morm.entity(name="class")
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

///|
#morm.entity(name="student")
pub(all) struct Student {
  #morm.primary_key
  #morm.auto_increment
  id : Int
  #morm.varchar(length="255")
  name : String
  age : Int
  #morm.datetime
  birth_date : String
} derive(ToJson, FromJson)

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
