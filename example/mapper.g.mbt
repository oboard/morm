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
) -> FixedArray[Student] {
  self.engine.exec("SELECT * FROM students WHERE age = ?", [age.to_json()]).rows.map(row => @json.from_json(
      row,
    ) catch {
      _ => panic()
    },
  )
}

///|
pub impl StudentMapper for StudentMapper_ with find_students_by_age_and_name(
  self,
  age : Int,
  name : String,
) -> FixedArray[Student] {
  self.engine.exec("SELECT * FROM students WHERE age = ? AND name = ?", [
    age.to_json(),
    name.to_json(),
  ]).rows.map(row => @json.from_json(row) catch { _ => panic() })
}

///|
pub impl StudentMapper for StudentMapper_ with count_students_by_age(
  self,
  age : Int,
) -> Int? {
  if self.engine.exec("SELECT count(*) FROM students WHERE age = ?", [
      age.to_json(),
    ]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}
