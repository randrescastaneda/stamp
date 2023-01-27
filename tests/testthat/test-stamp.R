library(fs)
library(withr)
op <- options(stamp.verbose = FALSE,
              stamp.seed    = 12332)
defer(options(op))

options(stamp.verbose = FALSE)
x <- data.frame(a = 1:5,
                b = letters[1:5])
test_that("stamp_get", {

  # Names of stamp
  st <- stamp_get(x)
  nm <- names(st)

  expect_equal(nm, c("stamps", "time", "algo"),
               label = "Names of stamp do not match")

  expect_length(st, 3)

  # same has as diggest
  da <- digest::digest(x$a, getOption("stamp.digest.algo"))
  db <- digest::digest(x$b, getOption("stamp.digest.algo"))

  expect_equal(st$stamps$a, da, label = "same hash as digest")
  expect_equal(st$stamps$b, db, label = "same hash as digest")

  # hash for every element of list
  expect_equal(length(x), length(st$stamps))

  # atomic vectors
  stl <- stamp_get(letters)
  expect_length(stl$stamps, 1)

  # Test time objects
  st_tnm <- names(st$time)
  expect_equal(st_tnm, c("tz", "tformat", "usetz", "st_time"))


})

test_that("stamp_set & stamp_call", {
  st <- stamp_get(x)
  stamp_set(x, "st_x")
  st_x <- stamp_call("st_x")
  expect_equal(st, st_x)

  # try to reset an existiing stamp
  stamp_set(x, "st_x") |>
    expect_error()

  # replace works
  stamp_set(letters, "st_x", replace = TRUE)
  stl <- stamp_get(letters)
  expect_equal(stl, stamp_call("st_x"))

  # Call a stamp that does not exist
  stamp_call("hola") |>
    expect_error()

  # set previously calculated stamp
  st <- stamp_get(x)
  stamp_set(stamp = st, st_name = "st_x2")
  st_x <- stamp_call("st_x2")
  expect_equal(st, st_x)

  stamp_set() |>
    expect_error()

  stamp_set(x = x, stamp = st) |>
    expect_error()


})

test_that("stamp_env & stamp_clean", {

  # clean all
  stamp_clean()
  stn <- stamp_env()
  expect_length(stn, 0)

  # lean specific stamps
  stamp_set(x, "st_x")
  stamp_set(x, "st_y")
  stamp_set(x, "st_z")

  stamp_clean(st_name = "st_x") |>
    expect_true()
  stn <- stamp_env()
  expect_equal(stn, c("st_y", "st_z"))


  # error if stamp is not found
  stamp_clean("hola") |>
    expect_false()

  stamp_clean() |>
    expect_true()

  # Clean stamp
  stamp_clean() |>
    expect_false()

})

test_that("stamp_confirm", {
  x <- data.frame(a = 1:5, b = "hola")
  stx <- stamp_get(x)
  st_name <- "stx"
  stamp_set(x, st_name, replace = TRUE)

  tdir <- path_temp()
  sv <- stamp_save(x, st_dir = tdir, st_name = st_name)
  sv


  # must provide st_dir or st_name
  stamp_confirm(x) |>
    expect_error()

  # st_dir can't be alone
  stamp_confirm(x,
                st_dir = "hola") |>
    expect_error()

  # Syntax errors
  stamp_confirm(x,
                st_dir = "hola",
                st_file =  "chao") |>
    expect_error()

  stamp_confirm(x,
                st_name = "hola",
                st_file =  "chao") |>
    expect_error()

  stamp_confirm(x,
                st_name = "hola",
                stamp =  "chao") |>
    expect_error()

  # st_name does not exist
  stamp_confirm(x, st_name = "blabhblabh") |>
    expect_error()

  # New variable
  x <- data.frame(a = 1:5, b = "hola", c = "chao")
  stamp_confirm(x, st_name = st_name, verbose = TRUE) |>
    expect_false()

  # unchanged data
  x <- data.frame(a = 1:5, b = "hola")

  # test with st_name
  stamp_confirm(x, st_name = st_name, verbose = TRUE) |>
    expect_true()

  # test with st_file
  stamp_confirm(x, st_file = names(sv), verbose = TRUE) |>
    expect_true()

  # test with st_dir and st_name
  stamp_confirm(x,
                st_dir = tdir,
                st_name = st_name,
                verbose = TRUE) |>
    expect_true()

  # test with stamp
  stamp_confirm(x,
                stamp = stx,
                verbose = TRUE) |>
    expect_true()


  # set hash
  x <- data.frame(a = 1:5, b = "hola", c = "chao")

  stamp_clean(st_name = "bmpnocyc")
  stamp_confirm(x,
                st_name = st_name,
                set_hash = TRUE,
                verbose = TRUE)

  "bmpnocyc" %in% stamp_env() |>
  expect_true()

  t_hash <- "test_hash"
  stamp_clean(st_name = t_hash)
  stamp_confirm(x,
                st_name = st_name,
                set_hash = t_hash,
                verbose = TRUE,
                replace = TRUE)

  t_hash %in% stamp_env() |>
  expect_true()



})

test_that("stamp_x_attr ", {

  # Data.frame
  x    <- data.frame(a = 1:5, b = "hola")
  at_x <-  stamp_x_attr(x)
  atn <- names(at_x)
  skip_if_not(requireNamespace("skimr", quietly = TRUE))
  expect_equal(atn, c("names", "class", "row.names", "skim", "dim", "type"))

  skip_if(requireNamespace("skimr", quietly = TRUE))
  expect_equal(atn, c("names", "class", "row.names", "summary","dim", "type"))

  # list
  x    <- list(a = 1:5, b = "hola")
  at_x <-  stamp_x_attr(x)
  atn <- names(at_x)
  expect_equal(atn,  c("names", "length", "type", "class"))


})

test_that("stamp_save", {

  # defenses
  stamp_save() |>
    expect_error()

  stamp_save(x_attr = TRUE) |>
    expect_error()

  # stamps
  crt_wd <- getwd()
  defer(setwd(crt_wd))

  while (!is.null(file_temp_pop())) next
  file_temp_push(path(path_temp(),letters))


  stamp <- stamp_get(x)
  st_dir <- path_temp()
  st_name <- "xst"

  sv <- stamp_save(st_dir = st_dir,
             st_name = st_name,
             stamp   = stamp)

  expect_true(sv)

  nsv <- names(sv) |>
    path()
  nsv |>
    is_file() |>
    expect_true()

  exp_out <- path(st_dir,
                  getOption("stamp.dir_stamp"),
                  paste0(getOption("stamp.stamp_prefix"), st_name),
                  ext = getOption("stamp.default.ext"))
  expect_equal(nsv, exp_out)

  sv <- stamp_save(st_dir = st_dir,
                   st_name = st_name,
                   stamp   = stamp)

  svx <- stamp_save(x = x,
                    st_dir = st_dir,
                   st_name = st_name)
  expect_equal(sv, svx)


  stamp_save(x        = x,
            st_dir    = st_dir,
            st_name   = st_name,
            x_attr    = TRUE,
            stamp_set = TRUE,
            replace   = TRUE)

  svxa <- stamp_call(st_name)

  xtt <- stamp_x_attr(x)

  expect_equal(svxa$x_attr, xtt)




})

test_that("stamp_read", {

  x <- data.frame(a = 1:5,
                  b = letters[1:5])

  st_dir <- tempdir()
  st_name <- "xst2"
  sv <- stamp_save(x = x,
                  st_dir = st_dir,
                  st_name = st_name,
                  stamp_set = TRUE
                  )

  nsv <- names(sv) |>
   fs::path()

  str <- stamp_read(st_file = nsv)
  stc <- stamp_call(st_name)

  expect_equal(str$stamps,
               stc$stamps)

  str2 <- stamp_read(st_dir = st_dir,
                    st_name = st_name)

  expect_equal(str2$stamps,
               stc$stamps)


})
