# Helper function for test setup (DRY principle)
setup_stamp_test <- function() {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)
  stamp::st_init()
  invisible(test_proj)
}

test_that("st_restore restores to previous version", {
  setup_stamp_test()

  # Create and save initial version
  data_v1 <- data.frame(x = 1:5, y = letters[1:5])
  stamp::st_save(data_v1, "test.qs2", verbose = FALSE)

  # Modify and save second version
  data_v2 <- data.frame(x = 1:5, y = letters[6:10])
  stamp::st_save(data_v2, "test.qs2", verbose = FALSE)

  # Verify we have 2 versions
  versions <- stamp::st_versions("test.qs2")
  expect_equal(nrow(versions), 2)

  # Restore to first version
  stamp::st_restore("test.qs2", version = "oldest", verbose = FALSE)

  # Load and verify it's the first version
  restored <- stamp::st_load("test.qs2", verbose = FALSE)
  expect_identical(restored, data_v1)
})

test_that("st_restore works with subdirectories", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create and save in subdirectory
  data_v1 <- data.frame(a = 1:3)
  stamp::st_save(data_v1, "subdir/nested.qs2", verbose = FALSE)

  # Modify and save
  data_v2 <- data.frame(a = 4:6)
  stamp::st_save(data_v2, "subdir/nested.qs2", verbose = FALSE)

  # Restore to first version
  stamp::st_restore("subdir/nested.qs2", version = "oldest", verbose = FALSE)

  # Verify restoration
  restored <- stamp::st_load("subdir/nested.qs2", verbose = FALSE)
  expect_identical(restored, data_v1)
})

test_that("st_restore works with absolute paths", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  abs_path <- file.path(test_proj, "absolute.qs2")

  # Create versions
  data_v1 <- data.frame(z = 1:3)
  stamp::st_save(data_v1, abs_path, verbose = FALSE)

  data_v2 <- data.frame(z = 7:9)
  stamp::st_save(data_v2, abs_path, verbose = FALSE)

  # Restore
  stamp::st_restore(abs_path, version = "oldest", verbose = FALSE)

  # Verify
  restored <- stamp::st_load(abs_path, verbose = FALSE)
  expect_identical(restored, data_v1)
})

test_that("st_restore errors when no versions exist", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Try to restore non-existent artifact
  expect_error(
    stamp::st_restore("nonexistent.qs2", verbose = FALSE),
    "No versions found"
  )
})

test_that("st_restore errors with invalid version ID", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  data_v1 <- data.frame(x = 1:3)
  stamp::st_save(data_v1, "test.qs2", verbose = FALSE)

  # Try to restore with fake version ID
  expect_error(
    stamp::st_restore("test.qs2", version = "fake_version_id", verbose = FALSE),
    "version.*not found|invalid version"
  )
})

test_that("st_restore to 'latest' works", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create multiple versions
  data_v1 <- data.frame(x = 1:5)
  stamp::st_save(data_v1, "test.qs2", verbose = FALSE)

  data_v2 <- data.frame(x = 6:10)
  stamp::st_save(data_v2, "test.qs2", verbose = FALSE)

  data_v3 <- data.frame(x = 11:15)
  stamp::st_save(data_v3, "test.qs2", verbose = FALSE)

  # Restore to latest (should be v3)
  stamp::st_restore("test.qs2", version = "latest", verbose = FALSE)

  restored <- stamp::st_load("test.qs2", verbose = FALSE)
  expect_identical(restored, data_v3)
})

test_that("st_restore by specific version_id works", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create multiple versions
  data_v1 <- data.frame(x = 1:5)
  stamp::st_save(data_v1, "test.qs2", verbose = FALSE)

  data_v2 <- data.frame(x = 6:10)
  stamp::st_save(data_v2, "test.qs2", verbose = FALSE)

  data_v3 <- data.frame(x = 11:15)
  stamp::st_save(data_v3, "test.qs2", verbose = FALSE)

  # Get version IDs
  versions <- stamp::st_versions("test.qs2")
  middle_version_id <- versions$version_id[2] # Get middle version

  # Restore to middle version
  stamp::st_restore("test.qs2", version = middle_version_id, verbose = FALSE)

  restored <- stamp::st_load("test.qs2", verbose = FALSE)
  expect_identical(restored, data_v2)
})

test_that("st_restore works with different formats", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Test with RDS format
  data_v1 <- data.frame(x = 1:5)
  stamp::st_save(data_v1, "test.rds", verbose = FALSE)

  data_v2 <- data.frame(x = 6:10)
  stamp::st_save(data_v2, "test.rds", verbose = FALSE)

  stamp::st_restore("test.rds", version = "oldest", verbose = FALSE)

  restored <- stamp::st_load("test.rds", verbose = FALSE)
  expect_identical(restored, data_v1)
})

test_that("st_restore handles unsaved changes correctly", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Save initial version
  data_v1 <- data.frame(x = 1:5)
  stamp::st_save(data_v1, "test.qs2", verbose = FALSE)

  # Modify and save
  data_v2 <- data.frame(x = 6:10)
  stamp::st_save(data_v2, "test.qs2", verbose = FALSE)

  # Manually modify the file without saving to stamp
  data_v3 <- data.frame(x = 11:15)
  qs2::qs_save(data_v3, file.path(".st_data", "test.qs2", "test.qs2"))

  # Restore should overwrite unsaved changes
  stamp::st_restore("test.qs2", version = "oldest", verbose = FALSE)

  restored <- stamp::st_load("test.qs2", verbose = FALSE)
  expect_identical(restored, data_v1)
})

test_that("st_restore with multiple files doesn't cross-contaminate", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create versions for file A
  data_a1 <- data.frame(a = 1:3)
  stamp::st_save(data_a1, "fileA.qs2", verbose = FALSE)
  data_a2 <- data.frame(a = 4:6)
  stamp::st_save(data_a2, "fileA.qs2", verbose = FALSE)

  # Create versions for file B
  data_b1 <- data.frame(b = 10:12)
  stamp::st_save(data_b1, "fileB.qs2", verbose = FALSE)
  data_b2 <- data.frame(b = 20:22)
  stamp::st_save(data_b2, "fileB.qs2", verbose = FALSE)

  # Restore fileA only
  stamp::st_restore("fileA.qs2", version = "oldest", verbose = FALSE)

  # Verify fileA restored but fileB unchanged
  restored_a <- stamp::st_load("fileA.qs2", verbose = FALSE)
  restored_b <- stamp::st_load("fileB.qs2", verbose = FALSE)

  expect_identical(restored_a, data_a1)
  expect_identical(restored_b, data_b2) # Should still be latest version
})
