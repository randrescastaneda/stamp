# Tests for format handler factory and qs/qs2 separation

test_that(".require_pkg_handler creates valid format handlers", {
  skip_on_cran()

  # Create handler for a hypothetical package
  handler <- stamp:::.require_pkg_handler(
    pkg = "jsonlite",
    read_fn = jsonlite::read_json,
    write_fn = jsonlite::write_json,
    fmt_name = "JSON"
  )

  expect_type(handler, "list")
  expect_true(all(c("read", "write") %in% names(handler)))
  expect_type(handler$read, "closure")
  expect_type(handler$write, "closure")

  # Handler should work when package available
  td <- withr::local_tempdir()
  p <- fs::path(td, "test.json")
  obj <- list(a = 1, b = "test")

  expect_silent(handler$write(obj, p, auto_unbox = TRUE))
  expect_true(fs::file_exists(p))
  result <- handler$read(p, simplifyVector = TRUE)
  expect_equal(result$a, 1)
  expect_equal(result$b, "test")
})

test_that(".require_pkg_handler errors when package missing", {
  skip_on_cran()

  # Create handler for nonexistent package
  handler <- stamp:::.require_pkg_handler(
    pkg = "nonexistent_pkg_xyz",
    read_fn = function(path) readLines(path),
    write_fn = function(x, path) writeLines(x, path),
    fmt_name = "XYZ"
  )

  td <- withr::local_tempdir()
  p <- fs::path(td, "test.xyz")

  # Should abort with informative message
  expect_error(
    handler$write("test", p),
    regexp = "nonexistent_pkg_xyz.*required.*XYZ write"
  )

  # Create dummy file to test read error
  writeLines("test", p)
  expect_error(
    handler$read(p),
    regexp = "nonexistent_pkg_xyz.*required.*XYZ read"
  )
})

test_that(".require_pkg_handler forwards extra args correctly", {
  skip_on_cran()
  skip_if_not_installed("jsonlite")

  # Test: extra args must be supplied at write-time (factory no longer captures ...)
  handler <- stamp:::.require_pkg_handler(
    pkg = "jsonlite",
    read_fn = jsonlite::read_json,
    write_fn = jsonlite::write_json,
    fmt_name = "JSON"
  )

  td <- withr::local_tempdir()
  p <- fs::path(td, "test.json")
  obj <- list(x = c(1, 2, 3), y = "text")

  # Extra args should be passed to write function at call-time
  expect_silent(handler$write(obj, p, auto_unbox = TRUE, digits = NA))
  result <- handler$read(p, simplifyVector = TRUE)
  expect_equal(result$x, c(1, 2, 3))
})

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

  # Test qs format (if available)
  p_qs <- fs::path(td, "test.qs")
  if (requireNamespace("qs", quietly = TRUE)) {
    st_opts(default_format = "qs")
    expect_no_error(suppressMessages(st_save(obj, p_qs, code = function(z) z)))
    expect_true(fs::file_exists(p_qs))
    result_qs <- st_load(p_qs)
    expect_equal(result_qs, obj)
  } else {
    expect_error(
      st_save(obj, p_qs, format = "qs", code = function(z) z),
      regexp = "qs.*required"
    )
  }

  # Test qs2 format (if available)
  p_qs2 <- fs::path(td, "test.qs2")
  if (requireNamespace("qs2", quietly = TRUE)) {
    st_opts(default_format = "qs2")
    expect_no_error(suppressMessages(st_save(obj, p_qs2, code = function(z) z)))
    expect_true(fs::file_exists(p_qs2))
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

  # Should include both qs and qs2
  expect_true("qs" %in% report$ext)
  expect_true("qs2" %in% report$ext)

  # Current should match defaults after .onLoad
  qs_report <- report[report$ext == "qs", ]
  expect_equal(qs_report$default_format, "qs")
  expect_equal(qs_report$current_format, "qs")

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

test_that("st_save infers correct format from .qs vs .qs2 extension", {
  skip_on_cran()
  skip_if_not_installed("qs2")
  skip_if_not_installed("qs")

  td <- withr::local_tempdir()
  st_init(td)

  obj <- data.frame(a = 1:3)

  # Save with .qs extension should use qs format
  p_qs <- fs::path(td, "data.qs")
  st_save(obj, p_qs, code = function(z) z)
  sc_qs <- st_read_sidecar(p_qs)
  expect_equal(sc_qs$format, "qs")

  # Save with .qs2 extension should use qs2 format
  p_qs2 <- fs::path(td, "data.qs2")
  st_save(obj, p_qs2, code = function(z) z)
  sc_qs2 <- st_read_sidecar(p_qs2)
  expect_equal(sc_qs2$format, "qs2")
})

test_that("format registry contains both qs and qs2", {
  skip_on_cran()

  formats <- st_formats()
  expect_true("qs" %in% formats)
  expect_true("qs2" %in% formats)

  # Check internal registry has handlers
  expect_true(rlang::env_has(stamp:::.st_formats_env, "qs"))
  expect_true(rlang::env_has(stamp:::.st_formats_env, "qs2"))

  qs_handler <- rlang::env_get(stamp:::.st_formats_env, "qs")
  qs2_handler <- rlang::env_get(stamp:::.st_formats_env, "qs2")

  expect_true(all(c("read", "write") %in% names(qs_handler)))
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
