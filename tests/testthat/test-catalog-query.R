# Tests for st_catalog_query() ------------------------------------------------

# Helper: initialise a named temp alias and clean up after the test
local_alias <- function(name, env = parent.frame()) {
  td <- withr::local_tempdir(.local_envir = env)
  st_init(td, alias = name, verbose = FALSE)
  withr::defer(rlang::env_unbind(stamp:::.stamp_aliases, name), envir = env)
  td
}

# --- Empty catalog ------------------------------------------------------------

test_that("empty alias returns zero-row data.table with correct schema", {
  local_alias("cq_empty")

  result <- st_catalog_query(alias = "cq_empty")

  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 0L)
  expect_named(
    result,
    c(
      "path",
      "version_id",
      "content_hash",
      "code_hash",
      "size_bytes",
      "created_at"
    )
  )
  expect_type(result$path, "character")
  expect_type(result$version_id, "character")
  expect_type(result$content_hash, "character")
  expect_type(result$code_hash, "character")
  expect_type(result$size_bytes, "double")
  expect_type(result$created_at, "character")
})

# --- Happy path: multiple artifacts -------------------------------------------

test_that("three distinct artifacts each yield exactly one row", {
  td <- local_alias("cq_three")

  p1 <- fs::path(td, "art1.rds")
  p2 <- fs::path(td, "art2.rds")
  p3 <- fs::path(td, "art3.rds")
  st_save(list(x = 1L), p1, format = "rds", verbose = FALSE)
  st_save(list(x = 2L), p2, format = "rds", verbose = FALSE)
  st_save(list(x = 3L), p3, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = "cq_three")

  expect_equal(nrow(result), 3L)
  expect_named(
    result,
    c(
      "path",
      "version_id",
      "content_hash",
      "code_hash",
      "size_bytes",
      "created_at"
    )
  )
})

# --- Multiple versions: only latest returned ----------------------------------

test_that("artifact saved twice yields one row with the latest version_id", {
  td <- local_alias("cq_versions")

  p <- fs::path(td, "evolving.rds")
  st_save(list(v = 1L), p, format = "rds", verbose = FALSE)
  first_vid <- st_catalog_query(alias = "cq_versions")$version_id

  st_save(list(v = 2L), p, format = "rds", verbose = FALSE)
  result <- st_catalog_query(alias = "cq_versions")

  # Still one row for this artifact
  expect_equal(nrow(result), 1L)
  # version_id has changed to the newer save
  expect_false(result$version_id == first_vid)
})

test_that("join returns nrow(artifacts) rows, not nrow(versions)", {
  td <- local_alias("cq_join_count")

  p1 <- fs::path(td, "a.rds")
  p2 <- fs::path(td, "b.rds")
  # p1 saved twice → 2 version rows; p2 saved once → 1 version row
  # total version rows = 3, artifact rows = 2 → result must be 2
  st_save(list(v = 1L), p1, format = "rds", verbose = FALSE)
  st_save(list(v = 2L), p1, format = "rds", verbose = FALSE)
  st_save(list(v = 1L), p2, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = "cq_join_count")

  expect_equal(nrow(result), 2L)
})

# --- code_hash column present -------------------------------------------------

test_that("result includes code_hash column", {
  td <- local_alias("cq_code_hash")

  p <- fs::path(td, "item.rds")
  st_save(mtcars, p, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = "cq_code_hash")

  expect_true("code_hash" %in% names(result))
})

# --- content_hash present and non-NA -----------------------------------------

test_that("content_hash is populated for a saved artifact", {
  td <- local_alias("cq_content_hash")

  p <- fs::path(td, "item.rds")
  st_save(mtcars, p, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = "cq_content_hash")

  # content_hash should be a non-empty string (actual hash value)
  expect_true(nchar(result$content_hash) > 0L)
})

# --- path column matches actual file path ------------------------------------

test_that("path column matches the saved artifact path", {
  td <- local_alias("cq_path")

  p <- fs::path(td, "my_data.rds")
  st_save(list(a = 42L), p, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = "cq_path")

  # Compare case-insensitively: on Windows paths are stored normalised to
  # lowercase while withr::local_tempdir() may return mixed-case paths.
  expect_equal(tolower(fs::path_norm(result$path)), tolower(fs::path_norm(p)))
})

# --- NULL alias uses default alias -------------------------------------------

test_that("NULL alias queries the default alias without error", {
  td <- withr::local_tempdir()
  withr::defer(st_init(withr::local_tempdir(), verbose = FALSE)) # restore default
  st_init(td, verbose = FALSE) # set default alias to td

  p <- fs::path(td, "default_art.rds")
  st_save(list(z = 99L), p, format = "rds", verbose = FALSE)

  result <- st_catalog_query(alias = NULL)

  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 1L)
})

# --- Uninitialised alias errors -----------------------------------------------

test_that("querying an uninitialised alias propagates an error", {
  expect_error(st_catalog_query(alias = "cq_does_not_exist_xyz"))
})
