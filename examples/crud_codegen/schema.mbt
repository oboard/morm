///|
// Generate code from this schema file:
// moon run mormgen -- examples/crud_codegen/schema.mbt -o examples/crud_codegen/generated.mbt

///|
#morm.entity
pub struct User {
  #morm.id
  id : Int
  #morm.unique
  email : String
  active : Int
} derive(ToJson, FromJson)

///|
#morm.mapper(table="user")
pub trait UserMapper {
  // C: create
  async save(Self, entity : User) -> Bool
  // R: read
  async find_user_by_id(Self, id : Int) -> User?
  // U: update
  async update(Self, entity : User) -> Bool
  // D: delete
  async delete(Self, entity : User) -> Bool
}
