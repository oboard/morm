///|
#morm.mapper(Student)
pub trait StudentMapper {
  #morm.query("SELECT * FROM students WHERE id = ?")
  find_student_by_id(Self, id : Int) -> Student?
  #morm.query("SELECT * FROM students WHERE name = ?")
  find_student_by_name(Self, name : String) -> Student?
  #morm.query("SELECT * FROM students WHERE age = ?")
  find_students_by_age(Self, age : Int) -> Array[Student]
}
