///|
pub trait BenchUserMapper {
  async fn save(Self, entity : BenchUser) -> Bool
  async fn find_user_by_id(Self, id : Int) -> BenchUser?
  async fn find_users_by_active(Self, active : Int) -> FixedArray[BenchUser]
  async fn find_users_page_by_active(
    Self,
    active : Int,
    pageable : @morm/engine.Pageable,
  ) -> @morm/engine.Page[BenchUser]
  async fn update_active_by_id(Self, active : Int, id : Int) -> Bool
  async fn delete_by_id(Self, id : Int) -> Bool
}

///|
pub struct BenchUserMapperImpl {
  engine : &@morm/engine.Engine
}

///|
pub fn BenchUserMapperImpl::BenchUserMapperImpl(
  engine : &@morm/engine.Engine,
) -> BenchUserMapperImpl {
  { engine, }
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with fn save(self, entity) {
  self.engine.exec(@morm.upsert_into("bench_user").from(entity)).ok
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with fn find_user_by_id(
  self,
  id,
) {
  let q = @morm.select_from("bench_user").where_eq("id", id)
  if self.engine.exec(q).rows is [row, ..] {
    return Some(BenchUser::_from(row))
  }
  None
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with fn find_users_by_active(
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
pub impl BenchUserMapper for BenchUserMapperImpl with fn find_users_page_by_active(
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
pub impl BenchUserMapper for BenchUserMapperImpl with fn update_active_by_id(
  self,
  active,
  id,
) {
  self.engine.exec(
    @morm.update("bench_user").set("active", active).where_eq("id", id),
  ).ok
}

///|
pub impl BenchUserMapper for BenchUserMapperImpl with fn delete_by_id(self, id) {
  self.engine.exec(@morm.delete_from("bench_user").where_eq("id", id)).ok
}
