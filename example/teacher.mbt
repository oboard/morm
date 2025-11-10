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
  birth_date : String
} derive(ToJson, FromJson)
