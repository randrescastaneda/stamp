test_that("st_prune_versions dry-run reports candidates and apply prunes", {
  skip_on_cran()
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
  expect_true(nrow(st_versions(pA)) == 3)

  # Dry run keep latest 1 -> should list 2 candidates to prune
  res <- st_prune_versions(path = pA, policy = 1, dry_run = TRUE)
  expect_true(nrow(res) >= 1)

  # Apply pruning: keep only latest 1
  res2 <- st_prune_versions(path = pA, policy = 1, dry_run = FALSE)
  expect_true(nrow(res2) >= 1)
  # After pruning, st_versions(pA) should have 1 row
  expect_true(nrow(st_versions(pA)) == 1)
})

test_that("st_opts retain_versions applies after st_save via .st_apply_retention", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  old <- st_opts("retain_versions", .get = TRUE)
  withr::defer(st_opts(retain_versions = old))

  st_opts(retain_versions = 1)
  pB <- fs::path(td, "B.qs")
  st_save(data.frame(a=1), pB, code = function(z) z)
  st_save(data.frame(a=2), pB, code = function(z) z)
  st_save(data.frame(a=3), pB, code = function(z) z)

  # As retain_versions=1, after the last save there should be 1 version
  expect_true(nrow(st_versions(pB)) == 1)
})

test_that("retention policy parsing errors on invalid input and accepts char strings", {
  skip_on_cran()
  expect_error(st_prune_versions(policy = list()))
  # character like "2 7" should parse
  p <- withr::local_tempdir()
  st_init(p)
  st_opts(default_format = "rds")
  # create an artifact then call prune with char policy
  pa <- fs::path(p, "x.qs")
  st_save(data.frame(a=1), pa, code = function(z) z)
  res <- st_prune_versions(policy = "1", dry_run = TRUE)
  expect_true(is.data.frame(res))
})

test_that("st_prune_versions does not remove live artifact files (only snapshots)", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "keep.qs")
  st_save(data.frame(a=1), p, code = function(z) z)
  st_save(data.frame(a=2), p, code = function(z) z)
  # Apply pruning (keep latest 1)
  st_prune_versions(path = p, policy = 1, dry_run = FALSE)
  # live artifact should still exist
  expect_true(fs::file_exists(p))
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
