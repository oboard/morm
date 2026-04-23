///|
fn render_len(query : &@engine.QueryBuilder) -> Int {
  let (sql, params) = @engine.render_query_sql(query)
  sql.length() + params.length()
}

///|
test "morm query builder render benchmarks" (b : @bench.T) {
  b.bench(name="morm/render/find_all", fn() {
    b.keep(render_len(@morm.select_from("bench_user")))
  })
  b.bench(name="morm/render/filter_paginate_sort", fn() {
    b.keep(
      render_len(
        @morm.select_from("bench_user")
        .where_eq("active", 1)
        .order_by(Asc("id"))
        .limit(20)
        .offset(40),
      ),
    )
  })
  b.bench(name="morm/render/find_first", fn() {
    b.keep(
      render_len(@morm.select_from("bench_user").order_by(Asc("id")).limit(1)),
    )
  })
  b.bench(name="morm/render/find_unique", fn() {
    b.keep(render_len(@morm.select_from("bench_user").where_eq("id", 42)))
  })
  b.bench(name="morm/render/nested_find_unique", fn() {
    b.keep(
      render_len(
        @morm.select_from("bench_user u")
        .join("LEFT JOIN bench_post p ON p.user_id = u.id")
        .where_eq("u.id", 42),
      ),
    )
  })
  b.bench(name="morm/render/create", fn() {
    b.keep(render_len(@morm.insert_into("bench_user").from(bench_user(501))))
  })
  b.bench(name="morm/render/nested_create", fn() {
    let rows : FixedArray[BenchPost] = [
      bench_post(1001, 501),
      bench_post(1002, 501),
    ]
    b.keep(render_len(@morm.insert_into("bench_post").from_many(rows)))
  })
  b.bench(name="morm/render/update", fn() {
    b.keep(
      render_len(@morm.update("bench_user").set("active", 0).where_eq("id", 42)),
    )
  })
  b.bench(name="morm/render/upsert", fn() {
    b.keep(render_len(@morm.upsert_into("bench_user").from(bench_user(42))))
  })
  b.bench(name="morm/render/delete", fn() {
    b.keep(render_len(@morm.delete_from("bench_user").where_eq("id", 42)))
  })
}

///|
test "morm sqlite latency benchmarks" (b : @bench.T) {
  let engine = setup_engine()
  let mapper = BenchUserMapperImpl::new(engine)
  let mut create_id = 10_000
  let mut delete_id = 20_000
  b.bench(name="morm/sqlite/find_all", fn() {
    @async.run_async_main(async fn() {
      let res = engine.exec(@morm.select_from("bench_user"))
      b.keep(res.rows.length())
    })
  })
  b.bench(name="morm/sqlite/filter_paginate_sort", fn() {
    @async.run_async_main(async fn() {
      let page = mapper.find_users_page_by_active(
        1,
        @morm.pageable_with_sort(2, 20, @morm.asc("id")),
      )
      b.keep(page.content.length() + page.total_elements)
    })
  })
  b.bench(name="morm/sqlite/nested_find_all", fn() {
    @async.run_async_main(async fn() {
      let res = engine.exec(
        @morm.select_from("bench_user u")
        .join("LEFT JOIN bench_post p ON p.user_id = u.id")
        .order_by(Asc("u.id"))
        .limit(120),
      )
      b.keep(res.rows.length())
    })
  })
  b.bench(name="morm/sqlite/find_first", fn() {
    @async.run_async_main(async fn() {
      let res = engine.exec(
        @morm.select_from("bench_user").order_by(Asc("id")).limit(1),
      )
      b.keep(res.rows.length())
    })
  })
  b.bench(name="morm/sqlite/nested_find_first", fn() {
    @async.run_async_main(async fn() {
      let res = engine.exec(
        @morm.select_from("bench_user u")
        .join("LEFT JOIN bench_post p ON p.user_id = u.id")
        .order_by(Asc("u.id"))
        .limit(1),
      )
      b.keep(res.rows.length())
    })
  })
  b.bench(name="morm/sqlite/find_unique", fn() {
    @async.run_async_main(async fn() { b.keep(mapper.find_user_by_id(42)) })
  })
  b.bench(name="morm/sqlite/nested_find_unique", fn() {
    @async.run_async_main(async fn() {
      let users : FixedArray[BenchUser] = [bench_user(42)]
      let loaded : Map[String, Array[BenchPost]] = @morm.preload_has_many(
        engine, users, "id", "bench_post", "user_id",
      )
      b.keep(loaded.length())
    })
  })
  b.bench(name="morm/sqlite/create", fn() {
    create_id += 1
    @async.run_async_main(async fn() {
      b.keep(mapper.save(bench_user(create_id)))
    })
  })
  b.bench(name="morm/sqlite/nested_create", fn() {
    create_id += 1
    @async.run_async_main(async fn() {
      ignore(mapper.save(bench_user(create_id)))
      let posts : FixedArray[BenchPost] = [
        bench_post(create_id * 10 + 1, create_id),
        bench_post(create_id * 10 + 2, create_id),
      ]
      let res = engine.exec(@morm.insert_into("bench_post").from_many(posts))
      b.keep(res.ok)
    })
  })
  b.bench(name="morm/sqlite/update", fn() {
    @async.run_async_main(async fn() {
      b.keep(mapper.update_active_by_id(0, 42))
    })
  })
  b.bench(name="morm/sqlite/nested_update", fn() {
    @async.run_async_main(async fn() {
      ignore(mapper.update_active_by_id(1, 42))
      let res = engine.exec(
        @morm.update("bench_post").set("published", 1).where_eq("user_id", 42),
      )
      b.keep(res.ok)
    })
  })
  b.bench(name="morm/sqlite/upsert", fn() {
    @async.run_async_main(async fn() {
      b.keep(mapper.save({ ..bench_user(42), active: 1 }))
    })
  })
  b.bench(name="morm/sqlite/delete", fn() {
    delete_id += 1
    @async.run_async_main(async fn() {
      ignore(mapper.save(bench_user(delete_id)))
      b.keep(mapper.delete_by_id(delete_id))
    })
  })
  engine.close()
}
