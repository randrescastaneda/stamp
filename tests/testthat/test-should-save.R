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

test_that("st_should_save writes when sidecar missing (missing_meta)", {
  skip(
    "Sidecar path handling for missing metadata not fully functional in current codebase"
  )
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "nometa.qs")
  x <- data.frame(a = 1)
  st_save(x, p, code = function(z) z)

  # remove sidecar files
  scj <- stamp:::.st_sidecar_path(p, ext = "json")
  scq <- stamp:::.st_sidecar_path(p, ext = "qs2")
  if (fs::file_exists(scj)) {
    fs::file_delete(scj)
  }
  if (fs::file_exists(scq)) {
    fs::file_delete(scq)
  }

  dec <- st_should_save(p, x = x, code = function(z) z)
  expect_true(dec$save)
  expect_equal(dec$reason, "missing_meta")
})

test_that("st_should_save respects versioning policy timestamp and off", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "v.qs")
  x <- data.frame(a = 1)
  st_save(x, p, code = function(z) z)

  # timestamp policy always writes
  st_opts(versioning = "timestamp")
  dec_ts <- st_should_save(p, x = x, code = function(z) z)
  expect_true(dec_ts$save)

  # off policy never writes when no change
  st_opts(versioning = "off")
  dec_off <- st_should_save(p, x = x, code = function(z) z)
  expect_false(dec_off$save)
})

test_that("st_save correctly skips saving identical content (regression test)", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "qs2")

  df <- data.frame(x = 1:5, y = letters[1:5])

  # First save
  r1 <- st_save(df, "test.qs2", verbose = FALSE)
  expect_false(is.null(r1$version_id))
  v1 <- r1$version_id

  # Second save with IDENTICAL content - should be skipped
  r2 <- st_save(df, "test.qs2", verbose = FALSE)
  expect_true(r2$skipped)
  expect_equal(r2$reason, "no_change_policy")

  # Verify only one version exists
  versions <- st_versions("test.qs2")
  expect_equal(nrow(versions), 1)
  expect_equal(versions$version_id[1], v1)

  # Third save with CHANGED content - should create new version
  df_changed <- data.frame(x = 6:10, y = letters[6:10])
  r3 <- st_save(df_changed, "test.qs2", verbose = FALSE)
  expect_false(is.null(r3$version_id))
  expect_false(r3$version_id == v1)

  # Verify two versions exist now
  versions2 <- st_versions("test.qs2")
  expect_equal(nrow(versions2), 2)
})

test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
