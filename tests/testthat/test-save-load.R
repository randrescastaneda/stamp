test_that("st_init respects verbose flag", {
  td1 <- withr::local_tempdir()
  td2 <- withr::local_tempdir()

  # verbose = TRUE (default) emits the "stamp initialized" message
  expect_message(st_init(td1, verbose = TRUE), "stamp initialized")

  # verbose = FALSE is fully silent — no messages, no warnings
  expect_silent(st_init(td2, verbose = FALSE))

  # alias-rebase scenario: reinitialising the "default" alias to a new folder
  # emits a rebasing inform when verbose = TRUE
  td3 <- withr::local_tempdir()
  expect_message(st_init(td3, verbose = TRUE), "Rebasing default alias")

  # same rebase scenario is silent when verbose = FALSE
  td4 <- withr::local_tempdir()
  expect_silent(st_init(td4, verbose = FALSE))

  # duplicate-alias scenario: two aliases pointing to same folder warns verbose=TRUE
  td5 <- withr::local_tempdir()
  # Clean up named aliases after the test so they don't persist across runs
  withr::defer(rlang::env_unbind(stamp:::.stamp_aliases, c("dup_a", "dup_b", "dup_c")))
  st_init(td5, alias = "dup_a", verbose = FALSE)
  expect_warning(st_init(td5, alias = "dup_b", verbose = TRUE), "same folder")

  # same scenario is silent when verbose = FALSE
  expect_silent(st_init(td5, alias = "dup_c", verbose = FALSE))

  # invalid verbose values must error (validation is tested)
  td6 <- withr::local_tempdir()
  expect_error(st_init(td6, verbose = NA))
  expect_error(st_init(td6, verbose = "yes"))
})

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
  # Check file exists in new storage location
  storage_path <- fs::path(root, "demo.qs2", "demo.qs2")
  expect_true(fs::file_exists(storage_path))
  sc <- st_read_sidecar(p_qs)
  expect_true(is.list(sc))
  expect_true(nzchar(out$version_id))

  st_opts(warn_missing_pk_on_load = FALSE)
  # load and verify content hash matches
  y <- st_load(p_qs)
  expect_equal(y, x)
  expect_equal(st_hash_obj(y), sc$content_hash)

  # rds writer also works via explicit format override
  p_rds <- fs::path(root, "demo.rds")
  out2 <- st_save(x, p_rds, format = "rds", code = function(z) z)
  # Check RDS file exists in new storage location
  storage_path_rds <- fs::path(root, "demo.rds", "demo.rds")
  expect_true(fs::file_exists(storage_path_rds))
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
  # Check file exists in new storage location
  storage_path <- fs::path(root, "atomic.qs", "atomic.qs")
  expect_true(fs::file_exists(storage_path))
  # Ensure no lingering .tmp files in storage dir
  tmpfiles <- fs::dir_ls(
    fs::path_dir(storage_path),
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
