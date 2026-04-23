///|
pub trait BenchUserMapper {
  async save(Self, entity : BenchUser) -> Bool
  async find_user_by_id(Self, id : Int) -> BenchUser?
  async find_users_by_active(Self, active : Int) -> FixedArray[BenchUser]
  async find_users_page_by_active(
    Self,
    active : Int,
    pageable : @engine.Pageable,
  ) -> @engine.Page[BenchUser]
  async update_active_by_id(Self, active : Int, id : Int) -> Bool
  async delete_by_id(Self, id : Int) -> Bool
}

///|
pub struct BenchUserMapperImpl {
  engine : &@engine.Engine
}

///|
pub fn BenchUserMapperImpl::new(
  engine : &@engine.Engine,
) -> BenchUserMapperImpl {
  { engine, }
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with save(self, entity) {
  self.engine.exec(@morm.upsert_into("bench_user").from(entity)).ok
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with find_user_by_id(self, id) {
  let q = @morm.select_from("bench_user").where_eq("id", id)
  if self.engine.exec(q).rows is [row, ..] {
    return Some(BenchUser::_from(row))
  }
  None
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with find_users_by_active(
  self,
  active,
) {
  self.engine.exec(
    @morm.select_from("bench_user")
    .where_eq("active", active)
    .order_by(Asc("id")),
  ).rows.map(row => BenchUser::_from(row))
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with find_users_page_by_active(
  self,
  active,
  pageable,
) {
  @morm.paginate(
    self.engine,
    @morm.select_from("bench_user").where_eq("active", active),
    pageable,
  )
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with update_active_by_id(
  self,
  active,
  id,
) {
  self.engine.exec(
    @morm.update("bench_user").set("active", active).where_eq("id", id),
  ).ok
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with delete_by_id(self, id) {
  self.engine.exec(@morm.delete_from("bench_user").where_eq("id", id)).ok
}
