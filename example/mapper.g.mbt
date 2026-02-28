///|
pub struct ClassMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn ClassMapperImpl::new(engine : &@engine.Engine) -> ClassMapperImpl {
  ClassMapperImpl::{ engine, }
}

///|
pub impl ClassMapper for ClassMapperImpl with save(self, entity : Class) -> Class {
  let entity = {
    ..entity,
    created_at: @morm.current_plain_date_time_utc(),
    updated_at: @morm.current_plain_date_time_utc(),
  }
  let q = @morm.upsert_into("class").from(entity)
  let res = @engine.exec_query(self.engine, q)
  if res.rows is [result, ..] {
    return (try! @json.from_json(result) : Class)
  }
  panic()
}

///|
pub struct StudentMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn StudentMapperImpl::new(engine : &@engine.Engine) -> StudentMapperImpl {
  StudentMapperImpl::{ engine, }
}

///|
pub impl StudentMapper for StudentMapperImpl with find_student_by_id(
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
pub impl StudentMapper for StudentMapperImpl with find_student_by_name(
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
pub impl StudentMapper for StudentMapperImpl with find_students_by_age(
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
pub impl StudentMapper for StudentMapperImpl with find_students_by_age_and_name(
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
pub impl StudentMapper for StudentMapperImpl with count_students_by_age(
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
pub impl StudentMapper for StudentMapperImpl with find_all(self) -> FixedArray[
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
pub impl StudentMapper for StudentMapperImpl with all(self) -> FixedArray[
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
pub struct EnrollmentMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn EnrollmentMapperImpl::new(
  engine : &@engine.Engine,
) -> EnrollmentMapperImpl {
  EnrollmentMapperImpl::{ engine, }
}

///|
pub impl EnrollmentMapper for EnrollmentMapperImpl with find_enrollments_by_student_id(
  self,
  student_id : Int,
) -> FixedArray[Enrollment] {
  let q = @morm.select_from("enrollment").where_eq("student_id", student_id)
  @engine.exec_query(self.engine, q).rows.map(row => {
    @json.from_json(row) catch {
      _ => panic()
    }
  })
}

///|
pub impl EnrollmentMapper for EnrollmentMapperImpl with find_by_class_raw(
  self,
  class_id : Int,
) -> FixedArray[Enrollment] {
  self.engine.exec_raw(
    "SELECT id, student_id, class_id, note FROM enrollment WHERE class_id = ?",
    [@engine.to_param(class_id)],
  ).rows.map(row => @json.from_json(row) catch { _ => panic() })
}

///|
pub impl EnrollmentMapper for EnrollmentMapperImpl with find_with_student_by_id(
  self,
  id : Int,
) -> Enrollment? {
  let q = @morm.select_from("enrollment")
    .where_eq("id", id)
    .join("LEFT JOIN student ON student.id = enrollment.student_id")
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

///|
pub impl EnrollmentMapper for EnrollmentMapperImpl with find_with_class_by_id(
  self,
  id : Int,
) -> Enrollment? {
  let q = @morm.select_from("enrollment")
    .where_eq("id", id)
    .join("LEFT JOIN class ON class.id = enrollment.class_id")
  if @engine.exec_query(self.engine, q).rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}
