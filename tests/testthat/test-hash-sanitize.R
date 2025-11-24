library(data.table)

test_that("data.table hashing ignores volatile internals", {
  skip_if_not_installed("collapse")  

  dt <- data.table(a = 1:5, b = letters[1:5])
  # Create via different path (duplicate then unique)
  dt_alt <- collapse::rowbind(dt, dt) |> collapse::funique()

  # Sanity: content identical
  expect_true(identical(as.data.frame(dt), as.data.frame(dt_alt)))

  h1 <- st_hash_obj(dt)
  h2 <- st_hash_obj(dt_alt)
  expect_equal(h1, h2)
})

test_that("saving + loading restores data.table class", {
  tdir <- tempfile("stamp-sanitize-test-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(a = 1:3, b = letters[1:3])
  path <- file.path(tdir, "dt.qs2")
  st_save(dt, path)
  loaded <- st_load(path)
  expect_true(inherits(loaded, "data.table"))
  expect_true(identical(as.data.frame(dt), as.data.frame(loaded)))
})
