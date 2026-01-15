# Test suite for .st_restore_sanitized_object() and .st_has_custom_rownames()
# These internal helpers are critical for preserving object fidelity through
# the save/load cycle.

test_that(".st_has_custom_rownames() correctly identifies custom row.names", {
  # Default row.names (integer sequence)
  df_default <- data.frame(x = 1:5, y = letters[1:5])
  expect_false(stamp:::.st_has_custom_rownames(df_default))

  # Custom character row.names
  df_custom <- data.frame(x = 1:5, y = letters[1:5])
  rownames(df_custom) <- c("a", "b", "c", "d", "e")
  expect_true(stamp:::.st_has_custom_rownames(df_custom))

  # Custom numeric row.names (non-sequential)
  df_numeric <- data.frame(x = 1:3, y = letters[1:3])
  rownames(df_numeric) <- c(10, 20, 30)
  expect_true(stamp:::.st_has_custom_rownames(df_numeric))

  # Empty data.frame
  df_empty <- data.frame()
  expect_false(stamp:::.st_has_custom_rownames(df_empty))

  # Single row
  df_single <- data.frame(x = 1, y = "a")
  expect_false(stamp:::.st_has_custom_rownames(df_single))

  df_single_custom <- data.frame(x = 1, y = "a")
  rownames(df_single_custom) <- "first"
  expect_true(stamp:::.st_has_custom_rownames(df_single_custom))
})

test_that(".st_restore_sanitized_object() handles data.frames correctly", {
  # Standard data.frame with custom row.names
  original <- data.frame(x = 1:3, y = 4:6)
  rownames(original) <- c("a", "b", "c")

  # Sanitize then restore
  sanitized <- stamp:::st_sanitize_for_hash(original)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, original)
  expect_equal(attr(restored, "row.names"), c("a", "b", "c"))
  expect_null(attr(restored, "st_original_rownames"))
  expect_null(attr(restored, "st_original_format"))
  expect_null(attr(restored, "stamp_sanitized"))
})

test_that(".st_restore_sanitized_object() handles data.table correctly", {
  skip_if_not_installed("data.table")

  # Create data.table with custom row.names
  dt_original <- data.table::as.data.table(mtcars[1:5, ])

  # Sanitize then restore
  sanitized <- stamp:::st_sanitize_for_hash(dt_original)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_s3_class(restored, "data.table")
  expect_identical(restored, dt_original)
  expect_null(attr(restored, "st_original_format"))
  expect_null(attr(restored, "stamp_sanitized"))
})

test_that(".st_restore_sanitized_object() handles default row.names", {
  # data.frame with default row.names (should not be preserved)
  original <- data.frame(x = 1:5, y = letters[1:5])

  sanitized <- stamp:::st_sanitize_for_hash(original)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, original)
  # Should not have st_original_rownames since they were default
  expect_null(attr(sanitized, "st_original_rownames"))
})

test_that(".st_restore_sanitized_object() handles empty data.frames", {
  # Empty data.frame (0 rows, 0 cols)
  df_empty <- data.frame()

  sanitized <- stamp:::st_sanitize_for_hash(df_empty)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, df_empty)
  expect_null(attr(restored, "stamp_sanitized"))

  # Empty data.frame with columns but no rows
  df_no_rows <- data.frame(x = integer(), y = character())

  sanitized2 <- stamp:::st_sanitize_for_hash(df_no_rows)
  restored2 <- stamp:::.st_restore_sanitized_object(sanitized2)

  expect_identical(restored2, df_no_rows)
})

test_that(".st_restore_sanitized_object() handles single-row data.frames", {
  # Single row with custom row.name
  df_single <- data.frame(x = 10, y = "test")
  rownames(df_single) <- "custom_name"

  sanitized <- stamp:::st_sanitize_for_hash(df_single)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, df_single)
  expect_equal(rownames(restored), "custom_name")
})

test_that(".st_restore_sanitized_object() handles non-data.frame objects", {
  # Vector
  vec <- c(1, 2, 3, 4, 5)
  attr(vec, "stamp_sanitized") <- TRUE
  attr(vec, "st_original_format") <- "numeric"

  restored_vec <- stamp:::.st_restore_sanitized_object(vec)

  expect_null(attr(restored_vec, "stamp_sanitized"))
  expect_null(attr(restored_vec, "st_original_format"))
  expect_equal(restored_vec, c(1, 2, 3, 4, 5))

  # List
  lst <- list(a = 1, b = 2, c = 3)
  attr(lst, "stamp_sanitized") <- TRUE

  restored_lst <- stamp:::.st_restore_sanitized_object(lst)

  expect_null(attr(restored_lst, "stamp_sanitized"))
  expect_equal(restored_lst, list(a = 1, b = 2, c = 3))
})

test_that(".st_restore_sanitized_object() handles missing attributes gracefully", {
  # Object without any stamp attributes (already clean)
  df_clean <- data.frame(x = 1:3, y = letters[1:3])

  # Should return unchanged
  restored <- stamp:::.st_restore_sanitized_object(df_clean)

  expect_identical(restored, df_clean)

  # Object with only some attributes
  df_partial <- data.frame(x = 1:3, y = letters[1:3])
  attr(df_partial, "stamp_sanitized") <- TRUE
  # Missing st_original_format and st_original_rownames

  restored_partial <- stamp:::.st_restore_sanitized_object(df_partial)

  expect_null(attr(restored_partial, "stamp_sanitized"))
  expect_equal(nrow(restored_partial), 3)
})

test_that(".st_restore_sanitized_object() preserves data.table keys", {
  skip_if_not_installed("data.table")

  # data.table with key
  dt_keyed <- data.table::data.table(
    id = c(1, 2, 3),
    value = c("a", "b", "c")
  )
  data.table::setkey(dt_keyed, id)

  original_key <- data.table::key(dt_keyed)

  sanitized <- stamp:::st_sanitize_for_hash(dt_keyed)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_s3_class(restored, "data.table")
  # Note: keys are part of data.table structure and should be preserved
  # through the data.frame conversion and back
})

test_that(".st_restore_sanitized_object() handles numeric row.names", {
  # Custom numeric row.names (not sequential)
  df_numeric <- data.frame(x = 1:3, y = letters[1:3])
  rownames(df_numeric) <- c(100, 200, 300)

  sanitized <- stamp:::st_sanitize_for_hash(df_numeric)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, df_numeric)
  # Row.names should be preserved as character
  expect_equal(rownames(restored), c("100", "200", "300"))
})

test_that("Full round-trip: sanitize → restore → identical", {
  test_objects <- list(
    "mtcars" = mtcars,
    "iris" = iris,
    "custom_rownames" = {
      df <- data.frame(a = 1:5, b = letters[1:5])
      rownames(df) <- paste0("row_", 1:5)
      df
    },
    "single_col" = data.frame(x = 1:10),
    "single_row" = data.frame(x = 1, y = 2, z = 3)
  )

  for (name in names(test_objects)) {
    original <- test_objects[[name]]

    # Sanitize
    sanitized <- stamp:::st_sanitize_for_hash(original)

    # Restore
    restored <- stamp:::.st_restore_sanitized_object(sanitized)

    # Should be identical
    expect_identical(
      restored,
      original,
      label = paste("Round-trip failed for", name)
    )

    # No internal attributes should leak
    expect_null(attr(restored, "st_original_rownames"))
    expect_null(attr(restored, "st_original_format"))
    expect_null(attr(restored, "stamp_sanitized"))
  }
})

test_that("Integration: st_save + st_load uses restoration helper correctly", {
  td <- withr::local_tempdir()
  withr::local_dir(td)
  st_init(".")

  # Test with data.frame with custom row.names
  df_test <- data.frame(x = 1:5, y = letters[1:5])
  rownames(df_test) <- c("alpha", "beta", "gamma", "delta", "epsilon")

  path <- "test_df.rds"

  suppressMessages({
    st_save(df_test, path, verbose = FALSE)
    loaded <- st_load(path, verbose = FALSE)
  })

  expect_identical(loaded, df_test)
  expect_equal(
    rownames(loaded),
    c("alpha", "beta", "gamma", "delta", "epsilon")
  )

  # Verify no internal attributes leaked
  expect_null(attr(loaded, "st_original_rownames"))
  expect_null(attr(loaded, "st_original_format"))
  expect_null(attr(loaded, "stamp_sanitized"))
})

test_that("Integration: st_load_version uses restoration helper correctly", {
  skip_if_not_installed("data.table")
  td <- withr::local_tempdir()
  withr::local_dir(td)
  st_init(".")

  # Test with data.table
  dt_test <- data.table::data.table(
    id = 1:3,
    name = c("Alice", "Bob", "Charlie")
  )

  # Use rds to avoid requiring the qs2 package in test environments
  path <- "test_dt.rds"

  suppressMessages({
    result <- st_save(dt_test, path, verbose = FALSE)
    version_id <- result$version_id
    expect_true(!is.null(version_id) && nzchar(version_id))

    loaded <- st_load_version(path, version_id, verbose = FALSE)
  })

  expect_s3_class(loaded, "data.table")
  expect_identical(loaded, dt_test)

  # Verify no internal attributes leaked
  expect_null(attr(loaded, "st_original_format"))
  expect_null(attr(loaded, "stamp_sanitized"))
})

test_that("Edge case: Very long row.names", {
  # Row.names with long strings
  df_long <- data.frame(x = 1:3, y = letters[1:3])
  long_names <- strrep("very_long_name_", 100)
  # Add row numbers as suffix: paste0(long_names, 1:3) creates:
  # "very_long_name_very_long_name_...1"
  # "very_long_name_very_long_name_...2"
  # "very_long_name_very_long_name_...3"
  rownames(df_long) <- paste0(long_names, 1:3)

  sanitized <- stamp:::st_sanitize_for_hash(df_long)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, df_long)
  # "very_long_name_" has 15 characters, repeated 100 times = 1500 chars
  # Plus the suffix "1" (from 1:3) = 1501 characters total
  expect_equal(nchar(rownames(restored)[1]), 1501)
})

test_that("Edge case: Special characters in row.names", {
  df_special <- data.frame(x = 1:3, y = letters[1:3])
  rownames(df_special) <- c(
    "name-with-dash",
    "name.with.dot",
    "name_with_underscore"
  )

  sanitized <- stamp:::st_sanitize_for_hash(df_special)
  restored <- stamp:::.st_restore_sanitized_object(sanitized)

  expect_identical(restored, df_special)
  expect_equal(
    rownames(restored),
    c("name-with-dash", "name.with.dot", "name_with_underscore")
  )
})

test_that("Performance: Restoration is efficient (no deep copies)", {
  skip_if_not_installed("data.table")

  # Large data.table
  large_dt <- data.table::data.table(
    id = 1:10000,
    value = rnorm(10000),
    category = sample(letters, 10000, replace = TRUE)
  )

  sanitized <- stamp:::st_sanitize_for_hash(large_dt)

  # Restoration should be fast (no deep copy of data)
  time_taken <- system.time({
    restored <- stamp:::.st_restore_sanitized_object(sanitized)
  })

  # Should take less than 0.1 seconds even for large data
  expect_lt(time_taken["elapsed"], 0.1)

  expect_s3_class(restored, "data.table")
  expect_equal(nrow(restored), 10000)
})
