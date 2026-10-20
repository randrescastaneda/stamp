test_that("st_init trims alias whitespace, validates, and registers", {
  local_stamp_state()
  td <- withr::local_tempdir()
  root <- td
  alias_raw <- "  myalias  "

  expect_warning(
    st_init(root = root, state_dir = ".stampA", alias = alias_raw),
    regexp = "using .*myalias",
  )

  cfg <- st_alias_get("myalias")
  expect_true(is.list(cfg))
  expect_equal(cfg$root, fs::path_abs(root))
  expect_equal(cfg$state_dir, ".stampA")
  expect_equal(cfg$stamp_path, fs::path_abs(fs::path(root, ".stampA")))
})

test_that("st_init errors on empty or non-character alias", {
  local_stamp_state()
  td <- withr::local_tempdir()
  expect_error(st_init(root = td, alias = ""), regexp = "non-empty")
  expect_error(st_init(root = td, alias = 123), regexp = "non-empty|character")
})

test_that("alias conflict rules: same alias different folders errors", {
  local_stamp_state()
  t1 <- withr::local_tempdir()
  t2 <- withr::local_tempdir()
  st_init(root = t1, state_dir = ".s1", alias = "dup")
  expect_error(
    st_init(root = t2, state_dir = ".s2", alias = "dup"),
    regexp = "already registered for a different folder"
  )
})

test_that("alias conflict rules: different aliases same folder warns", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(root = td, state_dir = ".sX", alias = "a1")
  expect_warning(
    st_init(root = td, state_dir = ".sX", alias = "a2"),
    regexp = "points to the same folder"
  )
})

test_that("st_alias_list returns registered aliases with configs", {
  local_stamp_state()
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
  local_stamp_state()
  rA <- withr::local_tempdir()
  rB <- withr::local_tempdir()
  st_opts_reset()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
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

test_that("missing descendants normalize like their existing ancestor", {
  td <- withr::local_tempdir()
  root <- fs::path(td, "Stamp Mixed Case Root")
  fs::dir_create(root)
  root_spelling <- as.character(root)
  expected_root <- as.character(fs::path_norm(root))
  if (.Platform$OS.type == "windows") {
    root_spelling <- utils::shortPathName(root_spelling)
    expected_root <- tolower(normalizePath(root, winslash = "/"))
  }
  missing <- fs::path(root_spelling, "Missing", "Nested", "Leaf.rds")
  expected <- as.character(fs::path(expected_root, "Missing/Nested/Leaf.rds"))
  if (.Platform$OS.type == "windows") {
    expected <- tolower(expected)
  }

  expect_false(file.exists(missing))
  expect_identical(
    stamp:::.st_normalize_path(c(root_spelling, missing, NA_character_)),
    c(expected_root, expected, NA_character_)
  )
  expect_identical(stamp:::.st_normalize_path(character()), character())
  fs::dir_create(fs::path_dir(missing))
  expect_identical(stamp:::.st_normalize_path(missing), expected)
  fs::file_create(missing)
  expect_identical(stamp:::.st_normalize_path(missing), expected)
  if (.Platform$OS.type != "windows") {
    expect_false(identical(
      stamp:::.st_normalize_path(fs::path(root, "Case.rds")),
      stamp:::.st_normalize_path(fs::path(root, "case.rds"))
    ))
  }
})

test_that("absolute missing children route to named aliases without a default", {
  local_stamp_state()
  rlang::env_unbind(
    stamp:::.stamp_aliases, rlang::env_names(stamp:::.stamp_aliases)
  )
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  root <- fs::path(td, "Stamp Mixed Case Root")
  fs::dir_create(root)
  root_spelling <- as.character(root)
  if (.Platform$OS.type == "windows") {
    root_spelling <- utils::shortPathName(root_spelling)
  }
  path <- fs::path(root_spelling, "missing", "nested", "leaf.rds")
  expect_null(stamp:::.st_detect_alias_from_path(path))
  expect_error(stamp:::.st_normalize_user_path(path), "No stamp folder")
  st_init(root, alias = "named_root", verbose = FALSE)
  expect_null(st_alias_get("default"))
  expect_identical(stamp:::.st_detect_alias_from_path(path), "named_root")
  expect_true(stamp:::.st_path_matches_alias(path, "named_root"))
  expect_identical(
    stamp:::.st_normalize_user_path(path)$alias, "named_root"
  )
  expect_identical(
    stamp:::.st_normalize_user_path(path, alias = "named_root")$rel_path,
    "missing/nested/leaf.rds"
  )
  relative <- stamp:::.st_normalize_user_path(
    "relative.rds", alias = "named_root"
  )
  expect_identical(relative$rel_path, "relative.rds")
  expect_error(
    stamp:::.st_normalize_user_path(
      path, alias = "named_root", must_exist = TRUE
    ),
    "does not exist"
  )

  saved <- st_save(data.frame(x = 1:3), path, verbose = FALSE)
  expect_true(is.list(saved))
  expect_identical(st_load(path, alias = "named_root")$x, 1:3)
  st_init(fs::path(td, "other"), verbose = FALSE)
  another <- fs::path(root_spelling, "still", "missing", "leaf.rds")
  expect_identical(
    stamp:::.st_normalize_user_path(another)$alias, "named_root"
  )
})

test_that("canonical alias matching rejects sibling and traversal escapes", {
  local_stamp_state()
  rlang::env_unbind(
    stamp:::.stamp_aliases, rlang::env_names(stamp:::.stamp_aliases)
  )
  td <- withr::local_tempdir()
  root <- fs::path(td, "Stamp Mixed Case Root")
  fs::dir_create(root)
  st_init(root, alias = "bounded_root", verbose = FALSE)
  root_spelling <- as.character(root)
  if (.Platform$OS.type == "windows") {
    root_spelling <- utils::shortPathName(root_spelling)
  }
  outside <- c(
    as.character(fs::path(paste0(root, "-sibling"), "missing/leaf.rds")),
    paste0(root_spelling, "/../outside/missing/leaf.rds")
  )
  for (path in outside) {
    expect_false(stamp:::.st_path_matches_alias(path, "bounded_root"))
    expect_null(stamp:::.st_detect_alias_from_path(path))
    expect_error(
      stamp:::.st_normalize_user_path(path, alias = "bounded_root"),
      "not under alias root"
    )
  }
  for (path in list(NA_character_, character(), "", c("a", "b"))) {
    expect_error(
      stamp:::.st_normalize_user_path(path, alias = "bounded_root"),
      "non-missing, non-empty character scalar"
    )
  }
})
