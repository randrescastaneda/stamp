
x <- data.frame(a = 1:5,
                b = letters[1:5])
test_that("stamp_get works as expected", {

  # Names of stamp
  st <- stamp_get(x)
  nm <- names(st)

  expect_equal(nm, c("stamps", "time", "algo"),
               label = "Names of stamp do not match")

  expect_length(st, 3)




})
