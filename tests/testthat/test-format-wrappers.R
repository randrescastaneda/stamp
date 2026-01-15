test_that(".st_wrap_reader adds verbose parameter", {
  # Create a mock reader that would normally produce a warning
  mock_reader <- function(path, ...) {
    warning("Mock reader warning")
    readRDS(path, ...)
  }

  # Wrap it
  wrapped <- stamp:::.st_wrap_reader(mock_reader)

  # Check the wrapped function has verbose parameter
  params <- names(formals(wrapped))
  expect_true("verbose" %in% params)
  expect_true("path" %in% params)
  expect_true("..." %in% params)

  # Test with verbose = TRUE (warnings should appear)
  td <- withr::local_tempdir()
  test_file <- file.path(td, "test.rds")
  saveRDS(mtcars, test_file)

  expect_warning(
    wrapped(test_file, verbose = TRUE),
    "Mock reader warning"
  )

  # Test with verbose = FALSE (warnings should be suppressed)
  expect_silent(
    result <- wrapped(test_file, verbose = FALSE)
  )

  # Result should still be correct
  expect_equal(result, mtcars)
})

test_that(".st_wrap_writer adds verbose parameter", {
  # Create a mock writer that would normally produce a warning
  mock_writer <- function(x, path, ...) {
    warning("Mock writer warning")
    saveRDS(x, path, ...)
  }

  # Wrap it
  wrapped <- stamp:::.st_wrap_writer(mock_writer)

  # Check the wrapped function has verbose parameter
  params <- names(formals(wrapped))
  expect_true("verbose" %in% params)
  expect_true("x" %in% params)
  expect_true("path" %in% params)
  expect_true("..." %in% params)

  # Test with verbose = TRUE (warnings should appear)
  td <- withr::local_tempdir()
  test_file <- file.path(td, "test.rds")

  expect_warning(
    wrapped(mtcars, test_file, verbose = TRUE),
    "Mock writer warning"
  )

  # Test with verbose = FALSE (warnings should be suppressed)
  expect_silent(
    wrapped(iris, test_file, verbose = FALSE)
  )

  # File should still be written correctly
  expect_true(file.exists(test_file))
  result <- readRDS(test_file)
  expect_equal(result, iris)
})

test_that("registered format handlers have verbose parameter", {
  # Get a registered handler (e.g., rds)
  rds_handler <- rlang::env_get(stamp:::.st_formats_env, "rds")

  # Check read handler has verbose
  read_params <- names(formals(rds_handler$read))
  expect_true("verbose" %in% read_params)
  expect_true("path" %in% read_params)

  # Check write handler has verbose
  write_params <- names(formals(rds_handler$write))
  expect_true("verbose" %in% write_params)
  expect_true("x" %in% write_params)
  expect_true("path" %in% write_params)
})

test_that("verbose parameter works end-to-end with st_save/st_load", {
  td <- withr::local_tempdir()
  st_init(td)
  test_file <- file.path(td, "test.rds")

  # Save with verbose = FALSE should be silent for stamp messages
  expect_silent(
    st_save(mtcars, test_file, verbose = FALSE)
  )

  expect_true(file.exists(test_file))

  # Load with verbose = FALSE should be silent for stamp messages
  expect_silent(
    result <- st_load(test_file, verbose = FALSE)
  )

  # Compare content only (ignore attributes like row.names)
  expect_equal(result, mtcars, ignore_attr = TRUE)
})

test_that("custom registered formats get wrapped with verbose", {
  # Register a custom format with a noisy reader/writer
  noisy_read <- function(path, ...) {
    warning("Noisy read warning")
    readLines(path, warn = FALSE, ...)
  }

  noisy_write <- function(x, path, ...) {
    warning("Noisy write warning")
    writeLines(as.character(x), path, ...)
  }

  # Register the format (wrapper is applied internally)
  suppressMessages(
    st_register_format(
      "noisytxt",
      read = noisy_read,
      write = noisy_write,
      extensions = "ntxt"
    )
  )

  # Get the registered handler
  handler <- rlang::env_get(stamp:::.st_formats_env, "noisytxt")

  # Verify it has verbose parameter
  expect_true("verbose" %in% names(formals(handler$read)))
  expect_true("verbose" %in% names(formals(handler$write)))

  # Test it suppresses warnings when verbose = FALSE
  td <- withr::local_tempdir()
  test_file <- file.path(td, "test.ntxt")

  # Write should warn with verbose = TRUE
  expect_warning(
    handler$write(c("line1", "line2"), test_file, verbose = TRUE),
    "Noisy write warning"
  )

  # Write should be silent with verbose = FALSE
  expect_silent(
    handler$write(c("line3", "line4"), test_file, verbose = FALSE)
  )

  # Read should warn with verbose = TRUE
  expect_warning(
    handler$read(test_file, verbose = TRUE),
    "Noisy read warning"
  )

  # Read should be silent with verbose = FALSE
  expect_silent(
    result <- handler$read(test_file, verbose = FALSE)
  )

  expect_equal(result, c("line3", "line4"))
})
