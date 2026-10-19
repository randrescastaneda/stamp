test_that("file locking returns the expression and rapid saves retain all versions", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  p <- fs::path(td, "concur.qs")
  x <- data.frame(a = 1:3)

  expect_identical(stamp:::.st_with_lock(p, 42L), 42L)

  ids <- character(5)
  for (i in seq_len(5)) {
    saved <- st_save(transform(x, a = a + i), p, code = function(z) z)
    ids[[i]] <- saved$version_id
  }
  expect_equal(nrow(st_versions(p)), 5L)
  expect_length(unique(ids), 5L)
  expect_setequal(st_versions(p)$version_id, ids)
  expect_identical(st_latest(p), ids[[5L]])
  expect_identical(st_load(p, verbose = FALSE), transform(x, a = a + 5L))
  for (i in seq_len(5)) {
    expect_identical(st_load_version(p, ids[[i]]), transform(x, a = a + i))
  }
})

test_that("malformed parents.json in a version dir is handled with a warning and returns empty list", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  p1 <- fs::path(td, "aa.qs")
  st_save(data.frame(a = 1), p1, code = function(z) z)
  vid <- st_latest(p1)
  
  # Normalize path to get relative path for internal functions
  norm <- stamp:::.st_normalize_user_path(p1, alias = NULL, must_exist = FALSE)
  vdir <- stamp:::.st_version_dir(norm$rel_path, vid, alias = norm$alias)

  # write invalid JSON into parents.json
  pfile <- fs::path(vdir, "parents.json")
  fs::dir_create(fs::path_dir(pfile), recurse = TRUE)
  writeLines("{ this is not : valid json", pfile)

  expect_warning(
    res <- stamp:::.st_version_read_parents(vdir),
    "Could not parse parents.json"
  )
  expect_identical(res, list())
})

test_that("multi-column PKs attach and st_assert_pk fails when columns missing", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  df <- data.frame(
    id = c(1, 1, 2),
    grp = c("a", "b", "a"),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  p <- fs::path(td, "pk.qs")
  st_save(df, p, pk = c("id", "grp"), code = function(z) z)

  obj <- st_load(p)
  expect_identical(st_get_pk(obj), c("id", "grp"))
  expect_identical(obj$id, df$id)
  expect_identical(obj$grp, df$grp)
  expect_identical(obj$val, df$val)
  expect_identical(attr(obj, "stamp_pk"), list(keys = c("id", "grp")))

  # remove one pk column. Note: subsetting can drop custom attributes,
  # so reattach the pk metadata to simulate an object that claims a pk
  # but lacks the corresponding column.
  obj2 <- obj[, setdiff(names(obj), "grp"), drop = FALSE]
  obj2 <- st_with_pk(obj2, st_get_pk(obj))
  expect_error(stamp:::st_assert_pk(obj2), "Recorded pk refers to missing columns: grp")

  # uniqueness enforcement: duplicate rows should fail when setting pk with unique=TRUE
  df2 <- data.frame(id = c(1, 1), grp = c("a", "a"), x = 1:2)
  expect_error(
    stamp:::st_set_pk(df2, pk = c("id", "grp"), unique = TRUE),
    "pk is not unique"
  )
})

test_that("catalog corruption is detectable and removing it allows repair via save", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  p <- fs::path(td, "c.qs")
  st_save(data.frame(a = 1), p, code = function(z) z)
  st_save(data.frame(a = 2), p, code = function(z) z)

  catp <- stamp:::.st_catalog_path()
  expect_true(fs::file_exists(catp))

  # corrupt the catalog file
  writeLines("not a qs file", catp)
  expect_error(stamp:::.st_catalog_read())

  # remove corrupted file and save should recreate catalog correctly
  fs::file_delete(catp)
  saved <- st_save(data.frame(a = 3), p, code = function(z) z)
  expect_true(fs::file_exists(catp))
  expect_equal(nrow(st_versions(p)), 1L)
  expect_identical(st_versions(p)$version_id, saved$version_id)
  expect_equal(nrow(stamp:::.st_catalog_read()$artifacts), 1L)
  expect_identical(st_load(p, verbose = FALSE), data.frame(a = 3))
})

test_that("catalog tables are data.table and created_at stays atomic", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  p <- fs::path(td, "dt.qs")
  for (i in 1:3) {
    st_save(data.frame(a = i), p, code = function(z) z)
  }

  # Internal read
  cat <- stamp:::.st_catalog_read()
  expect_s3_class(cat$artifacts, "data.table")
  expect_s3_class(cat$versions, "data.table")
  expect_equal(nrow(cat$artifacts), 1L)
  expect_equal(nrow(cat$versions), 3L)
  expect_type(cat$versions$created_at, "character")
  expect_length(cat$versions$created_at, 3L)
  expect_false(anyNA(cat$versions$created_at))

  # st_versions returns data.table without list corruption
  vtab <- st_versions(p)
  expect_s3_class(vtab, "data.table")
  expect_type(vtab$created_at, "character")
  expect_setequal(vtab$version_id, cat$versions$version_id)
})

test_that("pruning warns when candidate deletion snapshot dir missing (deterministic)", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  local_st_opts(default_format = "rds")

  p <- fs::path(td, "pr.qs")
  first <- st_save(data.frame(a = 1), p, code = function(z) z)
  second <- st_save(data.frame(a = 2), p, code = function(z) z)
  third <- st_save(data.frame(a = 3), p, code = function(z) z)
  vids <- st_versions(p)$version_id
  expect_setequal(vids, c(first$version_id, second$version_id, third$version_id))

  # Delete the OLDEST version directory (candidate for pruning under policy=2)
  old_vid <- first$version_id
  
  # Normalize path to get relative path for internal functions
  norm <- stamp:::.st_normalize_user_path(p, alias = NULL, must_exist = FALSE)
  vdir_old <- stamp:::.st_version_dir(norm$rel_path, old_vid, alias = norm$alias)
  expect_true(fs::dir_exists(vdir_old))
  fs::dir_delete(vdir_old)

  # Prune to keep only latest 2; expect warning for missing oldest snapshot
  expect_warning(
    st_prune_versions(path = p, policy = 2, dry_run = FALSE),
    regexp = "Version dir missing at"
  )

  # Artifact metadata should still exist - verify by checking sidecar
  expect_identical(st_read_sidecar(p)$content_hash, third$metadata$content_hash)
  expect_setequal(st_versions(p)$version_id, c(second$version_id, third$version_id))
  expect_identical(st_latest(p), third$version_id)
  expect_identical(st_load(p, verbose = FALSE), data.frame(a = 3))
})
