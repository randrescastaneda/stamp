test_that("st_save and st_load respect verbose flag", {
  td <- withr::local_tempdir()
  st_init(td)
  tmp <- fs::path(td, "test.rds")

  # Save with verbose = TRUE (should emit message)
  expect_message(
    st_save(mtcars, tmp, format = "rds", verbose = TRUE),
    "Saved \\["
  )

  # Load with verbose = TRUE (should emit message)
  expect_message(
    st_load(tmp, verbose = TRUE),
    "Loaded \\["
  )

  # Save with verbose = FALSE (should be silent for package messages)
  expect_silent(
    st_save(mtcars, tmp, format = "rds", verbose = FALSE)
  )

  # Load with verbose = FALSE (should be silent for package messages)
  expect_silent(
    st_load(tmp, verbose = FALSE)
  )

  # Ensure PK-missing warning is suppressed when verbose = FALSE
  old_warn <- st_opts("warn_missing_pk_on_load", .get = TRUE)
  on.exit(st_opts(warn_missing_pk_on_load = old_warn), add = TRUE)
  st_opts(warn_missing_pk_on_load = TRUE)
  expect_silent({
    st_load(tmp, verbose = FALSE)
  })
})
st_opts(warn_missing_pk_on_load = FALSE)
test_that("st_save and st_load create artifact, sidecar and versions", {
  skip_on_cran()
  skip_if_not_installed("qs2")
  td <- withr::local_tempdir()
  root <- td
  st_init(root)
  st_opts(default_format = "rds")

  p_qs <- fs::path(root, "demo.qs2")
  x <- data.frame(a = 1:3)

  # write and assert artifact + sidecar
  out <- st_save(x, p_qs, code = function(z) z)
  expect_true(fs::file_exists(p_qs))
  sc <- st_read_sidecar(p_qs)
  expect_true(is.list(sc))
  expect_true(nzchar(out$version_id))

  # load and verify content hash matches
  y <- st_load(p_qs)
  expect_equal(y, x)
  expect_equal(st_hash_obj(y), sc$content_hash)

  # rds writer also works via explicit format override
  p_rds <- fs::path(root, "demo.rds")
  out2 <- st_save(x, p_rds, format = "rds", code = function(z) z)
  expect_true(fs::file_exists(p_rds))
  expect_true(nzchar(out2$version_id))
  st_opts(warn_missing_pk_on_load = TRUE)
  st_load(p_rds) |>
    expect_warning(regexp = "No primary key recorded for")
  st_opts(warn_missing_pk_on_load = FALSE)

  y2 <- st_load(p_rds) |>
    suppressWarnings()

  expect_equal(y2, x)
})

test_that("atomic write creates temp then moves into place", {
  skip_on_cran()
  td <- withr::local_tempdir()
  root <- td
  st_init(root)
  st_opts(default_format = "rds")
  p <- fs::path(root, "atomic.qs")
  x <- data.frame(a = 1:2)

  res <- st_save(x, p, code = function(z) z)
  expect_true(fs::file_exists(p))
  # Ensure no lingering .tmp files in same dir
  tmpfiles <- fs::dir_ls(
    fs::path_dir(p),
    glob = "*tmp-*",
    recurse = FALSE,
    fail = FALSE
  )
  expect_true(length(tmpfiles) == 0)
})

test_that("st_register_format registers and st_formats lists it", {
  skip_on_cran()
  # register a trivial text format and ensure it appears
  st_register_format(
    "txt_test",
    read = function(p, ...) readLines(p, ...),
    write = function(x, p, ...) writeLines(as.character(x), p, ...),
    extensions = "txt"
  )
  f <- st_formats()
  expect_true("txt_test" %in% f)
})

test_that("sidecar absent, versions empty, and st_load_version errors when missing", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "missing.qs")
  # no artifact saved yet
  expect_true(!fs::file_exists(p))
  expect_true(nrow(st_versions(p)) == 0)
  expect_true(is.na(st_latest(p)))
  expect_error(st_load_version(p, "nope"))
  expect_null(st_read_sidecar(p))

  # internal helper returns an stmeta path containing the stmeta dir
  sc <- stamp:::.st_sidecar_path(p, ext = "json")
  expect_true(grepl("stmeta", sc))
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
