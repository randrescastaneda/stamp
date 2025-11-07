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
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
