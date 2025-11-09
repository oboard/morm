///|
// ---- MongoDB 命令生成（JSON 字符串） ----
fn format_where_mongo(where_ : FixedArray[@morm.Where]) -> String {
  if where_.is_empty() {
    return "{}"
  }
  let buf = @buffer.new()
  buf.write_string("{")
  let mut first = true
  for w in where_ {
    if !first {
      buf.write_string(", ")
    } else {
      first = false
    }
    match w.ty {
      Eq => {
        buf.write_string("\"")
        buf.write_string(w.col)
        buf.write_string("\": ")
        buf.write_string(w.value.stringify())
      }
      Gt => {
        buf.write_string("\"")
        buf.write_string(w.col)
        buf.write_string("\": {\"$gt\": ")
        buf.write_string(w.value.stringify())
        buf.write_string("}")
      }
      Lt => {
        buf.write_string("\"")
        buf.write_string(w.col)
        buf.write_string("\": {\"$lt\": ")
        buf.write_string(w.value.stringify())
        buf.write_string("}")
      }
      Gte => {
        buf.write_string("\"")
        buf.write_string(w.col)
        buf.write_string("\": {\"$gte\": ")
        buf.write_string(w.value.stringify())
        buf.write_string("}")
      }
      Lte => {
        buf.write_string("\"")
        buf.write_string(w.col)
        buf.write_string("\": {\"$lte\": ")
        buf.write_string(w.value.stringify())
        buf.write_string("}")
      }
    }
  }
  buf.write_string("}")
  buf.to_string()
}

///|
pub fn @morm.Query::to_mongodb_cmd(self : @morm.Query) -> String {
  let buf = @buffer.new()
  buf.write_string("{")
  buf.write_string("\"find\": \"")
  buf.write_string(self.from)
  buf.write_string("\"")
  buf.write_string(", \"filter\": ")
  buf.write_string(format_where_mongo(self.where_))
  if !self.order_by.is_empty() {
    buf.write_string(", \"sort\": {")
    buf.write_string(
      self.order_by
      .map(ob => match ob {
        Asc(col) => ["\"", col, "\": 1"].join("")
        Desc(col) => ["\"", col, "\": -1"].join("")
      })
      .join(", "),
    )
    buf.write_string("}")
  }
  if self.limit is Some(limit) {
    buf.write_string(", \"limit\": ")
    buf.write_string(limit.to_string())
  }
  if self.offset is Some(offset) {
    buf.write_string(", \"skip\": ")
    buf.write_string(offset.to_string())
  }
  if !self.select.is_empty() && self.select != "*" {
    // 省略 projection 以避免 split/trim 等字符串 API 造成的解析问题
  }
  buf.write_string("}")
  buf.to_string()
}

///|
pub fn @morm.InsertQuery::to_mongodb_cmd(self : @morm.InsertQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("{")
  buf.write_string("\"insert\": \"")
  buf.write_string(self.into)
  buf.write_string("\", \"documents\": [")
  // 单行插入
  buf.write_string("{")
  for i in 0..<self.columns.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    buf.write_string("\"")
    buf.write_string(self.columns[i])
    buf.write_string("\": ")
    buf.write_string(self.values[i].stringify())
  }
  buf.write_string("}")
  buf.write_string("]}")
  buf.to_string()
}

///|
pub fn @morm.UpdateQuery::to_mongodb_cmd(self : @morm.UpdateQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("{")
  buf.write_string("\"update\": \"")
  buf.write_string(self.table)
  buf.write_string("\", \"updates\": [")
  buf.write_string("{\"q\": ")
  buf.write_string(format_where_mongo(self.where_))
  buf.write_string(", \"u\": {\"$set\": {")
  for i in 0..<self.sets.length() {
    if i > 0 {
      buf.write_string(", ")
    }
    let s = self.sets[i]
    buf.write_string("\"")
    buf.write_string(s.col)
    buf.write_string("\": ")
    buf.write_string(s.value.stringify())
  }
  buf.write_string("}}}")
  buf.write_string("]}")
  buf.to_string()
}

///|
pub fn @morm.DeleteQuery::to_mongodb_cmd(self : @morm.DeleteQuery) -> String {
  let buf = @buffer.new()
  buf.write_string("{")
  buf.write_string("\"delete\": \"")
  buf.write_string(self.from)
  buf.write_string("\", \"deletes\": [")
  buf.write_string("{\"q\": ")
  buf.write_string(format_where_mongo(self.where_))
  buf.write_string(", \"limit\": 0}")
  buf.write_string("]}")
  buf.to_string()
}
