test_that("st_save_part and st_list_parts work and st_load_parts binds", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  base <- fs::path(td, "parts")
  k1 <- list(country = "US", year = 2025)
  k2 <- list(country = "US", year = 2024)

  st_save_part(data.frame(x = 1:2), base, k1, code = function(z) z)
  st_save_part(data.frame(x = 3:4), base, k2, code = function(z) z)

  lst <- st_list_parts(base)
  expect_true(nrow(lst) >= 2)

  # Filter by key
  one <- st_list_parts(base, filter = list(year = 2025))
  expect_true(nrow(one) == 1)

  # Load and rbind
  all <- st_load_parts(base, as = "rbind")
  expect_true(nrow(all) >= 2)
})

test_that("st_list_parts returns empty for missing base and st_load_parts dt mode works", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  base <- fs::path(td, "noexist")
  res <- st_list_parts(base)
  expect_true(is.data.frame(res) && nrow(res) == 0)

  # create some parts and test dt mode if data.table available
  base2 <- fs::path(td, "parts2")
  st_save_part(data.frame(x=1:2), base2, list(k=1), code = function(z) z)
  if (requireNamespace("data.table", quietly = TRUE)) {
    dt <- st_load_parts(base2, as = "dt")
    expect_s3_class(dt, "data.table")
  }
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
