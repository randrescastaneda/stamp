st_opts(warn_missing_pk_on_load = FALSE)

test_that("st_load with version=NULL loads current artifact", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3, b = letters[1:3])

  st_save(x1, p, code = function() "v1")

  # version=NULL should load current file
  y <- st_load(p, version = NULL)
  expect_equal(y, x1)
})

test_that("st_load with version=0 loads current version", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3, b = letters[1:3])
  x2 <- data.frame(a = 4:6, b = letters[4:6])

  st_save(x1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p, code = function() "v2")

  # version=0 should load latest version
  y <- st_load(p, version = 0)
  expect_equal(y, x2)
})

test_that("st_load with version=-1 loads previous version", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3, b = letters[1:3])
  x2 <- data.frame(a = 4:6, b = letters[4:6])

  st_save(x1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p, code = function() "v2")

  # version=-1 should load the previous version (x1)
  y <- st_load(p, version = -1)
  expect_equal(y, x1)
})

test_that("st_load with version=-2 loads two versions back", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3, b = letters[1:3])
  x2 <- data.frame(a = 4:6, b = letters[4:6])
  x3 <- data.frame(a = 7:9, b = letters[7:9])

  st_save(x1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p, code = function() "v2")
  Sys.sleep(0.1)
  st_save(x3, p, code = function() "v3")

  # version=-2 should load x1 (two versions back from x3)
  y <- st_load(p, version = -2)
  expect_equal(y, x1)
})

test_that("st_load with negative version beyond available throws error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)

  st_save(x1, p, code = function() "v1")

  # Only 1 version exists, -2 should error
  expect_error(
    st_load(p, version = -2),
    regexp = "goes beyond available versions"
  )
})

test_that("st_load with positive version throws error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)

  st_save(x1, p, code = function() "v1")

  # Positive integers not allowed
  expect_error(
    st_load(p, version = 1),
    regexp = "Positive version numbers are not allowed"
  )

  expect_error(
    st_load(p, version = 5),
    regexp = "Positive version numbers are not allowed"
  )
})

test_that("st_load with character version_id loads specific version", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3, b = letters[1:3])
  x2 <- data.frame(a = 4:6, b = letters[4:6])

  out1 <- st_save(x1, p, code = function() "v1")
  vid1 <- out1$version_id
  Sys.sleep(0.1)
  out2 <- st_save(x2, p, code = function() "v2")

  # Load specific version by version_id
  y <- st_load(p, version = vid1)
  expect_equal(y, x1)

  # Current file should be x2
  z <- st_load(p)
  expect_equal(z, x2)
})

test_that("st_load with invalid character version_id throws error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)

  st_save(x1, p, code = function() "v1")

  # Non-existent version_id should error
  expect_error(
    st_load(p, version = "20990101T000000Z-invalid"),
    regexp = "not found"
  )
})

test_that("st_load with version on non-existent artifact throws error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "nonexistent.rds")

  # No versions exist
  expect_error(
    st_load(p, version = -1),
    regexp = "No versions found"
  )

  expect_error(
    st_load(p, version = "fake-version"),
    regexp = "No versions found"
  )
})

test_that("st_load version works with multiple formats", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)

  # Test with .qs format
  p_qs <- fs::path(td, "data.qs")
  x1 <- data.frame(a = 1:3)
  x2 <- data.frame(a = 4:6)

  st_save(x1, p_qs, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p_qs, code = function() "v2")

  y_qs <- st_load(p_qs, version = -1)
  expect_equal(y_qs, x1)

  # Test with .rds format
  p_rds <- fs::path(td, "data.rds")
  st_save(x1, p_rds, format = "rds", code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p_rds, format = "rds", code = function() "v2")

  y_rds <- st_load(p_rds, version = -1)
  expect_equal(y_rds, x1)
})

test_that("st_load version preserves data.table class", {
  skip_on_cran()
  skip_if_not_installed("data.table")

  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "dt.rds")
  dt1 <- data.table::data.table(a = 1:3, b = letters[1:3])
  dt2 <- data.table::data.table(a = 4:6, b = letters[4:6])

  st_save(dt1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(dt2, p, code = function() "v2")

  # Load previous version
  y <- st_load(p, version = -1)
  expect_s3_class(y, "data.table")
  expect_equal(y, dt1)
})

test_that(".st_resolve_version handles all cases correctly", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)
  x2 <- data.frame(a = 4:6)
  x3 <- data.frame(a = 7:9)

  out1 <- st_save(x1, p, code = function() "v1")
  vid1 <- out1$version_id
  Sys.sleep(0.1)
  out2 <- st_save(x2, p, code = function() "v2")
  vid2 <- out2$version_id
  Sys.sleep(0.1)
  out3 <- st_save(x3, p, code = function() "v3")
  vid3 <- out3$version_id

  # NULL -> latest
  resolved_null <- stamp:::.st_resolve_version(p, NULL)
  expect_equal(resolved_null, vid3)

  # 0 -> latest
  resolved_0 <- stamp:::.st_resolve_version(p, 0)
  expect_equal(resolved_0, vid3)

  # -1 -> previous
  resolved_m1 <- stamp:::.st_resolve_version(p, -1)
  expect_equal(resolved_m1, vid2)

  # -2 -> two back
  resolved_m2 <- stamp:::.st_resolve_version(p, -2)
  expect_equal(resolved_m2, vid1)

  # character -> specific version
  resolved_char <- stamp:::.st_resolve_version(p, vid1)
  expect_equal(resolved_char, vid1)

  # positive -> error
  expect_error(
    stamp:::.st_resolve_version(p, 1),
    regexp = "Positive version numbers"
  )

  # beyond range -> error
  expect_error(
    stamp:::.st_resolve_version(p, -10),
    regexp = "goes beyond"
  )

  # invalid version_id -> error
  expect_error(
    stamp:::.st_resolve_version(p, "invalid-id"),
    regexp = "not found"
  )
})

test_that("st_load default behavior unchanged (backward compatibility)", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)
  x2 <- data.frame(a = 4:6)

  st_save(x1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p, code = function() "v2")

  # Default st_load() should load current file (x2)
  y_default <- st_load(p)
  expect_equal(y_default, x2)

  # Explicitly passing version=NULL should be same
  y_null <- st_load(p, version = NULL)
  expect_equal(y_null, x2)

  # Both should be identical
  expect_identical(y_default, y_null)
})

test_that("st_load with version='select' in non-interactive session throws error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)

  st_save(x1, p, code = function() "v1")

  # In non-interactive session, should error
  expect_error(
    st_load(p, version = "select"),
    regexp = "not interactive"
  )

  # Same for "pick"
  expect_error(
    st_load(p, version = "pick"),
    regexp = "not interactive"
  )

  # Same for "choose"
  expect_error(
    st_load(p, version = "choose"),
    regexp = "not interactive"
  )
})

test_that(".st_resolve_version with 'select' keyword detects non-interactive", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)
  x2 <- data.frame(a = 4:6)

  st_save(x1, p, code = function() "v1")
  Sys.sleep(0.1)
  st_save(x2, p, code = function() "v2")

  # All three keywords should error in non-interactive mode
  expect_error(
    stamp:::.st_resolve_version(p, "select"),
    regexp = "not interactive"
  )

  expect_error(
    stamp:::.st_resolve_version(p, "pick"),
    regexp = "not interactive"
  )

  expect_error(
    stamp:::.st_resolve_version(p, "choose"),
    regexp = "not interactive"
  )
})

test_that("interactive menu help text updated in error messages", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "data.rds")
  x1 <- data.frame(a = 1:3)

  st_save(x1, p, code = function() "v1")

  # Error message should mention 'select' option
  expect_error(
    st_load(p, version = "nonexistent-version-id"),
    regexp = "select"
  )
})
