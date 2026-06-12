///|
fn main {
  let status_param = @morm/engine.to_param(PostStatus::Published)
  println("enum: param=\{status_param.to_json().stringify()}")

  let decoded : PostStatus = try! @morm/engine.from_param(status_param)
  println("enum: decoded=\{decoded.to_json().stringify()}")

  println("enum: table=\{Post::table().to_json().stringify()}")
}
