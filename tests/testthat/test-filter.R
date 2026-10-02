test_that("st_filter() subsets on named filters", {
  df <- data.frame(
    country = c("PER", "USA", "PER"),
    year = c(2020L, 2020L, 2021L),
    stringsAsFactors = FALSE
  )

  expect_equal(nrow(st_filter(df, list(country = "PER"))), 2L)
  expect_equal(nrow(st_filter(df, list(country = "PER", year = 2021L))), 1L)
  expect_equal(nrow(st_filter(df, list(country = c("PER", "USA")))), 3L)
  expect_identical(st_filter(df, list()), df)
})

test_that("st_filter() rejects unnamed filters instead of silently matching all", {
  df <- data.frame(country = c("PER", "USA"), stringsAsFactors = FALSE)

  expect_error(st_filter(df, list("PER")), "must be named")
  expect_error(st_filter(df, list(country = "PER", "USA")), "must be named")
  expect_error(st_filter(df, list("PER"), strict = FALSE), "must be named")
})

test_that("st_filter() surfaces unknown columns under both strict settings", {
  df <- data.frame(country = c("PER", "USA"), stringsAsFactors = FALSE)

  expect_error(st_filter(df, list(cuntry = "PER")), "Unknown filter columns")
  expect_warning(
    out <- st_filter(df, list(cuntry = "PER"), strict = FALSE),
    "Ignoring unknown filter column"
  )
  expect_equal(nrow(out), 2L)
})

test_that("st_filter() validates strict rather than coercing it", {
  df <- data.frame(country = "PER", stringsAsFactors = FALSE)

  expect_error(st_filter(df, list(cuntry = "X"), strict = "yes"), "strict")
  expect_error(st_filter(df, list(cuntry = "X"), strict = NA), "strict")
  expect_error(
    st_filter(df, list(cuntry = "X"), strict = c(TRUE, FALSE)),
    "strict"
  )
})
