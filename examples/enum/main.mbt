///|
fn main {
  let status_param = PostStatus::Published
  println("enum: param=\{ToJson::to_json(status_param).stringify()}")

  let decoded : PostStatus = status_param
  println("enum: decoded=\{ToJson::to_json(decoded).stringify()}")

  println("enum: table=\{Post::table().to_json().stringify()}")
}
