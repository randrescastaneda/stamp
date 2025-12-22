test_that("file locking fallback and rapid consecutive saves do not error", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "concur.qs")
  x <- data.frame(a = 1:3)

  # .st_with_lock should run without error regardless of filelock availability
  expect_silent(.st_with_lock(p, {
    Sys.sleep(0.01)
    TRUE
  }))

  # Rapid consecutive saves should not raise and should produce a latest version
  for (i in seq_len(5)) {
    st_save(transform(x, a = a + i), p, code = function(z) z)
  }
  expect_true(nrow(st_versions(p)) >= 1)
})

test_that("malformed parents.json in a version dir is handled with a warning and returns empty list", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p1 <- fs::path(td, "aa.qs")
  st_save(data.frame(a = 1), p1, code = function(z) z)
  vid <- st_latest(p1)
  vdir <- stamp:::.st_version_dir(p1, vid)

  # write invalid JSON into parents.json
  pfile <- fs::path(vdir, "parents.json")
  fs::dir_create(fs::path_dir(pfile), recurse = TRUE)
  writeLines("{ this is not : valid json", pfile)

  expect_warning(res <- .st_version_read_parents(vdir))
  expect_true(is.list(res) && length(res) == 0)
})

test_that("multi-column PKs attach and st_assert_pk fails when columns missing", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  df <- data.frame(
    id = c(1, 1, 2),
    grp = c("a", "b", "a"),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  p <- fs::path(td, "pk.qs")
  st_save(df, p, pk = c("id", "grp"), code = function(z) z)

  obj <- st_load(p)
  expect_equal(st_get_pk(obj), c("id", "grp"))

  # remove one pk column. Note: subsetting can drop custom attributes,
  # so reattach the pk metadata to simulate an object that claims a pk
  # but lacks the corresponding column.
  obj2 <- obj[, setdiff(names(obj), "grp"), drop = FALSE]
  obj2 <- st_with_pk(obj2, st_get_pk(obj))
  expect_error(st_assert_pk(obj2))

  # uniqueness enforcement: duplicate rows should fail when setting pk with unique=TRUE
  df2 <- data.frame(id = c(1, 1), grp = c("a", "a"), x = 1:2)
  expect_error(st_set_pk(df2, pk = c("id", "grp"), unique = TRUE))
})

test_that("catalog corruption is detectable and removing it allows repair via save", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "c.qs")
  st_save(data.frame(a = 1), p, code = function(z) z)
  st_save(data.frame(a = 2), p, code = function(z) z)

  catp <- stamp:::.st_catalog_path()
  expect_true(fs::file_exists(catp))

  # corrupt the catalog file
  writeLines("not a qs file", catp)
  expect_error(.st_catalog_read())

  # remove corrupted file and save should recreate catalog correctly
  fs::file_delete(catp)
  st_save(data.frame(a = 3), p, code = function(z) z)
  expect_true(fs::file_exists(catp))
  expect_true(nrow(st_versions(p)) >= 1)
})

test_that("catalog tables are data.table and created_at stays atomic", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "dt.qs")
  for (i in 1:3) {
    st_save(data.frame(a = i), p, code = function(z) z)
  }

  # Internal read
  cat <- stamp:::.st_catalog_read()
  expect_true(data.table::is.data.table(cat$artifacts))
  expect_true(data.table::is.data.table(cat$versions))
  expect_false(is.list(cat$versions$created_at))
  expect_equal(length(cat$versions$created_at), nrow(cat$versions))

  # st_versions returns data.table without list corruption
  vtab <- st_versions(p)
  expect_true(data.table::is.data.table(vtab))
  expect_false(is.list(vtab$created_at))
})

test_that("pruning warns when candidate deletion snapshot dir missing (deterministic)", {
  skip_on_cran()
  td <- withr::local_tempdir()
  st_init(td)
  st_opts(default_format = "rds")

  p <- fs::path(td, "pr.qs")
  st_save(data.frame(a = 1), p, code = function(z) z)
  st_save(data.frame(a = 2), p, code = function(z) z)
  st_save(data.frame(a = 3), p, code = function(z) z)
  vids <- st_versions(p)$version_id
  expect_true(length(vids) >= 3)

  # Delete the OLDEST version directory (candidate for pruning under policy=2)
  old_vid <- vids[[length(vids)]]
  vdir_old <- stamp:::.st_version_dir(p, old_vid)
  if (fs::dir_exists(vdir_old)) {
    fs::dir_delete(vdir_old)
  }

  # Prune to keep only latest 2; expect warning for missing oldest snapshot
  expect_warning(
    st_prune_versions(path = p, policy = 2, dry_run = FALSE),
    regexp = "Version dir missing at"
  )

  # Artifact file remains
  expect_true(fs::file_exists(p))
  # Remaining versions should be <= 2
  expect_true(nrow(st_versions(p)) <= 2)
})
