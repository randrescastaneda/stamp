testthat::test_that("st_save accepts pk and domain without forwarding to writer", {
  skip_if_not_installed("qs2")
  td <- fs::path_temp("stamp_test_vs1") |> fs::dir_create()
  old <- setwd(td)
  on.exit(setwd(old), add = TRUE)
  st_init(root = td)

  df <- data.frame(id = 1L, val = "a", stringsAsFactors = FALSE)
  p <- fs::path(td, "data", "sample.qs2")

  # should not error even though pk/domain are not writer args
  testthat::expect_error(st_save(df, p, pk = "id", domain = "test"), NA)
  # Verify artifact was saved by checking sidecar exists
  testthat::expect_true(!is.null(st_read_sidecar(p)))
})


testthat::test_that("st_list_parts ignores sidecar/stmeta and returns partition keys", {
  td <- fs::path_temp("stamp_test_vs2") |> fs::dir_create()
  old <- setwd(td)
  on.exit(setwd(old), add = TRUE)
  st_init(root = td)

  base <- fs::path(td, "parts")
  fs::dir_create(base)

  # write one partition
  st_save_part(
    data.frame(x = 1),
    base,
    key = list(country = "COL", year = 2010, reporting_level = "urban"),
    pk = "x"
  )

  parts <- st_list_parts(base)
  testthat::expect_true(nrow(parts) >= 1)
  # ensure returned paths do not point into stmeta
  testthat::expect_false(any(grepl("/stmeta/", parts$path, fixed = TRUE)))
})


testthat::test_that("st_part_path and st_list_parts round-trip partition keys", {
  td <- fs::path_temp("stamp_test_vs3") |> fs::dir_create()
  old <- setwd(td)
  on.exit(setwd(old), add = TRUE)
  st_init(root = td)

  base <- fs::path(td, "parts2")
  fs::dir_create(base)
  key <- list(country = "COL", year = 2010, reporting_level = "rural")

  st_save_part(data.frame(x = 1), base, key = key, pk = "x")
  listing <- st_list_parts(base)

  testthat::expect_true(nrow(listing) >= 1)
  testthat::expect_true("country" %in% names(listing))
  testthat::expect_equal(listing$country[1], "COL")
  testthat::expect_equal(listing$year[1], "2010")
  testthat::expect_equal(listing$reporting_level[1], "rural")
})


testthat::test_that("st_part_path rejects invalid partition keys", {
  testthat::expect_error(st_part_path("/tmp", list(a = "bad/value")))
  testthat::expect_error(st_part_path("/tmp", list(a = "bad=value")))
})
