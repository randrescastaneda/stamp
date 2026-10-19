testthat::test_that("st_save accepts pk and domain without forwarding to writer", {
  local_stamp_state()
  td <- withr::local_tempdir()
  withr::local_dir(td)
  local_st_opts(default_format = "qs2")
  st_init(root = td)

  df <- data.frame(id = 1L, val = "a", stringsAsFactors = FALSE)
  p <- fs::path(td, "data", "sample.qs2")

  # should not error even though pk/domain are not writer args
  testthat::expect_error(st_save(df, p, pk = "id", domain = "test"), NA)
  meta <- st_read_sidecar(p)
  testthat::expect_identical(st_get_pk(meta), "id")
  testthat::expect_identical(meta$domain, "test")
  loaded <- st_load(p, verbose = FALSE)
  expected <- df
  attr(expected, "stamp_pk") <- list(keys = "id")
  attr(expected, "stamp_domain") <- "test"
  testthat::expect_identical(loaded, expected)
  testthat::expect_null(attr(df, "stamp_pk"))
  testthat::expect_null(attr(df, "stamp_domain"))
})


testthat::test_that("st_list_parts ignores sidecar/stmeta and returns partition keys", {
  local_stamp_state()
  td <- withr::local_tempdir()
  withr::local_dir(td)
  local_st_opts(default_format = "qs2")
  st_init(root = td)

  base <- fs::path(td, "parts")
  fs::dir_create(base)

  # write one partition
  stamp:::st_save_part(
    data.frame(x = 1),
    base,
    key = list(country = "col", year = 2010, reporting_level = "urban"),
    pk = "x"
  )

  parts <- stamp:::st_list_parts(base)
  testthat::expect_equal(nrow(parts), 1L)
  testthat::expect_named(parts, c("path", "country", "reporting_level", "year"))
  testthat::expect_identical(parts$country, "col")
  testthat::expect_identical(parts$year, "2010")
  testthat::expect_identical(parts$reporting_level, "urban")
  testthat::expect_identical(
    as.character(fs::path_rel(parts$path, start = base)),
    "country=col/reporting_level=urban/year=2010/part.qs2"
  )
})


testthat::test_that("st_part_path and st_list_parts round-trip partition keys", {
  local_stamp_state()
  td <- withr::local_tempdir()
  withr::local_dir(td)
  local_st_opts(default_format = "qs2")
  st_init(root = td)

  base <- fs::path(td, "parts2")
  fs::dir_create(base)
  key <- list(country = "col", year = 2010, reporting_level = "rural")
  expected_path <- fs::path(base, "country=col", "reporting_level=rural", "year=2010", "part.qs2")
  testthat::expect_identical(
    as.character(stamp:::st_part_path(base, key)), as.character(expected_path)
  )

  stamp:::st_save_part(data.frame(x = 1), base, key = key, pk = "x")
  listing <- stamp:::st_list_parts(base)

  testthat::expect_equal(nrow(listing), 1L)
  testthat::expect_identical(listing$country, "col")
  testthat::expect_identical(listing$year, "2010")
  testthat::expect_identical(listing$reporting_level, "rural")
  testthat::expect_identical(
    as.character(fs::path_rel(listing$path, start = base)),
    "country=col/reporting_level=rural/year=2010/part.qs2"
  )
})


testthat::test_that("st_part_path rejects invalid partition keys", {
  local_stamp_state()
  base <- withr::local_tempdir()
  testthat::expect_error(
    stamp:::st_part_path(base, list(a = "bad/value")), "Partition values cannot contain"
  )
  testthat::expect_error(
    stamp:::st_part_path(base, list(a = "bad=value")), "Partition values cannot contain"
  )
  testthat::expect_identical(list.files(base, all.files = TRUE, no.. = TRUE), character())
})
