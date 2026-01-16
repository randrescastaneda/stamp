test_that("aliases isolate catalogs and versions", {
  st_opts_reset()

  root1 <- fs::path(tempdir(), "stamp-root-1")
  root2 <- fs::path(tempdir(), "stamp-root-2")
  fs::dir_create(root1, recurse = TRUE)
  fs::dir_create(root2, recurse = TRUE)

  # Initialize two stamp folders with aliases
  aliasA <- paste0("A_", basename(root1))
  aliasB <- paste0("B_", basename(root2))
  st_init(root1, alias = aliasA)
  st_init(root2, alias = aliasB)

  # Save artifacts into separate aliases
  pathA <- fs::path(root1, "A.qs")
  pathB <- fs::path(root2, "B.qs")
  xA <- data.frame(a = 1:3)
  xB <- data.frame(b = 4:6)

  resA <- st_save(xA, pathA, alias = aliasA)
  resB <- st_save(xB, pathB, alias = aliasB)

  expect_true(is.list(resA))
  expect_true(is.list(resB))

  # Versions visible only within their alias
  vaA <- st_versions(pathA, alias = aliasA)
  vaB <- st_versions(pathA, alias = aliasB)
  vbA <- st_versions(pathB, alias = aliasA)
  vbB <- st_versions(pathB, alias = aliasB)

  expect_true(nrow(vaA) == 1L)
  expect_true(nrow(vbB) == 1L)
  expect_true(nrow(vaB) == 0L)
  expect_true(nrow(vbA) == 0L)

  # Latest resolves per alias
  la <- st_latest(pathA, alias = aliasA)
  lb <- st_latest(pathB, alias = aliasB)
  expect_true(is.character(la) && nzchar(la))
  expect_true(is.character(lb) && nzchar(lb))

  # Load uses alias-specific version store
  xa <- st_load(pathA, alias = aliasA)
  xb <- st_load(pathB, alias = aliasB)
  expect_true(is.data.frame(xa))
  expect_true(is.data.frame(xb))
})
