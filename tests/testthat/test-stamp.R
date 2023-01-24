
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



})
