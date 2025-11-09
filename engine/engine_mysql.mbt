///|
pub fn @morm.DeleteQuery::to_mysql_sql(self : @morm.DeleteQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("DELETE FROM ")
  buf.write_string(self.from)
  if !self.where_.is_empty() {
    buf.write_string(" WHERE ")
    buf.write_string(
      self.where_
      .map(w => {
        let ty = match w.ty {
          Eq => "="
          Gt => ">"
          Lt => "<"
          Gte => ">="
          Lte => "<="
        }
        [w.col, ty, w.value.stringify()].join(" ")
      })
      .join(" AND "),
    )
  }
  buf.to_string()
}

///|
pub fn @morm.Query::to_mysql_sql(self : @morm.Query) -> String {
  let buf = @buffer.new()
  if self.select.is_empty() {
    buf.write_string("SELECT * FROM ")
  } else {
    buf.write_string("SELECT ")
    buf.write_string(self.select)
    buf.write_string(" FROM ")
  }
  if !self.from.is_empty() {
    buf.write_string(self.from)
  }
  if !self.where_.is_empty() {
    buf.write_string(" WHERE ")
    buf.write_string(
      self.where_
      .map(w => {
        let ty = match w.ty {
          Eq => "="
          Gt => ">"
          Lt => "<"
          Gte => ">="
          Lte => "<="
        }
        [w.col, ty, w.value.stringify()].join(" ")
      })
      .join(" AND "),
    )
  }
  if !self.order_by.is_empty() {
    buf.write_string(" ORDER BY ")
    buf.write_string(
      self.order_by
      .map(ob => match ob {
        Asc(col) => [col, "ASC"].join(" ")
        Desc(col) => [col, "DESC"].join(" ")
      })
      .join(", "),
    )
  }
  if self.limit is Some(limit) {
    buf.write_string(" LIMIT ")
    buf.write_string(limit.to_string())
  }
  if self.offset is Some(offset) {
    buf.write_string(" OFFSET ")
    buf.write_string(offset.to_string())
  }
  buf.to_string()
}

///|
pub fn @morm.InsertQuery::to_mysql_sql(self : @morm.InsertQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("INSERT INTO ")
  buf.write_string(self.into)
  if !self.columns.is_empty() {
    buf.write_string(" (")
    buf.write_string(self.columns.join(", "))
    buf.write_string(")")
  }
  buf.write_string(" VALUES (")
  buf.write_string(self.values.map(v => v.stringify()).join(", "))
  buf.write_string(")")
  buf.to_string()
}
