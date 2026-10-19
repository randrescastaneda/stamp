test_that("sparse data.frame and data.table partitions save only observed rows", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  x <- data.frame(country = c("USA", "CAN", "USA"),
                  year = c(2020L, 2021L, 2020L), value = c(11L, 22L, 33L))
  for (kind in c("df", "dt")) {
    input <- if (kind == "df") x else data.table::as.data.table(x)
    before <- data.table::copy(input)
    base <- fs::path(td, kind)
    expect_no_warning(manifest <- suppressMessages(stamp:::st_write_parts(
      input, base, c("country", "year"), .progress = FALSE, verbose = FALSE
    )))
    expect_identical(input, before)
    expect_equal(nrow(manifest), 2L)
    expect_equal(sort(manifest$n_rows), c(1L, 2L))
    expect_equal(sort(vapply(manifest$partition_key, function(k) k$country,
                              character(1))), c("CAN", "USA"))
    expect_true(all(nzchar(manifest$version_id)))
    payloads <- fs::path(manifest$path, fs::path_file(manifest$path))
    expect_true(all(fs::file_exists(payloads)))
    stored <- lapply(payloads, nanoparquet::read_parquet)
    expect_equal(sort(unlist(lapply(stored, function(z) z$value))), c(11L, 22L, 33L))
    all <- stamp:::st_load_parts(base, as = "dt")
    expect_identical(sort(all$value), c(11L, 22L, 33L))
    projected <- stamp:::st_load_parts(base, columns = "value", as = "dt")
    expect_identical(sort(projected$value), c(11L, 22L, 33L))
    expect_setequal(names(projected), c("value", "country", "year"))
    expect_identical(projected, all[, c("value", "country", "year"), with = FALSE])
  }
})

test_that("partition filters select independently specified exact rows", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  x <- data.frame(country = c("usa", "can", "usa", "mex"),
                  year = c(2020L, 2021L, 2022L, 2022L), value = 1:4)
  base <- fs::path(td, "parts")
  stamp:::st_write_parts(x, base, c("country", "year"),
                        .progress = FALSE, verbose = FALSE)
  filters <- list(list(country = "usa"), list(year = 2022),
                  list(year = "2022"), ~ year > 2020,
                  ~ country == "usa" & year >= 2022,
                  ~ country == "can" | year == 2020,
                  ~ country %in% c("usa", "mex") & year != 2020,
                  ignored ~ year == 2021)
  expected <- list(c(1L, 3L), c(3L, 4L), c(3L, 4L), 2:4,
                   3L, 1:2, 3:4, 2L)
  for (i in seq_along(filters)) {
    listing <- stamp:::st_list_parts(base, filters[[i]])
    expect_equal(nrow(listing), length(expected[[i]]))
    loaded <- stamp:::st_load_parts(base, filters[[i]], as = "dt")
    expect_identical(sort(loaded$value), expected[[i]])
  }
  expect_error(stamp:::st_list_parts(base, filter = 2020), "Invalid filter")
  expect_equal(nrow(stamp:::st_list_parts(base, ~ absent > 2)), 0L)
})

test_that("empty and invalid partition datasets have visible outcomes", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  expect_error(stamp:::st_write_parts(data.frame(a = 1), td, "missing"),
               "not found in data")
  expect_warning(empty <- stamp:::st_write_parts(
    data.frame(a = character(), value = integer()),
    fs::path(td, "empty"), "a", .progress = FALSE
  ), "No partitions created")
  expect_equal(nrow(empty), 0L)
  expect_length(empty$path, 0L)
})
