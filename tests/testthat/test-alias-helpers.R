test_that("st_init trims alias whitespace, validates, and registers", {
  td <- withr::local_tempdir()
  root <- td
  alias_raw <- "  myalias  "

  expect_warning(
    st_init(root = root, state_dir = ".stampA", alias = alias_raw),
    regexp = "using .*myalias",
    all = FALSE
  )

  cfg <- st_alias_get("myalias")
  expect_true(is.list(cfg))
  expect_equal(cfg$root, fs::path_abs(root))
  expect_equal(cfg$state_dir, ".stampA")
  expect_equal(cfg$stamp_path, fs::path_abs(fs::path(root, ".stampA")))
})

test_that("st_init errors on empty or non-character alias", {
  td <- withr::local_tempdir()
  expect_error(st_init(root = td, alias = ""), regexp = "non-empty")
  expect_error(st_init(root = td, alias = 123), regexp = "non-empty|character")
})

test_that("alias conflict rules: same alias different folders errors", {
  t1 <- withr::local_tempdir()
  t2 <- withr::local_tempdir()
  st_init(root = t1, state_dir = ".s1", alias = "dup")
  expect_error(
    st_init(root = t2, state_dir = ".s2", alias = "dup"),
    regexp = "already registered for a different folder"
  )
})

test_that("alias conflict rules: different aliases same folder warns", {
  td <- withr::local_tempdir()
  st_init(root = td, state_dir = ".sX", alias = "a1")
  expect_warning(
    st_init(root = td, state_dir = ".sX", alias = "a2"),
    regexp = "points to the same folder"
  )
})

test_that("st_alias_list returns registered aliases with configs", {
  tA <- withr::local_tempdir()
  tB <- withr::local_tempdir()
  st_init(root = tA, state_dir = ".sa", alias = "A")
  st_init(root = tB, state_dir = ".sb", alias = "B")

  lst <- st_alias_list()
  expect_true(is.data.frame(lst))
  expect_true(all(
    c("alias", "root", "state_dir", "stamp_path") %in% names(lst)
  ))
  expect_true(all(c("A", "B") %in% lst$alias))
})

test_that("st_switch re-bases default alias and affects calls without alias", {
  rA <- withr::local_tempdir()
  rB <- withr::local_tempdir()
  st_opts_reset()
  aliasA <- paste0("A_", basename(rA))
  aliasB <- paste0("B_", basename(rB))
  st_init(root = rA, state_dir = ".sa", alias = aliasA)
  st_init(root = rB, state_dir = ".sb", alias = aliasB)

  pA <- fs::path(rA, "data", "A.qs")
  pB <- fs::path(rB, "data", "B.qs")
  fs::dir_create(fs::path_dir(pA), recurse = TRUE)
  fs::dir_create(fs::path_dir(pB), recurse = TRUE)

  st_save(data.frame(x = 1:3), pA, alias = aliasA, code = function(z) z)
  st_save(data.frame(y = 4:6), pB, alias = aliasB, code = function(z) z)

  expect_silent(st_switch(aliasA))
  expect_true(nzchar(st_latest(pA)))
  expect_true(is.na(st_latest(pB)))

  expect_silent(st_switch(aliasB))
  expect_true(nzchar(st_latest(pB)))
  expect_true(is.na(st_latest(pA)))

  expect_error(st_switch("nope"), regexp = "Alias not found")
})
