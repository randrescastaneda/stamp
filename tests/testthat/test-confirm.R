test_that("Confirm_data() works as expected", {
  x <- data.frame(a = 1:5, b = "hola")
  st_name <- "stx"
  stamp_set(x, st_name, replace = TRUE)
  stamp <- stamp_call(st_name)

  # New variable
  x <- data.frame(a = 1:5, b = "hola", c = "chao")

  hash <- stamp_get(x)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_data(ss, sh) |>
    expect_false()

  # different variable
  x <- data.frame(a = 6:10,
                  b = "hola")

  hash <- stamp_get(x)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_data(ss, sh) |>
    expect_false()

  # different number of variables in other data
  y <- data.frame(a = 1:5)

  hash <- stamp_get(y)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_data(ss, sh) |>
    expect_false()

  # no intersection of names
  x <- data.frame(a = 1:5, b = "hola")

  st_name <- "stx"
  stamp_set(x, st_name, replace = TRUE)
  stamp <- stamp_call(st_name)

  # New variable
  x <- data.frame(d = 1:5, c = "hola")

  hash <- stamp_get(x)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_data(ss, sh) |>
    expect_false()

})

test_that("confirm_names works as expected", {
  # no intersection of names
  x <- data.frame(a = 1:5, b = "hola")

  st_name <- "stx"
  stamp_set(x, st_name, replace = TRUE)
  stamp <- stamp_call(st_name)

  # New variable
  x <- data.frame(d = 1:5, c = "hola")

  hash <- stamp_get(x)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_names(ss, sh) |>
    expect_false()


  # Same names with different values
  x <- data.frame(a = 1:5, b = "hola")

  st_name <- "stx"
  stamp_set(x, st_name, replace = TRUE)
  stamp <- stamp_call(st_name)

  # New variable
  x <- data.frame(a = 6:10, b = "chao")

  hash <- stamp_get(x)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  confirm_names(ss, sh) |>
    expect_true()

})

