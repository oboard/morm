///|
// mormgen source file: run from repo root:
// moon run mormgen examples/mapper/schema.mbt -o examples/mapper/generated.mbt

///|
#morm.entity
pub struct User {
  #morm.id
  #morm.default(autoincrement())
  id : Int
  #morm.unique
  email : String
  active : Int
} derive(ToJson, FromJson)

///|
#morm.mapper(table="user")
pub trait UserMapper {
  async fn find_user_by_id(Self, id : Int) -> User?
  async fn find_users_by_active(Self, active : Int) -> FixedArray[User]
  async fn find_users_page_by_active(
    Self,
    active : Int,
    pageable : @morm/engine.Pageable,
  ) -> @morm/engine.Page[User]
}
