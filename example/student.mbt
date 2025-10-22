///|
#morm.entity
pub(all) struct Student {
  #morm.primary_key
  #morm.auto_increment
  id : Int
  #morm.varchar(length="255")
  name : String
  age : Int
  #morm.datetime
  birth_date : String
} derive(ToJson)
