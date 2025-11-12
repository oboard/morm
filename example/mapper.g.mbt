pub struct StudentMapper_ {
  engine : &@engine.Engine
}

pub fn Student::mapper(engine : &@engine.Engine) -> StudentMapper_ {
  StudentMapper_::{ engine, }
}

pub impl StudentMapper for StudentMapper_ with find_student_by_id(
  self, id : Int
) -> Student? {
  if self.engine.exec("SELECT * FROM students WHERE id = ?", [id.to_json()]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

pub impl StudentMapper for StudentMapper_ with find_student_by_name(
  self, name : String
) -> Student? {
  if self.engine.exec("SELECT * FROM students WHERE name = ?", [name.to_json()]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

pub impl StudentMapper for StudentMapper_ with find_students_by_age(
  self, age : Int
) -> FixedArray[Student] {
  self.engine.exec("SELECT * FROM students WHERE age = ?", [age.to_json()]).rows.map(row => @json.from_json(
      row,
    ) catch {
      _ => panic()
    },
  )
}

pub impl StudentMapper for StudentMapper_ with find_students_by_age_and_name(
  self, age : Int, name : String
) -> FixedArray[Student] {
  self.engine.exec("SELECT * FROM students WHERE age = ? AND name = ?", [age.to_json(), name.to_json()]).rows.map(row => @json.from_json(
      row,
    ) catch {
      _ => panic()
    },
  )
}

pub impl StudentMapper for StudentMapper_ with count_students_by_age(
  self, age : Int
) -> Int? {
  if self.engine.exec("SELECT count(*) FROM students WHERE age = ?", [age.to_json()]).rows
    is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  None
}

pub fn StudentMapper_::save(
  self : StudentMapper_,
  entity : Student,
) -> Student? {
  let (sql, params) = @morm.upsert_into(Student::table().name)
    .from(entity)
    .to(self.engine.dialect())
  let res = self.engine.exec(sql, params)
  if res.rows is [result, ..] {
    return Some(try! @json.from_json(result))
  }
  // Fallback: read back by conflict keys when UPSERT does not return rows
  let tbl = Student::table()
  let obj = entity.to_json().as_object().unwrap()
  // try primary key first
  match tbl.primary_key() {
    Some(pk) => match obj.get(pk) {
      Some(pkv) => {
        let (sel_sql, sel_params) = @morm.select_from(tbl.name).where_eq(pk, pkv).to(self.engine.dialect())
        if self.engine.exec(sel_sql, sel_params).rows is [row, ..] {
          return Some(try! @json.from_json(row))
        }
      }
      None => ()
    }
    None => ()
  }
  // try first unique index with all values present
  for idx in tbl.indexes {
    match idx.index_type {
      Unique => {
        let mut q = @morm.select_from(tbl.name)
        let mut ok = true
        for col in idx.columns {
          match obj.get(col) {
            Some(v) => q = q.where_eq(col, v)
            None => { ok = false; break }
          }
        }
        if ok {
          let (sel_sql, sel_params) = q.to(self.engine.dialect())
          if self.engine.exec(sel_sql, sel_params).rows is [row, ..] {
            return Some(try! @json.from_json(row))
          }
        }
        break
      }
      _ => ()
    }
  }
  None
}

pub fn StudentMapper_::delete(self : StudentMapper_, entity : Student) -> Bool {
  let primary_key = Student::table().primary_key()
  if primary_key is Some(_) {
    let (sql, params) = @morm.delete_from(Student::table().name)
      .from(entity)
      .to(self.engine.dialect())
    self.engine.exec(sql, params).ok
  } else {
    false
  }
}

