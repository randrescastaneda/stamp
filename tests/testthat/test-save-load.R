test_that("st_save and st_load create artifact, sidecar and versions", {
  skip_on_cran()
  td <- withr::local_tempdir()
  root <- td
  st_init(root)
  st_opts(default_format = "rds")

  p_qs <- fs::path(root, "demo.qs")
  x <- data.frame(a = 1:3)

  # write and assert artifact + sidecar
  out <- st_save(x, p_qs, code = function(z) z)
  expect_true(fs::file_exists(p_qs))
  sc <- st_read_sidecar(p_qs)
  expect_true(is.list(sc))
  expect_true(nzchar(out$version_id))

  # load and verify content hash matches
  y <- st_load(p_qs)
  expect_equal(y, x)
  expect_equal(st_hash_obj(y), sc$content_hash)

  # rds writer also works via explicit format override
  p_rds <- fs::path(root, "demo.rds")
  out2 <- st_save(x, p_rds, format = "rds", code = function(z) z)
  expect_true(fs::file_exists(p_rds))
  expect_true(nzchar(out2$version_id))
  y2 <- st_load(p_rds)
  expect_equal(y2, x)
})

test_that("atomic write creates temp then moves into place", {
  skip_on_cran()
  td <- withr::local_tempdir()
  root <- td
  st_init(root)
  st_opts(default_format = "rds")
  p <- fs::path(root, "atomic.qs")
  x <- data.frame(a = 1:2)

  res <- st_save(x, p, code = function(z) z)
  expect_true(fs::file_exists(p))
  # Ensure no lingering .tmp files in same dir
  tmpfiles <- fs::dir_ls(fs::path_dir(p), glob = "*tmp-*", recurse = FALSE, fail = FALSE)
  expect_true(length(tmpfiles) == 0)
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
