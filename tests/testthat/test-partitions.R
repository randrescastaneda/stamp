st_opts(warn_missing_pk_on_load = FALSE)
test_that("st_save_part and st_list_parts work and st_load_parts binds", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  base <- fs::path(td, "parts")
  k1 <- list(country = "US", year = 2025)
  k2 <- list(country = "US", year = 2024)

  stamp:::st_save_part(data.frame(x = 1:2), base, k1, code = function(z) z)
  stamp:::st_save_part(data.frame(x = 3:4), base, k2, code = function(z) z)

  lst <- stamp:::st_list_parts(base)
  expect_true(nrow(lst) >= 2)

  # Filter by key
  one <- stamp:::st_list_parts(base, filter = list(year = 2025))
  expect_true(nrow(one) == 1)

  # Load and rbind
  all <- stamp:::st_load_parts(base, as = "rbind")
  expect_true(nrow(all) >= 2)
})

test_that("st_list_parts returns empty for missing base and st_load_parts dt mode works", {
  skip_on_cran()
  skip_if_not_installed("data.table")
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  base <- fs::path(td, "noexist")
  res <- stamp:::st_list_parts(base)
  expect_true(is.data.frame(res) && nrow(res) == 0)

  # create some parts and test dt mode if data.table available
  base2 <- fs::path(td, "parts2")
  stamp:::st_save_part(data.frame(x = 1:2), base2, list(k = 1), code = function(z) z)
  dt <- stamp:::st_load_parts(base2, as = "dt")
  expect_s3_class(dt, "data.table")
})

test_that("st_part_path rejects invalid partition keys and sanitizes values", {
  skip_on_cran()
  # invalid characters in partition value
  expect_error(stamp:::st_part_path("/tmp", list(a = "bad/value")))
  expect_error(stamp:::st_part_path("/tmp", list(a = "bad=value")))

  # numeric keys coerced to strings and ordering stable
  p1 <- stamp:::st_part_path("/tmp", list(b = 2, a = 1), format = "rds")
  p2 <- stamp:::st_part_path("/tmp", list(a = 1, b = 2), format = "rds")
  expect_equal(p1, p2)
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
