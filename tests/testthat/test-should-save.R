test_that("st_should_save skips when content and code unchanged", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "s.qs")
  x <- data.frame(a = 1:3)

  st_save(x, p, code = function(z) z)
  # same content and same code => skip
  dec <- st_should_save(p, x = x, code = function(z) z)
  expect_false(dec$save)
  expect_match(dec$reason, "no_change|no_change_policy")
})

test_that("st_should_save writes when content or code changed", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "s2.qs")
  x <- data.frame(a = 1:3)
  st_save(x, p, code = function(z) z)

  x2 <- transform(x, a = a + 1L)
  dec2 <- st_should_save(p, x = x2, code = function(z) z)
  expect_true(dec2$save)
  expect_match(dec2$reason, "content")

  # same content but different code
  dec3 <- st_should_save(p, x = x, code = function(y) y + 0)
  # Likely code change triggers save
  expect_true(dec3$save)
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
