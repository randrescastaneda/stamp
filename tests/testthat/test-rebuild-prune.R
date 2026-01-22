test_that("st_rebuild works with new folder structure", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Register a simple builder
  stamp::st_register_builder(
    "result.qs2",
    function() {
      data.frame(x = 1:5, y = letters[1:5])
    }
  )

  # Build the artifact
  stamp::st_rebuild("result.qs2", verbose = FALSE)

  # Verify artifact was created
  expect_true(fs::file_exists(file.path(
    ".st_data",
    "result.qs2",
    "result.qs2"
  )))

  # Load and verify content
  result <- stamp::st_load("result.qs2", verbose = FALSE)
  expect_equal(result$x, 1:5)
  expect_equal(result$y, letters[1:5])
})

test_that("st_rebuild works with dependencies in new structure", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Register builder for base data
  stamp::st_register_builder(
    "base.qs2",
    function() {
      data.frame(value = 1:10)
    }
  )

  # Register builder that depends on base
  stamp::st_register_builder(
    "derived.qs2",
    function() {
      base_data <- stamp::st_load("base.qs2", verbose = FALSE)
      data.frame(value = base_data$value * 2)
    },
    parents = "base.qs2"
  )

  # Build both
  stamp::st_rebuild("base.qs2", verbose = FALSE)
  stamp::st_rebuild("derived.qs2", verbose = FALSE)

  # Verify both exist
  expect_true(fs::file_exists(file.path(".st_data", "base.qs2", "base.qs2")))
  expect_true(fs::file_exists(file.path(
    ".st_data",
    "derived.qs2",
    "derived.qs2"
  )))

  # Verify derived content
  derived <- stamp::st_load("derived.qs2", verbose = FALSE)
  expect_equal(derived$value, (1:10) * 2)
})

test_that("st_rebuild works with subdirectories", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Register builder in subdirectory
  stamp::st_register_builder(
    "results/output.qs2",
    function() {
      data.frame(status = "success")
    }
  )

  # Build
  stamp::st_rebuild("results/output.qs2", verbose = FALSE)

  # Verify
  expect_true(fs::file_exists(file.path(
    ".st_data",
    "results",
    "output.qs2",
    "output.qs2"
  )))

  output <- stamp::st_load("results/output.qs2", verbose = FALSE)
  expect_equal(output$status, "success")
})

test_that("st_prune_versions keeps specified number of versions", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create multiple versions
  for (i in 1:5) {
    data <- data.frame(version = i)
    stamp::st_save(data, "test.qs2", verbose = FALSE)
    Sys.sleep(0.1) # Ensure different timestamps
  }

  # Verify we have 5 versions
  versions_before <- stamp::st_versions("test.qs2")
  expect_equal(nrow(versions_before), 5)

  # Prune to keep only 2 versions
  stamp::st_prune_versions("test.qs2", keep_n = 2, verbose = FALSE)

  # Verify only 2 versions remain
  versions_after <- stamp::st_versions("test.qs2")
  expect_equal(nrow(versions_after), 2)

  # Verify the kept versions are the most recent
  expect_equal(versions_after$version_id, versions_before$version_id[1:2])
})

test_that("st_prune_versions keeps versions by age", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create versions
  for (i in 1:3) {
    data <- data.frame(value = i)
    stamp::st_save(data, "data.qs2", verbose = FALSE)
    Sys.sleep(0.1)
  }

  versions_before <- stamp::st_versions("data.qs2")
  expect_equal(nrow(versions_before), 3)

  # Prune keeping versions from last 1000 seconds (should keep all)
  stamp::st_prune_versions("data.qs2", keep_recent = "1000s", verbose = FALSE)
  versions_after <- stamp::st_versions("data.qs2")
  expect_equal(nrow(versions_after), 3)

  # Prune keeping only versions from last 0 seconds (should keep only latest)
  stamp::st_prune_versions("data.qs2", keep_recent = "0s", verbose = FALSE)
  versions_final <- stamp::st_versions("data.qs2")
  expect_equal(nrow(versions_final), 1)
})

test_that("st_prune_versions works with subdirectories", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Create versions in subdirectory
  for (i in 1:4) {
    data <- data.frame(iter = i)
    stamp::st_save(data, "models/result.qs2", verbose = FALSE)
    Sys.sleep(0.1)
  }

  versions_before <- stamp::st_versions("models/result.qs2")
  expect_equal(nrow(versions_before), 4)

  # Prune
  stamp::st_prune_versions("models/result.qs2", keep_n = 2, verbose = FALSE)

  versions_after <- stamp::st_versions("models/result.qs2")
  expect_equal(nrow(versions_after), 2)
})

test_that("st_plan_rebuild identifies stale artifacts", {
  test_proj <- withr::local_tempdir("stamp_test")
  withr::local_dir(test_proj)

  stamp::st_init()

  # Register base builder
  stamp::st_register_builder(
    "input.qs2",
    function() data.frame(x = 1:5)
  )

  # Register derived builder
  stamp::st_register_builder(
    "output.qs2",
    function() {
      input <- stamp::st_load("input.qs2", verbose = FALSE)
      data.frame(x = input$x * 2)
    },
    parents = "input.qs2"
  )

  # Build both
  stamp::st_rebuild("input.qs2", verbose = FALSE)
  stamp::st_rebuild("output.qs2", verbose = FALSE)

  # Both should be up-to-date
  plan <- stamp::st_plan_rebuild()
  expect_equal(nrow(plan), 0) # No stale artifacts

  # Modify input
  stamp::st_save(data.frame(x = 10:15), "input.qs2", verbose = FALSE)

  # Now output should be stale
  plan_after <- stamp::st_plan_rebuild()
  expect_true(nrow(plan_after) > 0)
  expect_true("output.qs2" %in% plan_after$path)
})
