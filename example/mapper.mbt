///|
#morm.mapper(table="student")
pub trait StudentMapper {
  async find_student_by_id(Self, id : Int) -> Student?
  async find_student_by_name(Self, name : String) -> Student?
  async find_students_by_age(Self, age : Int) -> FixedArray[Student]
  async find_students_by_age_and_name(Self, age : Int, name : String) -> FixedArray[
    Student,
  ]
  async count_students_by_age(Self, age : Int) -> Int?
  async find_all(Self) -> FixedArray[Student]
  async all(Self) -> FixedArray[Student]
}
