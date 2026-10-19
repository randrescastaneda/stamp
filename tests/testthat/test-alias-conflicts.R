test_that("same alias to different folders errors", {
  local_stamp_state()
  st_opts_reset()
  r1 <- withr::local_tempdir()
  r2 <- withr::local_tempdir()
  fs::dir_create(r1, recurse = TRUE)
  fs::dir_create(r2, recurse = TRUE)

  st_init(r1, alias = "A1")
  expect_error(
    st_init(r2, alias = "A1"),
    regexp = "already registered for a different folder"
  )
})

test_that("different aliases to same folder warn", {
  local_stamp_state()
  st_opts_reset()
  r <- withr::local_tempdir()
  fs::dir_create(r, recurse = TRUE)

  st_init(r, alias = "A2")
  expect_warning(st_init(r, alias = "B2"), regexp = "points to the same folder")
})
