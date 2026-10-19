test_that("st_info reports catalog counts and snapshot dir correctly", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  root <- withr::local_tempdir()
  st_init(root = root, state_dir = ".s", alias = "I")

  p <- fs::path(root, "D.qs")
  fs::dir_create(fs::path_dir(p), recurse = TRUE)

  st_save(data.frame(a = 1:2), p, alias = "I", code = function(z) z)
  st_save(data.frame(a = 3:4), p, alias = "I", code = function(z) z)

  inf <- st_info(p, alias = "I")
  expect_true(is.list(inf))
  expect_true(is.list(inf$catalog))
  expect_equal(inf$catalog$n_versions, 2L)
  expect_equal(inf$catalog$latest_version_id, st_latest(p, alias = "I"))
  expect_true(fs::dir_exists(inf$snapshot_dir))
  expect_identical(st_load(p, alias = "I", verbose = FALSE), data.frame(a = 3:4))
})

test_that("st_prune_versions dry-run selects older versions under policies", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  root <- withr::local_tempdir()
  st_init(root = root, state_dir = ".s", alias = "R")

  p <- fs::path(root, "X.qs")
  fs::dir_create(fs::path_dir(p), recurse = TRUE)

  st_save(data.frame(a = 1), p, alias = "R", code = function(z) z)
  st_save(data.frame(a = 2), p, alias = "R", code = function(z) z)
  st_save(data.frame(a = 3), p, alias = "R", code = function(z) z)

  dr1 <- st_prune_versions(path = p, policy = 1, dry_run = TRUE, alias = "R")
  expect_true(is.data.frame(dr1))
  expect_equal(nrow(dr1), 2L)

  dr2 <- st_prune_versions(
    path = p,
    policy = list(n = 2, days = 365),
    dry_run = TRUE,
    alias = "R"
  )
  expect_true(is.data.frame(dr2))
  # Count and age are a UNION: all three recent versions survive.
  expect_equal(nrow(dr2), 0L)
  expect_equal(nrow(st_versions(p, alias = "R")), 3L)
})

test_that("st_children returns reverse lineage rows for committed parents", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", retain_versions = Inf)
  root <- withr::local_tempdir()
  # Use a unique alias name to avoid conflicts with other tests
  test_alias <- "children-audit"
  st_init(root = root, state_dir = ".s", alias = test_alias)

  pA <- fs::path(root, "A.qs")
  pB <- fs::path(root, "B.qs")
  fs::dir_create(fs::path_dir(pA), recurse = TRUE)
  fs::dir_create(fs::path_dir(pB), recurse = TRUE)

  st_save(data.frame(a = 1), pA, alias = test_alias, code = function(z) z)
  vA <- st_latest(pA, alias = test_alias)

  st_save(
    data.frame(b = 2),
    pB,
    alias = test_alias,
    code = function(z) z,
    parents = list(list(path = pA, version_id = vA))
  )

  kids <- st_children(pA, depth = 1L, alias = test_alias)
  expect_true(is.data.frame(kids))
  expect_equal(nrow(kids), 1L)
  # Compare normalized paths since paths may differ in case on Windows
  pB_norm <- stamp:::.st_normalize_path(pB)
  expect_equal(kids$child_path, pB_norm)
  expect_equal(stamp:::.st_normalize_path(kids$parent_path),
               stamp:::.st_normalize_path(pA))
  expect_equal(kids$parent_version, vA)
  expect_equal(kids$child_version, st_latest(pB, alias = test_alias))
})
