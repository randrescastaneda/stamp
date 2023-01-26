library(fs)
library(withr)

test_that("check_format", {

  # upper cases
  expect_equal(check_format("Rds"), check_format("rds"))

  # different formats
  check_format(file_ext = "Rds", ext = "fst") |>
    expect_warning()

  # change format of file
  check_format(file_ext = "Rds", ext = "fst") |>
    expect_equal("fst")

  # pakcage available
  check_format(file_ext = "fst") |>
    expect_equal("fst")

  # package not available
  check_format(file_ext = "foo") |>
    expect_error()

})

test_that("pkg_available ", {

  # package avilable
  pk <- pkg_available("fst")
  expect_equal(names(pk), "base")
  expect_true(pk)

  # package not suported
  pkg_available("sdsds") |>
    expect_error()


})

test_that("check_file ", {

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))


  # files does not exist
  tf <- file_temp()
  check_file(tf) |>
    expect_error()

  # files does not exist
  tf <- file_temp() |>
    path(ext = "rds")
  saveRDS(1:5, tf)

  check_file(tf) |>
    expect_true()

})

test_that("format_st_dir ", {
  crt_wd <- getwd()
  defer(setwd(crt_wd))

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))

  tdir <- path_temp()
  setwd(tdir)

  dir_stamp <- getOption("stamp.dir_stamp")
  st_dir <- format_st_dir() |>
    path_wd()

  expect_equal(st_dir, path(tdir, dir_stamp))

  tdir <- path_temp("n1")

  # add dir_stamp in the process
  tdir |>
    format_st_dir() |>
    expect_equal(path(tdir, dir_stamp))

  tdir <- path_temp("n2")

  # add dir_stamp before
  tdir |>
    path(dir_stamp) |>
    dir_create() |>
    format_st_dir() |>
    expect_equal(path(tdir, dir_stamp))

  # relative path
  tdir <- path_temp("n3")

  "n3" |>
    format_st_dir() |>
    expect_equal(path(tdir, dir_stamp))
})

test_that("format_st_name", {

  # random name
  format_st_name(seed = 123) |>
    expect_equal("st_4oncnyz0")

  # name with suffix
  st_name <-  "hola"
  format_st_name(st_name) |>
    expect_equal(paste0("st_", st_name))

  # With suffix
  format_st_name(paste0("st_", st_name)) |>
    expect_equal(paste0("st_", st_name))


})


test_that("format_st_file ", {

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))

  # No arguments
  format_st_file() |>
    expect_error()

  # If no name provided, st_dir MUST be a file
  tdir <- path_temp("dos")

  tdir |>
    dir_create() |>
    format_st_file() |>
    expect_error()


  # If directory does not exist
  file_temp() |>
    path(ext = "fst") |>
    format_st_file() |>
    expect_error()

  # add format
  format_st_file(st_dir = tdir,
                 st_name = "cuatro") |>
    path_ext() |>
    expect_equal(getOption("stamp.default.ext"))


  # replace format based on st_name
  format_st_file(st_dir = tdir,
                 st_name = "cinco.fst") |>
    path_ext() |>
    expect_equal("fst")

  # Check output
  exp_out <- path(tdir,
                  getOption("stamp.dir_stamp"),
                  paste0(getOption("stamp.stamp_prefix"), "cinco.fst"))

  format_st_file(st_dir = tdir,
                 st_name = "cinco.fst") |>
    expect_equal(exp_out)

})
