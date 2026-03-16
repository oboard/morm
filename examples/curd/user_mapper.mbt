///|
// Generate code:
// moon run mormgen -- examples/curd/user.mbt -o examples/curd/user.g.mbt
// moon run mormgen -- examples/curd/user_mapper.mbt -o examples/curd/user_mapper.g.mbt

///|
#morm.mapper(table="user")
pub trait UserMapper {
  // C: create
  async save(Self, entity : User) -> Bool
  // R: read
  async find_user_by_id(Self, id : Int) -> User?
  // U: update (partial update by primary key in generated code)
  async update(Self, entity : User) -> Bool
  // U: method-name based partial update
  async update_active_by_id(Self, active : Int, id : Int) -> Bool
  // D: delete
  async delete(Self, entity : User) -> Bool
  // D: method-name based delete
  async delete_by_id(Self, id : Int) -> Bool
}
