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

  format_st_dir(tdir) |>
    expect_error()

})
