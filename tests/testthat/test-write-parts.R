test_that("st_write_parts auto-partitions and saves data", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-write-parts-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  # Create sample data with multiple partition dimensions
  dt <- data.table(
    country = rep(c("USA", "CAN"), each = 6),
    year = rep(rep(2020:2021, each = 3), 2),
    reporting_level = rep(c("national", "urban", "rural"), 4),
    value = 1:12
  )

  parts_dir <- file.path(tdir, "welfare_parts")

  # Auto-partition and save
  manifest <- st_write_parts(
    dt,
    base = parts_dir,
    partitioning = c("country", "year", "reporting_level"),
    code_label = "test_partition",
    .progress = FALSE
  )

  # Verify manifest structure
  expect_s3_class(manifest, "data.frame")
  expect_true("partition_key" %in% names(manifest))
  expect_true("path" %in% names(manifest))
  expect_true("version_id" %in% names(manifest))
  expect_true("n_rows" %in% names(manifest))

  # Should have 2 countries × 2 years × 3 levels = 12 partitions (one per row)
  expect_equal(nrow(manifest), 12)
  expect_equal(sum(manifest$n_rows), nrow(dt))

  # Verify files exist on disk
  expect_true(all(file.exists(manifest$path)))

  # Verify partition structure (Hive-style paths)
  sample_path <- manifest$path[1]
  expect_true(grepl("country=", sample_path))
  expect_true(grepl("year=", sample_path))
  expect_true(grepl("reporting_level=", sample_path))

  # Load partitions back and verify content
  loaded <- st_load_parts(parts_dir, as = "dt")
  expect_equal(nrow(loaded), nrow(dt))

  # Verify partition columns are added
  expect_true(all(c("country", "year", "reporting_level") %in% names(loaded)))
})

test_that("st_write_parts handles missing partition columns", {
  tdir <- tempfile("stamp-write-parts-err-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.frame(a = 1:3, b = 4:6)
  parts_dir <- file.path(tdir, "parts")

  expect_error(
    st_write_parts(dt, parts_dir, partitioning = c("country", "year")),
    "not found in data"
  )
})

test_that("st_write_parts works with base data.frame", {
  tdir <- tempfile("stamp-write-parts-df-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  df <- data.frame(
    region = rep(c("North", "South"), each = 2),
    category = rep(c("A", "B"), 2),
    value = 1:4
  )

  parts_dir <- file.path(tdir, "parts")

  manifest <- st_write_parts(
    df,
    base = parts_dir,
    partitioning = c("region", "category"),
    .progress = FALSE
  )

  expect_equal(nrow(manifest), 4)
  expect_true(all(file.exists(manifest$path)))
})

test_that("st_write_parts with filter allows selective loading", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-write-parts-filter-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    country = rep(c("USA", "CAN"), each = 3),
    year = rep(2020:2022, 2),
    value = 1:6
  )

  parts_dir <- file.path(tdir, "parts")

  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = c("country", "year"),
    .progress = FALSE
  )

  # Load only USA partitions
  loaded_usa <- st_load_parts(
    parts_dir,
    filter = list(country = "USA"),
    as = "dt"
  )
  expect_equal(nrow(loaded_usa), 3)
  expect_true(all(loaded_usa$country == "USA"))

  # Load only 2021 data
  loaded_2021 <- st_load_parts(
    parts_dir,
    filter = list(year = "2021"),
    as = "dt"
  )
  expect_equal(nrow(loaded_2021), 2)
  expect_true(all(loaded_2021$year == "2021"))
})
