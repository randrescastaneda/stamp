# Tests for attribute order normalization in hashing
# Issue: rowbind() + funique() leaves attributes in different order,
# causing identical objects to hash differently

test_that("st_hash_obj produces consistent hashes despite attribute order differences", {
  # Create test data
  raw <- data.table::data.table(
    a = 1:5,
    b = letters[1:5],
    c = rnorm(5)
  )

  pip_inv <- data.table::copy(raw)

  # Scenario from user: funique alone vs rowbind + funique
  DT_a <- pip_inv |>
    collapse::funique() |>
    data.table::as.data.table()

  DT_b <- pip_inv |>
    collapse::rowbind(pip_inv) |>
    collapse::funique() |>
    data.table::as.data.table()

  # Content should be identical
  expect_true(identical(DT_a, DT_b))

  # Attributes may be in different order (this is the bug we're fixing)
  attrs_a <- names(attributes(DT_a))
  attrs_b <- names(attributes(DT_b))

  # With st_hash_obj (which now normalizes), hashes should match
  hash_a <- st_hash_obj(DT_a)
  hash_b <- st_hash_obj(DT_b)

  expect_equal(
    hash_a,
    hash_b,
    info = "Hashes should match after attribute normalization"
  )

  # Same test for data.frames (not data.tables)
  DF_a <- pip_inv |>
    collapse::funique()

  DF_b <- pip_inv |>
    collapse::rowbind(pip_inv) |>
    collapse::funique()

  expect_true(identical(DF_a, DF_b))

  hash_df_a <- st_hash_obj(DF_a)
  hash_df_b <- st_hash_obj(DF_b)

  expect_equal(
    hash_df_a,
    hash_df_b,
    info = "Data.frame hashes should match after attribute normalization"
  )
})

test_that("st_normalize_attrs works with data.tables and uses setattr", {
  skip_if_not_installed("data.table")
  skip_if_not_installed("collapse")

  # Create data.table with attribute order issue using collapse operations
  raw <- data.table::data.table(x = 1:5, y = 6:10)

  dt <- raw |>
    collapse::rowbind(raw) |>
    collapse::funique() |>
    data.table::as.data.table()

  # Store original class
  original_class <- class(dt)

  # Normalize
  dt_normalized <- st_normalize_attrs(dt)

  # Check it's still a data.table
  expect_true(inherits(dt_normalized, "data.table"))
  expect_equal(class(dt_normalized), original_class)

  # Check attributes are in canonical order
  after_order <- names(attributes(dt_normalized))

  # Standard attributes should be prioritized in correct order
  priority_attrs <- c("names", "row.names", "class", ".internal.selfref")
  priority_present <- intersect(priority_attrs, after_order)

  # Check they appear in the correct priority order
  for (i in seq_along(priority_present)[-1]) {
    expect_true(
      which(after_order == priority_present[i - 1]) <
        which(after_order == priority_present[i]),
      info = sprintf(
        "%s should come before %s",
        priority_present[i - 1],
        priority_present[i]
      )
    )
  }
})

test_that("st_normalize_attrs works with regular data.frames", {
  df <- data.frame(x = 1:3, y = 4:6)

  # Get original attributes
  attrs <- attributes(df)
  original_class <- class(df)

  # Manually reverse attribute order
  attributes(df) <- NULL
  for (nm in rev(names(attrs))) {
    attr(df, nm) <- attrs[[nm]]
  }

  # Normalize
  df_normalized <- st_normalize_attrs(df)

  # Check it's still a data.frame (not a data.table)
  expect_false(inherits(df_normalized, "data.table"))
  expect_true(is.data.frame(df_normalized))
  expect_equal(class(df_normalized), original_class)

  # After normalization, should be in canonical order
  after_order <- names(attributes(df_normalized))

  # Check standard attributes are prioritized
  expect_true(which(after_order == "names") < which(after_order == "class"))
  expect_true(which(after_order == "row.names") < which(after_order == "class"))
})

test_that("st_normalize_attrs works with lists", {
  lst <- list(a = 1:3, b = letters[1:3])
  attr(lst, "custom1") <- "value1"
  attr(lst, "custom2") <- "value2"

  # Manually create reversed order
  attrs <- attributes(lst)
  attributes(lst) <- NULL
  for (nm in rev(names(attrs))) {
    attr(lst, nm) <- attrs[[nm]]
  }

  # Normalize (for lists, this returns a new object)
  lst_normalized <- st_normalize_attrs(lst)

  # After normalization, should be in canonical order
  after_order <- names(attributes(lst_normalized))

  # names should come before custom attributes (which are alphabetically sorted)
  if ("names" %in% after_order) {
    expect_true(which(after_order == "names") < which(after_order == "custom1"))
  }

  # custom attributes should be alphabetically sorted
  custom_attrs <- after_order[grepl("^custom", after_order)]
  expect_equal(custom_attrs, sort(custom_attrs))
})

test_that("st_normalize_attrs handles objects with no attributes", {
  x <- 1:10
  # Atomic vectors typically have no attributes except maybe names
  attributes(x) <- NULL

  # Should not error
  expect_silent(st_normalize_attrs(x))

  # Should return the object (for atomic vectors, just returns as-is)
  result <- st_normalize_attrs(x)
  expect_equal(result, x)
})
