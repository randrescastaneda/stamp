test_that("qs2 readers and writers preserve R object fidelity independently", {
  x <- structure(list(
    factor = factor(c("b", "a"), levels = c("a", "b", "unused")),
    date = as.Date(c("2020-01-01", NA)), nested = list(1:2, NULL)
  ), note = "retained")
  p <- withr::local_tempfile(fileext = ".qs2")
  stamp:::.st_write_qs2(x, p)
  expect_identical(qs2::qs_read(p), x)
  qs2::qs_save(x, p)
  expect_identical(stamp:::.st_read_qs2(p), x)
})

test_that("extension defaults are stable and qs uses qs2 without legacy qs", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  before <- st_extmap_report()
  stamp:::.seed_extmap()
  expect_identical(st_extmap_report(), before)
  for (ext in c("qs", "qs2")) {
    p <- fs::path(td, paste0("data.", ext))
    st_save(data.frame(a = 1:3), p, verbose = FALSE)
    expect_identical(st_read_sidecar(p)$format, "qs2")
    expect_equal(st_load(p, verbose = FALSE)$a, 1:3)
  }
  expect_true(all(c("qs2", "rds", "csv", "fst", "parquet", "json") %in%
                    st_formats()))
  expect_identical(st_formats(), sort(st_formats()))
})

test_that("custom registration forwards arguments and replaces handlers", {
  local_stamp_state()
  calls <- list()
  reader <- function(path, token, ...) {
    calls$read <<- list(path = path, token = token, dots = list(...))
    readRDS(path)
  }
  writer <- function(x, path, token, ...) {
    calls$write <<- list(token = token, dots = list(...))
    saveRDS(x, path)
  }
  expect_message(
    out <- withVisible(st_register_format(
      "audit_custom", reader, writer, c("AUD", "aud", "")
    )), "Registered"
  )
  expect_identical(out$value, TRUE)
  expect_false(out$visible)
  expect_identical(stamp:::.st_guess_format("file.AUD"), "audit_custom")
  h <- stamp:::.st_formats_env$audit_custom
  p <- withr::local_tempfile()
  h$write(1:3, p, token = "write", extra = 17L, verbose = FALSE)
  expect_identical(h$read(p, token = "read", extra = 23L), 1:3)
  expect_identical(calls$write, list(token = "write", dots = list(extra = 17L)))
  expect_identical(calls$read,
                   list(path = p, token = "read", dots = list(extra = 23L)))
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  artifact <- fs::path(td, "custom.aud")
  st_save(data.frame(value = 1:3), artifact, token = "save", extra = 17L,
          verbose = FALSE)
  loaded <- st_load(artifact, token = "load", extra = 23L, verbose = FALSE)
  expect_identical(loaded$value, 1:3)
  expect_identical(st_read_sidecar(artifact)$format, "audit_custom")
  expect_identical(calls$write, list(token = "save", dots = list(extra = 17L)))
  expect_identical(calls$read$token, "load")
  expect_identical(calls$read$dots, list(extra = 23L))
  expect_message(st_register_format(
    "audit_custom", function(path, ...) "replacement", writer
  ), "Replaced")
  expect_identical(stamp:::.st_formats_env$audit_custom$read(p), "replacement")
  expect_identical(stamp:::.st_guess_format("file.aud"), "audit_custom")
  expect_error(st_register_format("bad", NULL, writer))
  expect_error(st_register_format(c("a", "b"), reader, writer))
  expect_error(stamp:::.st_extmap_set("x", "not_registered"), "not registered")
})

test_that("explicit format overrides extension inference for current reads", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  p <- fs::path(td, "actually-rds.csv")
  st_save(list(answer = 42L), p, format = "rds", verbose = FALSE)
  expect_identical(st_read_sidecar(p)$format, "rds")
  expect_identical(st_load(p, format = "rds", verbose = FALSE),
                   list(answer = 42L))
})
