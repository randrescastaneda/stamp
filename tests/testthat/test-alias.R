test_that("aliases isolate catalogs and versions", {
  st_opts_reset()

  root1 <- fs::path(tempdir(), "stamp-root-1")
  root2 <- fs::path(tempdir(), "stamp-root-2")
  fs::dir_create(root1, recurse = TRUE)
  fs::dir_create(root2, recurse = TRUE)

  # Initialize two stamp folders with aliases
  st_init(root1, alias = "A")
  st_init(root2, alias = "B")

  # Save artifacts into separate aliases
  pathA <- fs::path(root1, "A.qs")
  pathB <- fs::path(root2, "B.qs")
  xA <- data.frame(a = 1:3)
  xB <- data.frame(b = 4:6)

  resA <- st_save(xA, pathA, alias = "A")
  resB <- st_save(xB, pathB, alias = "B")

  expect_true(is.list(resA))
  expect_true(is.list(resB))

  # Versions visible only within their alias
  vaA <- st_versions(pathA, alias = "A")
  vaB <- st_versions(pathA, alias = "B")
  vbA <- st_versions(pathB, alias = "A")
  vbB <- st_versions(pathB, alias = "B")

  expect_true(nrow(vaA) == 1L)
  expect_true(nrow(vbB) == 1L)
  expect_true(nrow(vaB) == 0L)
  expect_true(nrow(vbA) == 0L)

  # Latest resolves per alias
  la <- st_latest(pathA, alias = "A")
  lb <- st_latest(pathB, alias = "B")
  expect_true(is.character(la) && nzchar(la))
  expect_true(is.character(lb) && nzchar(lb))

  # Load uses alias-specific version store
  xa <- st_load(pathA, alias = "A")
  xb <- st_load(pathB, alias = "B")
  expect_true(is.data.frame(xa))
  expect_true(is.data.frame(xb))
})
