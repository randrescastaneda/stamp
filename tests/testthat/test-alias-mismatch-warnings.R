test_that("warning when alias doesn't match path location", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "alias_warn_A")
  rootB <- fs::path(tempdir(), "alias_warn_B")
  fs::dir_create(rootA, recurse = TRUE)
  fs::dir_create(rootB, recurse = TRUE)

  st_init(rootA, alias = "WarnA")
  st_init(rootB, alias = "WarnB")

  pathA <- fs::path(rootA, "data.qs")

  # Save to path in rootA but specify alias for rootB - should warn
  expect_warning(
    st_save(data.frame(id = 1:2), pathA, alias = "WarnB"),
    "Path.*is outside the root of alias.*WarnB"
  )

  # Should also mention where versions will be stored
  expect_warning(
    st_save(data.frame(id = 3:4), pathA, alias = "WarnB"),
    "Versions will be stored under alias WarnA"
  )
})

test_that("no warning when alias matches path location", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "alias_match_A")
  fs::dir_create(rootA, recurse = TRUE)

  st_init(rootA, alias = "MatchA")

  pathA <- fs::path(rootA, "data.qs")

  # Save with matching alias - should NOT warn
  expect_no_warning(
    st_save(data.frame(id = 1:2), pathA, alias = "MatchA")
  )
})

test_that("no warning when alias is NULL", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "alias_null_A")
  fs::dir_create(rootA, recurse = TRUE)

  st_init(rootA, alias = "NullA")

  pathA <- fs::path(rootA, "data.qs")

  # Save without alias - should NOT warn
  expect_no_warning(
    st_save(data.frame(id = 1:2), pathA)
  )
})

test_that("versions stored based on path location, not alias parameter", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "version_loc_A")
  rootB <- fs::path(tempdir(), "version_loc_B")
  fs::dir_create(rootA, recurse = TRUE)
  fs::dir_create(rootB, recurse = TRUE)

  st_init(rootA, alias = "LocA")
  st_init(rootB, alias = "LocB")

  pathA <- fs::path(rootA, "data.qs")
  pathB <- fs::path(rootB, "data.qs")

  # Save to pathA with alias="LocB"
  suppressWarnings(
    result <- st_save(data.frame(id = 1:2), pathA, alias = "LocB")
  )

  # Versions should be in LocA (where pathA is), not LocB
  versionsA <- st_versions(pathA, alias = "LocA")
  versionsB <- st_versions(pathA, alias = "LocB")

  expect_equal(nrow(versionsA), 1L)
  expect_equal(nrow(versionsB), 0L)

  # Verify the version exists in LocA's stamp folder
  stampA <- fs::path(rootA, ".stamp")
  stampB <- fs::path(rootB, ".stamp")

  expect_true(fs::dir_exists(fs::path(stampA, "versions")))
  expect_false(fs::dir_exists(fs::path(stampB, "versions")))

  # Save to pathB with alias="LocB" (matching)
  result2 <- st_save(data.frame(id = 3:4), pathB, alias = "LocB")

  # This should be in LocB
  versionsB2 <- st_versions(pathB, alias = "LocB")
  expect_equal(nrow(versionsB2), 1L)
})

test_that("auto-detection works without alias parameter", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "auto_detect_A")
  rootB <- fs::path(tempdir(), "auto_detect_B")
  fs::dir_create(rootA, recurse = TRUE)
  fs::dir_create(rootB, recurse = TRUE)

  st_init(rootA, alias = "AutoA")
  st_init(rootB, alias = "AutoB")

  pathA <- fs::path(rootA, "data.qs")
  pathB <- fs::path(rootB, "data.qs")

  # Save without specifying alias
  result1 <- st_save(data.frame(id = 1:2), pathA)
  result2 <- st_save(data.frame(id = 3:4), pathB)

  # Should auto-detect correct aliases
  versionsA <- st_versions(pathA, alias = "AutoA")
  versionsB <- st_versions(pathB, alias = "AutoB")

  expect_equal(nrow(versionsA), 1L)
  expect_equal(nrow(versionsB), 1L)

  # Cross-check: versions shouldn't appear in wrong aliases
  versionsA_wrongAlias <- st_versions(pathA, alias = "AutoB")
  versionsB_wrongAlias <- st_versions(pathB, alias = "AutoA")

  expect_equal(nrow(versionsA_wrongAlias), 0L)
  expect_equal(nrow(versionsB_wrongAlias), 0L)
})

test_that("can load versions using auto-detected alias", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "load_auto_A")
  fs::dir_create(rootA, recurse = TRUE)

  st_init(rootA, alias = "LoadAutoA")

  pathA <- fs::path(rootA, "data.qs")

  # Save without alias
  original_data <- data.frame(id = 1:5, value = letters[1:5])
  st_save(original_data, pathA)

  # Load using the auto-detected alias
  loaded_data <- st_load(pathA, alias = "LoadAutoA")

  expect_equal(loaded_data$id, original_data$id)
  expect_equal(loaded_data$value, original_data$value)
})

test_that("warning message includes helpful context", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "context_A")
  rootB <- fs::path(tempdir(), "context_B")
  fs::dir_create(rootA, recurse = TRUE)
  fs::dir_create(rootB, recurse = TRUE)

  st_init(rootA, alias = "ContextA")
  st_init(rootB, alias = "ContextB")

  pathA <- fs::path(rootA, "data.qs")

  # Capture the warning to check its content
  warning_msg <- capture_warnings(
    st_save(data.frame(id = 1:2), pathA, alias = "ContextB")
  )

  # Should contain all key information
  expect_match(warning_msg[[1]], "ContextB", fixed = TRUE)
  expect_match(warning_msg[[1]], "ContextA", fixed = TRUE)
  expect_match(warning_msg[[1]], "detected from path", fixed = TRUE)
})

test_that("verbose=FALSE suppresses mismatch warning", {
  st_opts_reset()

  rootA <- fs::path(tempdir(), "quiet_A")
  rootB <- fs::path(tempdir(), "quiet_B")
  fs::dir_create(rootA, recurse = TRUE)
  fs::dir_create(rootB, recurse = TRUE)

  st_init(rootA, alias = "QuietA")
  st_init(rootB, alias = "QuietB")

  pathA <- fs::path(rootA, "data.qs")

  # Save with verbose=FALSE - should not warn
  expect_no_warning(
    st_save(data.frame(id = 1:2), pathA, alias = "QuietB", verbose = FALSE)
  )

  # But versions should still be stored correctly
  versionsA <- st_versions(pathA, alias = "QuietA")
  expect_equal(nrow(versionsA), 1L)
})

test_that("nested aliases choose most specific match", {
  st_opts_reset()

  rootOuter <- fs::path(tempdir(), "nested_outer")
  rootInner <- fs::path(rootOuter, "inner")
  fs::dir_create(rootOuter, recurse = TRUE)
  fs::dir_create(rootInner, recurse = TRUE)

  st_init(rootOuter, alias = "Outer")
  st_init(rootInner, alias = "Inner")

  pathInner <- fs::path(rootInner, "data.qs")

  # Save to inner path - should detect "Inner" not "Outer"
  st_save(data.frame(id = 1:2), pathInner)

  versionsInner <- st_versions(pathInner, alias = "Inner")
  versionsOuter <- st_versions(pathInner, alias = "Outer")

  expect_equal(nrow(versionsInner), 1L)
  expect_equal(nrow(versionsOuter), 0L)
})
