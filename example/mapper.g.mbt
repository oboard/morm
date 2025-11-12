///|
pub struct StudentMapper_ {
  engine : &@engine.Engine
}

///|
pub fn Student::mapper(engine : &@engine.Engine) -> StudentMapper_ {
  StudentMapper_::{ engine, }
}

///|
pub impl StudentMapper for StudentMapper_ with find_student_by_id(
  self,
  id : Int,
) -> Student? {
  if self.engine.exec("SELECT * FROM students WHERE id = ?", [id.to_json()]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl StudentMapper for StudentMapper_ with find_student_by_name(
  self,
  name : String,
) -> Student? {
  if self.engine.exec("SELECT * FROM students WHERE name = ?", [name.to_json()]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl StudentMapper for StudentMapper_ with find_students_by_age(
  self,
  age : Int,
) -> Array[Student] {
  let results = []
  for
    row in self.engine.exec("SELECT * FROM students WHERE age = ?", [
      age.to_json(),
    ]).rows {
    try! results.push(@json.from_json(row))
  }
  results
}
