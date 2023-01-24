
x <- data.frame(a = 1:5,
                b = letters[1:5])
test_that("stamp_get works as expected", {

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

test_that("stamp_set works as expected", {
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

})



test_that("stamp_env and stamp_clean works as expected", {

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
    expect_error()

  stamp_clean()

  # Clean stamp
  stamp_clean() |>
    expect_false()

})
