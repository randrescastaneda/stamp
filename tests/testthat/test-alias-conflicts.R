test_that("same alias to different folders errors", {
  st_opts_reset()
  r1 <- fs::path(tempdir(), "alias-conflict-1")
  r2 <- fs::path(tempdir(), "alias-conflict-2")
  fs::dir_create(r1, recurse = TRUE)
  fs::dir_create(r2, recurse = TRUE)

  st_init(r1, alias = "A1")
  expect_error(
    st_init(r2, alias = "A1"),
    regexp = "already registered for a different folder"
  )
})

test_that("different aliases to same folder warn", {
  st_opts_reset()
  r <- fs::path(tempdir(), "alias-same-folder")
  fs::dir_create(r, recurse = TRUE)

  st_init(r, alias = "A2")
  expect_warning(st_init(r, alias = "B2"), regexp = "points to the same folder")
})
