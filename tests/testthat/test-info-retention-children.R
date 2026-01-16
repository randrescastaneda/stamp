test_that("st_info reports catalog counts and snapshot dir correctly", {
  root <- withr::local_tempdir()
  st_opts_reset()
  st_init(root = root, state_dir = ".s", alias = "I")

  p <- fs::path(root, "D.qs")
  fs::dir_create(fs::path_dir(p), recurse = TRUE)

  st_save(data.frame(a = 1:2), p, alias = "I", code = function(z) z)
  st_save(data.frame(a = 3:4), p, alias = "I", code = function(z) z)

  inf <- st_info(p, alias = "I")
  expect_true(is.list(inf))
  expect_true(is.list(inf$catalog))
  expect_equal(inf$catalog$n_versions, 2L)
  expect_true(
    is.character(inf$catalog$latest_version_id) ||
      is.na(inf$catalog$latest_version_id)
  )
  expect_true(fs::dir_exists(inf$snapshot_dir) || is.na(inf$snapshot_dir))
})

test_that("st_prune_versions dry-run selects older versions under policies", {
  root <- withr::local_tempdir()
  st_opts_reset()
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
  expect_equal(nrow(dr2), 1L)
})

test_that("st_children returns reverse lineage rows for committed parents", {
  root <- withr::local_tempdir()
  st_opts_reset()
  st_init(root = root, state_dir = ".s", alias = "L")

  pA <- fs::path(root, "A.qs")
  pB <- fs::path(root, "B.qs")
  fs::dir_create(fs::path_dir(pA), recurse = TRUE)
  fs::dir_create(fs::path_dir(pB), recurse = TRUE)

  st_save(data.frame(a = 1), pA, alias = "L", code = function(z) z)
  vA <- st_latest(pA, alias = "L")

  st_save(
    data.frame(b = 2),
    pB,
    alias = "L",
    code = function(z) z,
    parents = list(list(path = pA, version_id = vA))
  )

  kids <- st_children(pA, depth = 1L, alias = "L")
  expect_true(is.data.frame(kids))
  expect_true(nrow(kids) >= 1L)
  expect_true(any(kids$child_path == pB))
})
