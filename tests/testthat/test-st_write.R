skip("st_write has to be re-written")
library(fs)
library(withr)
df <- data.frame(l = letters[1:5],
                 X = c(1:5))

test_that("file management works", {
  crt_wd <- getwd()
  defer(setwd(crt_wd))

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))

  tdir <- path_temp()
  setwd(tdir)
  tfile <- file_temp(ext = "qs")

  st_write(x = df,
           file = tfile, ext = "fst") |>
    expect_warning(label = "differnet extensions")


  st_write(df, path(tdir, "temp", "file"), recurse = FALSE) |>
    expect_error(label = "dir does not exist")

  stamp_dir <- getOption("stamp.dir_stamp")

  tfile <- file_temp(ext = "qs")
  st_dir <- path(tdir, stamp_dir)
  if (dir_exists(st_dir)) {
    dir_delete(st_dir)
  }

  st_write(df, tfile)

  dir_exists(st_dir) |>
    expect_true(label = "Creates st_dir when parameter is NULL")


  path(tdir, "wd") |>
    dir_create() |>
    setwd()

  st_dir <- path(tdir, "wd", "tmp", stamp_dir)
  if (dir_exists(st_dir)) {
    dir_delete(st_dir)
  }

  st_write(df, tfile, st_dir = paste0("tmp/", stamp_dir))
  st_dir |>
    dir_exists() |>
    expect_true(label = "relative path for st_dir does not work")

  st_dir <- path(tdir, "wd", "tmp/st_dir2")
  if (dir_exists(st_dir)) {
    dir_delete(st_dir)
  }

  st_write(df, tfile, st_dir = st_dir)
  st_dir |>
    dir_exists() |>
    expect_true(label = "Absolute path for st_dir does not work")

})
