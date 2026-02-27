///|
pub struct StudentMapper_ {
  engine : &@engine.Engine
}

///|
pub fn make_StudentMapper(engine : &@engine.Engine) -> StudentMapper_ {
  StudentMapper_::{ engine, }
}

///|
pub impl StudentMapper for StudentMapper_ with find_student_by_id(
  self,
  id : Int,
) -> Student? {
  let q = @morm.select_from("student").where_eq("id", id)
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl StudentMapper for StudentMapper_ with find_student_by_name(
  self,
  name : String,
) -> Student? {
  let q = @morm.select_from("student").where_eq("name", name)
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl StudentMapper for StudentMapper_ with find_students_by_age(
  self,
  age : Int,
) -> FixedArray[Student] {
  let q = @morm.select_from("student").where_eq("age", age)
  @engine.exec_query(self.engine, q).rows.map(row => {
    @json.from_json(row) catch {
      _ => panic()
    }
  })
}

///|
pub impl StudentMapper for StudentMapper_ with find_students_by_age_and_name(
  self,
  age : Int,
  name : String,
) -> FixedArray[Student] {
  let q = @morm.select_from("student")
    .where_eq("age", age)
    .where_eq("name", name)
  @engine.exec_query(self.engine, q).rows.map(row => {
    @json.from_json(row) catch {
      _ => panic()
    }
  })
}

///|
pub impl StudentMapper for StudentMapper_ with count_students_by_age(
  self,
  age : Int,
) -> Int? {
  let q = @morm.select_raw("student", "count(*)").where_eq("age", age)
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl StudentMapper for StudentMapper_ with find_all(self) -> FixedArray[
  Student,
] {
  let q = @morm.select_from("student")
  @engine.exec_query(self.engine, q).rows.map(row => {
    @json.from_json(row) catch {
      _ => panic()
    }
  })
}

///|
pub impl StudentMapper for StudentMapper_ with all(self) -> FixedArray[Student] {
  let q = @morm.select_from("student")
  @engine.exec_query(self.engine, q).rows.map(row => {
    @json.from_json(row) catch {
      _ => panic()
    }
  })
}
