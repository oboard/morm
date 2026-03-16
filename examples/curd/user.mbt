///|
#morm.entity
pub struct User {
  #morm.id
  id : Int
  #morm.unique
  email : String
  active : Int
} derive(ToJson, FromJson)
