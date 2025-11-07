test_that("verify_on_load warns when file hash or content hash mismatch", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  old <- st_opts("verify_on_load", .get = TRUE)
  withr::defer(st_opts(verify_on_load = old))

  st_opts(verify_on_load = TRUE)
  p <- fs::path(td, "v.qs")
  df <- data.frame(a = 1:3)
  st_save(df, p, code = function(z) z)

  # Tamper the file by writing different content directly
  if (requireNamespace("qs2", quietly = TRUE)) {
    qs2::qs_save(data.frame(a = 9), p)
  } else if (requireNamespace("qs", quietly = TRUE)) {
    qs::qsave(data.frame(a = 9), p)
  } else {
    # fallback: overwrite with saveRDS (still should change content hash)
    saveRDS(data.frame(a = 9), p)
  }

  expect_warning(st_load(p), regexp = "mismatch|File hash mismatch|Loaded object hash mismatch")
})

test_that("sidecar parents shaped as data.frame are normalized and used for first-level lineage", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p1 <- fs::path(td, "a.qs")
  p2 <- fs::path(td, "b.qs")
  st_save(data.frame(a=1), p1, code = function(z) z)
  # create b with a sidecar parents written as a data.frame shape
  st_save(data.frame(a=2), p2, code = function(z) z,
          parents = list(list(path = p1, version_id = st_latest(p1))))

  # remove the committed snapshot for b to force sidecar-only parents
  vdirb <- stamp:::.st_version_dir(p2, st_latest(p2))
  if (fs::dir_exists(vdirb)) fs::dir_delete(vdirb)

  lin <- st_lineage(p2, depth = 1)
  # should find a parent (using sidecar fallback)
  expect_true(nrow(lin) >= 1)
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
