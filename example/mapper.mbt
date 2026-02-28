///|
#morm.mapper(table="class")
pub trait ClassMapper {
  async save(Self, entity : Class) -> Class
}

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

///|
#morm.mapper(table="enrollment")
pub trait EnrollmentMapper {
  async find_enrollments_by_student_id(Self, student_id : Int) -> FixedArray[
    Enrollment,
  ]
  #morm.query("SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?")
  async find_by_class_raw(Self, class_id : Int) -> FixedArray[Enrollment]
  #morm.fetch_graph(join="LEFT JOIN student ON student.id = enrollment.student_id")
  async find_with_student_by_id(Self, id : Int) -> Enrollment?
  #morm.load_graph(join="LEFT JOIN class ON class.id = enrollment.class_id")
  async find_with_class_by_id(Self, id : Int) -> Enrollment?
}
