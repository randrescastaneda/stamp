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

  # Load only 2021 data (with character)
  loaded_2021 <- st_load_parts(
    parts_dir,
    filter = list(year = "2021"),
    as = "dt"
  )
  expect_equal(nrow(loaded_2021), 2)
  expect_true(all(loaded_2021$year == "2021"))

  # Load only 2020 data (numeric)
  loaded_2020 <- st_load_parts(
    parts_dir,
    filter = list(year = 2020),
    as = "dt"
  )
  expect_equal(nrow(loaded_2020), 2)
  expect_true(all(loaded_2020$year == "2020"))

})

test_that("st_load_parts supports column selection for parquet", {
  skip_if_not_installed("data.table")
  skip_if_not_installed("nanoparquet")
  library(data.table)

  tdir <- tempfile("stamp-load-cols-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    country = rep(c("USA", "CAN"), each = 3),
    year = rep(2020:2022, 2),
    value = 1:6,
    extra_col = letters[1:6]
  )

  parts_dir <- file.path(tdir, "parts")

  # Save as parquet (default for partitions)
  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = c("country"),
    .progress = FALSE
  )

  # Load only specific columns
  loaded_subset <- st_load_parts(
    parts_dir,
    columns = c("year", "value"),
    as = "dt"
  )

  expect_equal(ncol(loaded_subset), 3) # year, value, + country (partition key)
  expect_true(all(c("year", "value", "country") %in% names(loaded_subset)))
  expect_false("extra_col" %in% names(loaded_subset))
  expect_equal(nrow(loaded_subset), 6)
})

test_that("st_load_parts warns for non-columnar formats", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-load-warn-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    country = "USA",
    year = 2020,
    value = 100,
    extra = 200
  )

  parts_dir <- file.path(tdir, "parts")

  # Save as qs2 (non-columnar)
  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = "country",
    format = "qs2",
    .progress = FALSE
  )

  # Should warn and load full object then subset
  expect_warning(
    loaded <- st_load_parts(parts_dir, columns = c("year", "value"), as = "dt"),
    "Column selection not supported"
  )

  # Should still subset correctly
  expect_true(all(c("year", "value", "country") %in% names(loaded)))
  expect_false("extra" %in% names(loaded))
})

test_that("st_load_parts supports expression-based filtering", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-filter-expr-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    country = rep(c("USA", "CAN", "MEX"), each = 4),
    year = rep(2010:2013, 3),
    value = 1:12
  )

  parts_dir <- file.path(tdir, "parts")

  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = c("country", "year"),
    .progress = FALSE
  )

  # Test: year > 2010 (formula syntax)
  loaded_gt <- st_load_parts(
    parts_dir,
    filter = ~ year > 2010,
    as = "dt"
  )
  expect_true(all(loaded_gt$year > 2010))
  expect_equal(nrow(loaded_gt), 9) # 3 countries × 3 years (2011, 2012, 2013)

  # Test: country == "USA" & year >= 2012
  loaded_complex <- st_load_parts(
    parts_dir,
    filter = ~ country == "USA" & year >= 2012,
    as = "dt"
  )
  expect_equal(nrow(loaded_complex), 2)
  expect_true(all(loaded_complex$country == "USA"))
  expect_true(all(loaded_complex$year >= 2012))

  # Test: OR conditions - (country == "CAN" & year == 2012) | (country == "MEX" & year == 2010)
  loaded_or <- st_load_parts(
    parts_dir,
    filter = ~ (country == "CAN" & year == 2012) |
      (country == "MEX" & year == 2010),
    as = "dt"
  )
  expect_equal(nrow(loaded_or), 2)
  can_2012 <- loaded_or$country == "CAN" & loaded_or$year == 2012
  mex_2010 <- loaded_or$country == "MEX" & loaded_or$year == 2010
  expect_true(all(can_2012 | mex_2010))

  # Test: %in% operator
  loaded_in <- st_load_parts(
    parts_dir,
    filter = ~ country %in% c("USA", "CAN") & year != 2010,
    as = "dt"
  )
  expect_true(all(loaded_in$country %in% c("USA", "CAN")))
  expect_true(all(loaded_in$year != 2010))
  expect_equal(nrow(loaded_in), 6)
})

test_that("st_load_parts backward compatible with list filter", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-filter-list-")
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

  # Old-style list filter should still work
  loaded_list <- st_load_parts(
    parts_dir,
    filter = list(country = "USA", year = "2021"),
    as = "dt"
  )
  expect_equal(nrow(loaded_list), 1)
  expect_equal(loaded_list$country, "USA")
  expect_equal(loaded_list$year, "2021")
})

test_that("st_list_parts supports expression filtering", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-list-expr-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    region = rep(c("North", "South", "East"), each = 2),
    status = rep(c("active", "inactive"), 3),
    value = 1:6
  )

  parts_dir <- file.path(tdir, "parts")

  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = c("region", "status"),
    .progress = FALSE
  )

  # List with expression filter (formula)
  listing_expr <- st_list_parts(
    parts_dir,
    filter = ~ region == "North" | status == "active"
  )

  expect_equal(nrow(listing_expr), 4) # North (2) + South/active (1) + East/active (1)

  # Verify all results match filter
  for (i in seq_len(nrow(listing_expr))) {
    expect_true(
      listing_expr$region[i] == "North" | listing_expr$status[i] == "active"
    )
  }

  # List with named list filter (backward compat)
  listing_list <- st_list_parts(
    parts_dir,
    filter = list(region = "South", status = "inactive")
  )
  expect_equal(nrow(listing_list), 1)
  expect_equal(listing_list$region, "South")
  expect_equal(listing_list$status, "inactive")
})

test_that("filter expressions handle numeric comparisons correctly", {
  skip_if_not_installed("data.table")
  library(data.table)

  tdir <- tempfile("stamp-filter-numeric-")
  dir.create(tdir)
  old_opts <- options()
  on.exit(options(old_opts), add = TRUE)
  st_init(tdir)

  dt <- data.table(
    id = 1:10,
    year = rep(2015:2019, 2),
    value = rnorm(10)
  )

  parts_dir <- file.path(tdir, "parts")

  st_write_parts(
    dt,
    base = parts_dir,
    partitioning = "year",
    .progress = FALSE
  )

  # Numeric comparison (formula syntax)
  loaded_numeric <- st_load_parts(
    parts_dir,
    filter = ~ year >= 2017,
    as = "dt"
  )

  expect_true(all(loaded_numeric$year >= 2017))
  expect_equal(nrow(loaded_numeric), 6) # 2017, 2018, 2019 × 2 each
})
