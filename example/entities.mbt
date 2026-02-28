///|
using @time {type ZonedDateTime, type PlainDateTime}

///|
#morm.entity
pub(all) struct Class {
  #morm.primary_key
  #morm.auto_increment
  id : Int64
  #morm.varchar(length="255")
  name : String

  // 外键：引用 Teacher(id)
  #morm.foreign_key(references="teacher.id", on_delete="CASCADE")
  teacher_id : Int
  created_at : PlainDateTime
  updated_at : PlainDateTime
} derive(ToJson, FromJson)

///|
#morm.entity
pub(all) struct Student {
  #morm.primary_key
  #morm.auto_increment
  id : Int64
  #morm.varchar(length="255")
  name : String
  age : Int
  birth_date : ZonedDateTime
} derive(ToJson, FromJson)

///|
#morm.entity
pub(all) struct Teacher {
  #morm.primary_key
  #morm.auto_increment
  id : Int64
  #morm.varchar(length="255")
  name : String
  #morm.varchar(length="255")
  major : String
  age : Int
  birth_date : ZonedDateTime?
} derive(ToJson, FromJson)

///|
#morm.entity
pub(all) struct Enrollment {
  #morm.primary_key
  #morm.auto_increment
  id : Int64
  #morm.many_to_one(references="student.id", fk="student_id", on_delete="CASCADE")
  student : Student
  #morm.many_to_one(table="class", column="id", fk="class_id")
  klass : Class
  #morm.varchar(length="255")
  note : String
} derive(ToJson, FromJson)

///|
#morm.entity
pub(all) struct StudentAggregate {
  #morm.primary_key
  id : Int64
  #morm.one_to_many(mapped_by="student")
  enrollments : FixedArray[Int]
} derive(ToJson, FromJson)
