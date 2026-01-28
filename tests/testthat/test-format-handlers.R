# Tests for format handlers and qs/qs2 separation

test_that("qs2 handlers require qs2 package strictly (no fallback)", {
  skip_on_cran()

  # Test internal qs2 write/read functions
  td <- withr::local_tempdir()
  p <- fs::path(td, "test.qs2")
  obj <- data.frame(a = 1:3, b = letters[1:3])

  if (!requireNamespace("qs2", quietly = TRUE)) {
    # When qs2 missing, both functions should abort
    expect_error(
      stamp:::.st_write_qs2(obj, p),
      regexp = "qs2.*required.*qs2 format"
    )

    # Create dummy file to test read
    saveRDS(obj, p)
    expect_error(
      stamp:::.st_read_qs2(p),
      regexp = "qs2.*required.*qs2 format"
    )
  } else {
    # When qs2 available, should work normally
    expect_silent(stamp:::.st_write_qs2(obj, p))
    expect_true(fs::file_exists(p))
    result <- stamp:::.st_read_qs2(p)
    expect_equal(result, obj)
  }
})

test_that("qs and qs2 format handlers are independent", {
  skip_on_cran()

  td <- withr::local_tempdir()
  st_init(td)

  obj <- data.frame(x = 1:5, y = LETTERS[1:5])

  # Test qs2 format (if available)
  p_qs2 <- fs::path(td, "test.qs2")
  if (requireNamespace("qs2", quietly = TRUE)) {
    st_opts(default_format = "qs2")
    expect_no_error(suppressMessages(st_save(obj, p_qs2, code = function(z) z)))
    # Check file exists in new storage location
    storage_path_qs2 <- fs::path(td, "test.qs2", "test.qs2")
    expect_true(fs::file_exists(storage_path_qs2))
    result_qs2 <- st_load(p_qs2)
    expect_equal(result_qs2, obj)
  } else {
    expect_error(
      st_save(obj, p_qs2, format = "qs2", code = function(z) z),
      regexp = "qs2.*required"
    )
  }
})

test_that("st_extmap_report shows current vs default mappings", {
  skip_on_cran()

  report <- st_extmap_report()
  expect_true(is.data.frame(report))
  expect_true(all(
    c("ext", "default_format", "current_format", "desc") %in% names(report)
  ))

  # Should include qs2 only (qs has been removed)
  expect_true("qs2" %in% report$ext)

  qs2_report <- report[report$ext == "qs2", ]
  expect_equal(qs2_report$default_format, "qs2")
  expect_equal(qs2_report$current_format, "qs2")
})

test_that(".seed_extmap is idempotent", {
  skip_on_cran()

  # Get initial state
  report1 <- st_extmap_report()

  # Call seed again (should not change anything)
  stamp:::.seed_extmap()
  report2 <- st_extmap_report()

  # Should be identical
  expect_equal(report1, report2)
})

test_that("st_save infers qs2 format from .qs extension and qs2 from .qs2", {
  skip_on_cran()
  skip_if_not_installed("qs2")
  skip_if_not_installed("qs")

  td <- withr::local_tempdir()
  st_init(td)

  obj <- data.frame(a = 1:3)

  # Save with .qs extension should use qs2 format (default after qs removal)
  p_qs <- fs::path(td, "data.qs")
  st_save(obj, p_qs, code = function(z) z)
  sc_qs <- st_read_sidecar(p_qs)
  expect_equal(sc_qs$format, "qs2")

  # Save with .qs2 extension should use qs2 format
  p_qs2 <- fs::path(td, "data.qs2")
  st_save(obj, p_qs2, code = function(z) z)
  sc_qs2 <- st_read_sidecar(p_qs2)
  expect_equal(sc_qs2$format, "qs2")
})

test_that("format registry contains qs2", {
  skip_on_cran()

  formats <- st_formats()
  expect_true("qs2" %in% formats)

  # Check internal registry has handlers
  expect_true(rlang::env_has(stamp:::.st_formats_env, "qs2"))

  qs2_handler <- rlang::env_get(stamp:::.st_formats_env, "qs2")

  expect_true(all(c("read", "write") %in% names(qs2_handler)))
})

test_that("custom format registration via st_register_format still works", {
  skip_on_cran()

  td <- withr::local_tempdir()
  st_init(td)

  # Register custom format
  st_register_format(
    name = "custom_txt",
    read = function(path, ...) {
      lines <- readLines(path, ...)
      as.numeric(lines)
    },
    write = function(x, path, ...) {
      writeLines(as.character(x), path, ...)
    },
    extensions = c("txt", "ctxt")
  )

  expect_true("custom_txt" %in% st_formats())

  # Test it works
  obj <- c(1, 2, 3)
  p <- fs::path(td, "test.ctxt")
  st_save(obj, p, format = "custom_txt", code = function(z) z)
  result <- st_load(p)
  expect_equal(result, obj)
})
