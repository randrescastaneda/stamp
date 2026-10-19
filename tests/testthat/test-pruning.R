test_that("st_prune_versions dry-run reports candidates and apply prunes", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  pA <- fs::path(td, "A.qs")
  x <- data.frame(a = 1:3)

  # create multiple versions for A
  st_save(x, pA, code = function(z) z)
  st_save(transform(x, a = a + 1L), pA, code = function(z) z)
  st_save(transform(x, a = a + 2L), pA, code = function(z) z)
  # Confirm that three versions exist before pruning
  expect_equal(nrow(st_versions(pA)), 3L)
  versions <- st_versions(pA)$version_id
  latest <- st_latest(pA)

  # Dry run keep latest 1 -> should list 2 candidates to prune
  res <- st_prune_versions(path = pA, policy = 1, dry_run = TRUE)
  expect_setequal(res$version_id, setdiff(versions, latest))
  expect_setequal(st_versions(pA)$version_id, versions)

  # Apply pruning: keep only latest 1
  res2 <- st_prune_versions(path = pA, policy = 1, dry_run = FALSE)
  expect_setequal(res2$version_id, res$version_id)
  # After pruning, st_versions(pA) should have 1 row
  expect_equal(st_versions(pA)$version_id, latest)
  expect_identical(st_load(pA, verbose = FALSE), transform(x, a = a + 2L))
})

test_that("st_opts retain_versions applies after st_save via .st_apply_retention", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = 1)
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  st_opts(retain_versions = 1)
  pB <- fs::path(td, "B.qs")
  st_save(data.frame(a = 1), pB, code = function(z) z)
  st_save(data.frame(a = 2), pB, code = function(z) z)
  st_save(data.frame(a = 3), pB, code = function(z) z)

  # As retain_versions=1, after the last save there should be 1 version
  expect_equal(nrow(st_versions(pB)), 1L)
  expect_equal(st_versions(pB)$version_id, st_latest(pB))
  expect_identical(st_load(pB, verbose = FALSE), data.frame(a = 3))
})

test_that("retention policy parsing errors on invalid input and accepts char strings", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  expect_error(st_prune_versions(policy = list()))
  # character like "2 7" should parse
  p <- withr::local_tempdir()
  st_init(p)
  st_opts(default_format = "rds")
  # create an artifact then call prune with char policy
  pa <- fs::path(p, "x.qs")
  st_save(data.frame(a = 1), pa, code = function(z) z)
  res <- st_prune_versions(policy = "1", dry_run = TRUE)
  expect_true(is.data.frame(res))
  expect_equal(nrow(res), 0L)
})

test_that("st_prune_versions does not remove live artifact files (only snapshots)", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "keep.qs")
  st_save(data.frame(a = 1), p, code = function(z) z)
  st_save(data.frame(a = 2), p, code = function(z) z)
  # Apply pruning (keep latest 1)
  st_prune_versions(path = p, policy = 1, dry_run = FALSE)
  # live artifact should still exist - verify by checking sidecar metadata
  expect_true(!is.null(st_read_sidecar(p)))
  expect_identical(st_load(p, verbose = FALSE), data.frame(a = 2))
  physical <- stamp:::.st_normalize_user_path(p)$storage_path
  expect_true(fs::file_exists(physical))
})
