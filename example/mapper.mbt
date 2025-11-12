///|
#morm.mapper(Student)
pub trait StudentMapper {
  #morm.query("SELECT * FROM students WHERE id = ?")
  find_student_by_id(Self, id : Int) -> Student?
  #morm.query("SELECT * FROM students WHERE name = ?")
  find_student_by_name(Self, name : String) -> Student?
  #morm.query("SELECT * FROM students WHERE age = ?")
  find_students_by_age(Self, age : Int) -> FixedArray[Student]
  #morm.query("SELECT * FROM students WHERE age = ? AND name = ?")
  find_students_by_age_and_name(Self, age : Int, name : String) -> FixedArray[
    Student,
  ]
  #morm.query("SELECT count(*) FROM students WHERE age = ?")
  count_students_by_age(Self, age : Int) -> Int?
}
