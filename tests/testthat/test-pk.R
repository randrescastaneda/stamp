test_that("st_save records primary key and st_inspect_pk reads it", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "tbl.qs")
  df <- data.frame(id = c(1,2,3), value = letters[1:3], stringsAsFactors = FALSE)

  out <- st_save(df, p, pk = "id", code = function(z) z)
  meta <- st_read_sidecar(p)
  expect_true(is.list(meta))
  expect_true(!is.null(meta$pk))
  expect_equal(st_inspect_pk(p), c("id"))
  # loading attaches stamp_pk attribute
  obj <- st_load(p)
  expect_equal(st_get_pk(obj), c("id"))
})

test_that("st_add_pk validates and can be forced without validate", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")
  p <- fs::path(td, "tbl2.qs")
  df <- data.frame(id = c(1,1), value = 1:2)
  st_save(df, p, code = function(z) z)

  # With validate=TRUE and check_unique=TRUE should error for dup keys
  expect_error(st_add_pk(p, keys = c("id"), validate = TRUE, check_unique = TRUE))

  # But validate = FALSE will just record metadata
  keys <- st_add_pk(p, keys = c("id"), validate = FALSE)
  expect_equal(keys, c("id"))
  expect_equal(st_inspect_pk(p), c("id"))
})

test_that("st_pk enforces presence of columns when validating", {
  df <- data.frame(a=1:3)
  expect_error(st_pk(df, keys = c("b"), validate = TRUE))
})
test_that("multiplication works", {
  expect_equal(2 * 2, 4)
})
