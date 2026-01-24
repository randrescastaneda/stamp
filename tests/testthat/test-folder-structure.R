test_that("st_init creates .stamp and .st_data directories", {
  skip_on_cran()

  # Create temp directory
  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  # Initialize stamp
  st_init()

  # Check both directories exist
  expect_true(dir.exists(".stamp"))
  expect_true(dir.exists(".st_data"))
})

test_that("st_save with bare filename creates correct structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save test data
  test_data <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data, "test.qs2", verbose = FALSE)

  # Check structure
  expect_true(dir.exists(".st_data/test.qs2"))
  expect_true(dir.exists(".st_data/test.qs2/stmeta"))
  expect_true(dir.exists(".st_data/test.qs2/versions"))

  # Check actual file exists
  expect_true(file.exists(".st_data/test.qs2/test.qs2"))
})

test_that("st_load with bare filename works correctly", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save and load
  test_data <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data, "test.qs2", verbose = FALSE)
  loaded_data <- st_load("test.qs2", verbose = FALSE)

  expect_identical(test_data, loaded_data)
})

test_that("st_save with subdirectories preserves structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save with nested path
  test_data <- data.frame(a = 6:10, b = letters[6:10])
  st_save(test_data, "subdir/nested/data.qs2", verbose = FALSE)

  # Check structure is preserved
  expect_true(dir.exists(".st_data/subdir"))
  expect_true(dir.exists(".st_data/subdir/nested"))
  expect_true(dir.exists(".st_data/subdir/nested/data.qs2"))
  expect_true(file.exists(".st_data/subdir/nested/data.qs2/data.qs2"))
})

test_that("st_load with subdirectories works correctly", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save and load nested
  test_data <- data.frame(a = 6:10, b = letters[6:10])
  st_save(test_data, "subdir/nested/data.qs2", verbose = FALSE)
  loaded_data <- st_load("subdir/nested/data.qs2", verbose = FALSE)

  expect_identical(test_data, loaded_data)
})

test_that("absolute path under root works", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save with absolute path under root
  abs_path <- file.path(getwd(), "abs_test.qs2")
  test_data <- data.frame(z = 11:15)
  st_save(test_data, abs_path, verbose = FALSE)

  # Check it was stored correctly
  expect_true(dir.exists(".st_data/abs_test.qs2"))
  expect_true(file.exists(".st_data/abs_test.qs2/abs_test.qs2"))

  # Load it back
  loaded_data <- st_load(abs_path, verbose = FALSE)
  expect_identical(test_data, loaded_data)
})

test_that("absolute path outside root throws error", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Try to save with path outside root
  outside_path <- file.path(tempdir(), "outside.qs2")
  test_data <- data.frame(x = 1:3)

  expect_error(
    st_save(test_data, outside_path, verbose = FALSE),
    "not under alias root"
  )
})

test_that("st_info works with new structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  test_data <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data, "test.qs2", verbose = FALSE)

  info <- st_info("test.qs2")

  expect_type(info, "list")
  expect_true("sidecar" %in% names(info))
  expect_true("catalog" %in% names(info))
  expect_true("snapshot_dir" %in% names(info))
  expect_true("parents" %in% names(info))
})

test_that("st_versions works with new structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  test_data <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data, "test.qs2", verbose = FALSE)

  versions <- st_versions("test.qs2")

  expect_s3_class(versions, "data.table")
  expect_equal(nrow(versions), 1)
  expect_true("version_id" %in% names(versions))
  expect_true("content_hash" %in% names(versions))
})

test_that("versioning creates multiple versions", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save first version
  test_data_v1 <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data_v1, "test.qs2", verbose = FALSE)

  # Save second version with different data
  test_data_v2 <- data.frame(x = 1:5, y = letters[6:10])
  st_save(test_data_v2, "test.qs2", verbose = FALSE)

  versions <- st_versions("test.qs2")
  expect_equal(nrow(versions), 2)

  # Check multiple version directories exist
  version_dirs <- list.dirs(".st_data/test.qs2/versions", recursive = FALSE)
  expect_equal(length(version_dirs), 2)
})

test_that("st_load_version works with new structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save two versions
  test_data_v1 <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data_v1, "test.qs2", verbose = FALSE)

  test_data_v2 <- data.frame(x = 1:5, y = letters[6:10])
  st_save(test_data_v2, "test.qs2", verbose = FALSE)

  # Get version IDs - they're ordered by created_at descending, so last row is oldest
  versions <- st_versions("test.qs2")
  first_version <- versions$version_id[nrow(versions)] # Get oldest version

  # Load first (oldest) version
  loaded_v1 <- st_load_version("test.qs2", first_version, verbose = FALSE)

  expect_identical(test_data_v1, loaded_v1)
})

test_that("st_changed detects changes with new structure", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  test_data <- data.frame(x = 1:5, y = letters[1:5])
  st_save(test_data, "test.qs2", verbose = FALSE)

  # No change
  result_same <- st_changed("test.qs2", x = test_data, mode = "content")
  expect_false(result_same$changed)

  # Changed data
  test_data_new <- data.frame(x = 1:5, y = letters[6:10])
  result_changed <- st_changed("test.qs2", x = test_data_new, mode = "content")
  expect_true(result_changed$changed)
})

test_that("multiple files in different directories work independently", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save files in different locations
  data1 <- data.frame(a = 1:3)
  data2 <- data.frame(b = 4:6)
  data3 <- data.frame(c = 7:9)

  st_save(data1, "file1.qs2", verbose = FALSE)
  st_save(data2, "dir1/file2.qs2", verbose = FALSE)
  st_save(data3, "dir1/dir2/file3.qs2", verbose = FALSE)

  # Load them back
  loaded1 <- st_load("file1.qs2", verbose = FALSE)
  loaded2 <- st_load("dir1/file2.qs2", verbose = FALSE)
  loaded3 <- st_load("dir1/dir2/file3.qs2", verbose = FALSE)

  expect_identical(data1, loaded1)
  expect_identical(data2, loaded2)
  expect_identical(data3, loaded3)
})

test_that("catalog stores logical paths correctly", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Save with relative path
  test_data <- data.frame(x = 1:5)
  st_save(test_data, "subdir/test.qs2", verbose = FALSE)

  # Read catalog directly
  cat <- stamp:::.st_catalog_read(alias = NULL)

  # Check that path is stored (logical path)
  expect_equal(nrow(cat$artifacts), 1)
  artifact_path <- cat$artifacts$path[1]
  expect_true(nzchar(artifact_path))
  expect_true(grepl("test\\.qs2$", artifact_path))
})

test_that("path normalization helper validates inputs", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  st_init()

  # Test with valid relative path
  norm <- stamp:::.st_normalize_user_path(
    "test.qs2",
    alias = NULL,
    must_exist = FALSE
  )
  expect_type(norm, "list")
  expect_true("logical_path" %in% names(norm))
  expect_true("storage_path" %in% names(norm))
  expect_true("rel_path" %in% names(norm))
  expect_equal(norm$rel_path, "test.qs2")

  # Test with valid absolute path under root
  abs_path <- file.path(getwd(), "test.qs2")
  norm_abs <- stamp:::.st_normalize_user_path(
    abs_path,
    alias = NULL,
    must_exist = FALSE
  )
  expect_equal(norm_abs$rel_path, "test.qs2")
  expect_true(norm_abs$is_absolute)
})

test_that(".st_data folder is configurable", {
  skip_on_cran()

  tdir <- tempfile(pattern = "stamp_test_")
  dir.create(tdir, recursive = TRUE)
  withr::defer(unlink(tdir, recursive = TRUE))

  old_wd <- getwd()
  withr::defer(setwd(old_wd))
  setwd(tdir)

  # Change data folder name
  st_opts(data_folder = ".my_data")
  st_init()

  # Check custom folder exists
  expect_true(dir.exists(".my_data"))

  # Save file
  test_data <- data.frame(x = 1:5)
  st_save(test_data, "test.qs2", verbose = FALSE)

  # Check it's in custom folder
  expect_true(file.exists(".my_data/test.qs2/test.qs2"))

  # Reset for other tests
  st_opts(data_folder = ".st_data")
})
