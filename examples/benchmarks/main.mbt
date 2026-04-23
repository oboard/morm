///|
let metric_iterations = 500

///|
fn metric_percentile(samples : Array[Double], numerator : Int) -> Double {
  let len = samples.length()
  let mut index = (len * numerator + 99) / 100 - 1
  if index < 0 {
    index = 0
  }
  if index >= len {
    index = len - 1
  }
  samples[index]
}

///|
fn metric_median(samples : Array[Double]) -> Double {
  let len = samples.length()
  if len % 2 == 0 {
    (samples[len / 2 - 1] + samples[len / 2]) / 2.0
  } else {
    samples[len / 2]
  }
}

///|
fn metric_json(name : String, samples : Array[Double]) -> String {
  samples.sort()
  let len = samples.length()
  let mut sum = 0.0
  for sample in samples {
    sum += sample
  }
  let mean = sum / len.to_double()
  let mut variance = 0.0
  for sample in samples {
    let delta = sample - mean
    variance += delta * delta
  }
  let stddev = (variance / len.to_double()).sqrt()
  let median = metric_median(samples)
  let q1 = metric_percentile(samples, 25)
  let q3 = metric_percentile(samples, 75)
  let p99 = metric_percentile(samples, 99)
  "{ \"name\": \"\{name}\", \"iterations\": \{len}, \"mean_us\": \{mean}, \"median_us\": \{median}, \"iqr_us\": \{q3 - q1}, \"stddev_us\": \{stddev}, \"p99_us\": \{p99} }"
}

///|
fn run_metric(name : String, op : () -> Unit) -> String {
  let samples : Array[Double] = []
  for _ in 0..<metric_iterations {
    let started = @bench.monotonic_clock_start()
    op()
    samples.push(@bench.monotonic_clock_end(started))
  }
  metric_json(name, samples)
}

///|
fn metric_select_count(result : @engine.QueryResult) -> Int {
  result.rows.length()
}

///|
fn run_main_metrics(
  engine : @sqlite3.SQLiteEngine,
  mapper : BenchUserMapperImpl,
) -> Array[String] {
  let rows : Array[String] = []
  let mut sink = 0
  let mut create_id = 100_000
  let mut delete_id = 200_000
  rows.push(
    run_metric("morm/sqlite/find_all", fn() {
      @async.run_async_main(async fn() {
        sink += metric_select_count(
          engine.exec(@morm.select_from("bench_user")),
        )
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/filter_paginate_sort", fn() {
      @async.run_async_main(async fn() {
        let page = mapper.find_users_page_by_active(
          1,
          @morm.pageable_with_sort(2, 20, @morm.asc("id")),
        )
        sink += page.content.length()
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/nested_find_all", fn() {
      @async.run_async_main(async fn() {
        sink += metric_select_count(
          engine.exec(
            @morm.select_from("bench_user u")
            .join("LEFT JOIN bench_post p ON p.user_id = u.id")
            .order_by(Asc("u.id"))
            .limit(120),
          ),
        )
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/find_first", fn() {
      @async.run_async_main(async fn() {
        sink += metric_select_count(
          engine.exec(
            @morm.select_from("bench_user").order_by(Asc("id")).limit(1),
          ),
        )
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/nested_find_first", fn() {
      @async.run_async_main(async fn() {
        sink += metric_select_count(
          engine.exec(
            @morm.select_from("bench_user u")
            .join("LEFT JOIN bench_post p ON p.user_id = u.id")
            .order_by(Asc("u.id"))
            .limit(1),
          ),
        )
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/find_unique", fn() {
      @async.run_async_main(async fn() {
        if mapper.find_user_by_id(42) is Some(_) {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/nested_find_unique", fn() {
      @async.run_async_main(async fn() {
        let users : FixedArray[BenchUser] = [bench_user(42)]
        let loaded : Map[String, Array[BenchPost]] = @morm.preload_has_many(
          engine, users, "id", "bench_post", "user_id",
        )
        sink += loaded.length()
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/create", fn() {
      create_id += 1
      @async.run_async_main(async fn() {
        if mapper.save(bench_user(create_id)) {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/nested_create", fn() {
      create_id += 1
      @async.run_async_main(async fn() {
        ignore(mapper.save(bench_user(create_id)))
        let posts : FixedArray[BenchPost] = [
          bench_post(create_id * 10 + 1, create_id),
          bench_post(create_id * 10 + 2, create_id),
        ]
        if engine.exec(@morm.insert_into("bench_post").from_many(posts)).ok {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/update", fn() {
      @async.run_async_main(async fn() {
        if mapper.update_active_by_id(0, 42) {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/nested_update", fn() {
      @async.run_async_main(async fn() {
        ignore(mapper.update_active_by_id(1, 42))
        if engine.exec(
            @morm.update("bench_post")
            .set("published", 1)
            .where_eq("user_id", 42),
          ).ok {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/upsert", fn() {
      @async.run_async_main(async fn() {
        if mapper.save({ ..bench_user(42), active: 1 }) {
          sink += 1
        }
      })
    }),
  )
  rows.push(
    run_metric("morm/sqlite/delete", fn() {
      delete_id += 1
      @async.run_async_main(async fn() {
        ignore(mapper.save(bench_user(delete_id)))
        if mapper.delete_by_id(delete_id) {
          sink += 1
        }
      })
    }),
  )
  if sink < 0 {
    println(sink)
  }
  rows
}

///|
fn main {
  let engine = setup_engine()
  let mapper = BenchUserMapperImpl::new(engine)
  let rows = run_main_metrics(engine, mapper)
  println("[")
  rows.eachi((index, row) => {
    let suffix = if index == rows.length() - 1 { "" } else { "," }
    println("  " + row + suffix)
  })
  println("]")
  engine.close()
}
