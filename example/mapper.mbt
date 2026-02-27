///|
#morm.mapper(table="student")
pub trait StudentMapper {
  find_student_by_id(Self, id : Int) -> Student?
  find_student_by_name(Self, name : String) -> Student?
  find_students_by_age(Self, age : Int) -> FixedArray[Student]
  find_students_by_age_and_name(Self, age : Int, name : String) -> FixedArray[
    Student,
  ]
  count_students_by_age(Self, age : Int) -> Int?
  find_all(Self) -> FixedArray[Student]
  all(Self) -> FixedArray[Student]
}
