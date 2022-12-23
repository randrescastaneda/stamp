library(fs)
df <- data.frame(l = letters[1:5],
                 X = c(1:5))

test_that("file management works", {

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))

  tdir <- path_temp()
  tfile <- file_temp(ext = "qs")

  st_write(df, tfile, ext = "fst") |>
    expect_warning(label = "differnet extensions")


  st_write(df, path(tdir, "temp", "file")) |>
    expect_error(label = "dir does not exist")


  tfile <- file_temp(ext = "qs")
  st_dir <- path(tdir, "_st_dir")
  if (dir_exists(st_dir)) dir_delete(st_dir)
  st_write(df, tfile)

  dir_exists(st_dir) |>
    expect_true(label = "Creates st_dir when parameter is NULL")

  crt_wd <- getwd()
  path(tdir, "wd") |>
    dir_create() |>
    setwd()

  st_dir <- path(tdir, "wd", "st_dir")
  if (dir_exists(st_dir)) dir_delete(st_dir)

  st_write(df, tfile, st_dir = "st_dir")
  st_dir |>
    dir_exists() |>
    expect_true(label = "relative path for st_dir does not work")

  st_dir <- path(tdir, "wd", "st_dir2")
  if (dir_exists(st_dir)) dir_delete(st_dir)

  st_write(df, tfile, st_dir = st_dir)
  st_dir |>
    dir_exists() |>
    expect_true(label = "Absolute path for st_dir does not work")

  setwd(crt_wd)


})
