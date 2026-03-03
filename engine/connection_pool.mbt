///|
pub(all) struct ConnectionPool[C] {
  idle : @async.Queue[C]
  permits : @async.Semaphore
  mut closed : Bool
}

///|
pub fn[C] ConnectionPool::new(
  max_open : Int,
  max_idle? : Int = max_open,
) -> ConnectionPool[C] {
  guard max_open > 0
  let idle_cap = if max_idle < 0 {
    0
  } else if max_idle > max_open {
    max_open
  } else {
    max_idle
  }
  {
    idle: @async.Queue::new(kind=Blocking(idle_cap)),
    permits: @async.Semaphore::new(max_open),
    closed: false,
  }
}

///|
pub async fn[C] ConnectionPool::borrow(
  self : ConnectionPool[C],
  open_conn : async () -> Result[C, String],
) -> Result[C, String] {
  if self.closed {
    return Err("connection pool is closed")
  }
  self.permits.acquire()
  if self.closed {
    self.permits.release()
    return Err("connection pool is closed")
  }
  let idle_conn = self.idle.try_get() catch {
    _ => {
      self.permits.release()
      return Err("connection pool is closed")
    }
  }
  match idle_conn {
    Some(conn) => Ok(conn)
    None =>
      match open_conn() {
        Ok(conn) => Ok(conn)
        Err(err) => {
          self.permits.release()
          Err(err)
        }
      }
  }
}

///|
pub fn[C] ConnectionPool::release(
  self : ConnectionPool[C],
  conn : C,
  close_conn : (C) -> Unit,
  reusable? : Bool = true,
) -> Unit {
  if self.closed || !reusable {
    close_conn(conn)
    self.permits.release()
    return
  }
  let kept = self.idle.try_put(conn) catch { _ => false }
  if !kept {
    close_conn(conn)
  }
  self.permits.release()
}

///|
pub fn[C] ConnectionPool::close(
  self : ConnectionPool[C],
  close_conn : (C) -> Unit,
) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  self.idle.close()
  while true {
    let item = self.idle.try_get() catch { _ => break }
    match item {
      Some(conn) => close_conn(conn)
      None => break
    }
  }
}
