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
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
