///|
pub struct UserMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn UserMapperImpl::new(engine : &@engine.Engine) -> UserMapperImpl {
  UserMapperImpl::{ engine, }
}

///|
pub impl UserMapper for UserMapperImpl with save(self, entity : User) -> Bool {
  let q = @morm.upsert_into("user").from(entity)
  self.engine.exec(q).ok
}

///|
pub impl UserMapper for UserMapperImpl with find_user_by_id(self, id : Int) -> User? {
  let q = @morm.select_from("user").where_eq("id", id)
  if self.engine.exec(q).rows is [result, ..] {
    return Some(User::_from(result))
  }
  None
}

///|
pub impl UserMapper for UserMapperImpl with update(self, entity : User) -> Bool {
  let q = @morm.update("user")
    .set("email", entity.email)
    .set("active", entity.active)
    .where_eq("id", entity.id)
  self.engine.exec(q).ok
}

///|
pub impl UserMapper for UserMapperImpl with update_active_by_id(
  self,
  active : Int,
  id : Int,
) -> Bool {
  let q = @morm.update("user").set("active", active).where_eq("id", id)
  self.engine.exec(q).ok
}

///|
pub impl UserMapper for UserMapperImpl with delete(self, entity : User) -> Bool {
  let q = @morm.delete_from("user").from(entity)
  self.engine.exec(q).ok
}

///|
pub impl UserMapper for UserMapperImpl with delete_by_id(self, id : Int) -> Bool {
  let q = @morm.delete_from("user").where_eq("id", id)
  self.engine.exec(q).ok
}
