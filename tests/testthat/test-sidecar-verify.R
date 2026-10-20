test_that("verify_on_load warns when file hash or content hash mismatch", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, default_format = "rds",
                verify_on_load = TRUE)

  td <- withr::local_tempdir()
  st_init(td)
  p <- fs::path(td, "v.rds")
  df <- data.frame(a = 1:3)
  st_save(df, p, code = function(z) z)

  # Tamper the file by writing different content to the storage location
  norm <- stamp:::.st_normalize_user_path(p, alias = NULL, must_exist = FALSE)
  saveRDS(data.frame(a = 9), norm$storage_path)

  st_opts(warn_missing_pk_on_load = TRUE)
  st_load(p) |>
    expect_warning(
      regexp = "mismatch|File hash mismatch|Loaded object hash mismatch"
    ) |>
    expect_warning(regexp = "No primary key recorded")
  st_opts(warn_missing_pk_on_load = FALSE)
})

test_that("sidecar parents shaped as data.frame are normalized and used for first-level lineage", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, default_format = "rds")
  td <- withr::local_tempdir()
  st_init(td)

  p1 <- fs::path(td, "a.qs")
  p2 <- fs::path(td, "b.qs")
  st_save(data.frame(a = 1), p1, code = function(z) z)
  # create b with a sidecar parents written as a data.frame shape
  st_save(
    data.frame(a = 2),
    p2,
    code = function(z) z,
    parents = list(list(path = p1, version_id = st_latest(p1)))
  )
  parent_version <- st_latest(p1)
  child_version <- st_latest(p2)
  meta <- st_read_sidecar(p2)
  meta$parents <- data.frame(path = as.character(p1),
                             version_id = parent_version)
  stamp:::.st_write_sidecar("b.qs", meta)

  # remove the committed snapshot for b to force sidecar-only parents
  norm <- stamp:::.st_normalize_user_path(p2, alias = NULL, must_exist = FALSE)
  vdirb <- stamp:::.st_version_dir(
    norm$rel_path,
    st_latest(p2),
    alias = norm$alias
  )
  if (fs::dir_exists(vdirb)) {
    fs::dir_delete(vdirb)
  }

  lin <- st_lineage(p2, depth = 1)
  expect_equal(nrow(lin), 1L)
  expect_identical(lin$level, 1L)
  expect_identical(lin$parent_version, parent_version)
  expect_identical(lin$child_version, child_version)
  expect_identical(lin$parent_path, stamp:::.st_norm_path(p1))
  expected_child <- if (.Platform$OS.type == "windows") {
    fs::path_abs(tolower(normalizePath(p2, winslash = "/", mustWork = TRUE)))
  } else {
    fs::path_abs(p2)
  }
  expect_identical(lin$child_path, as.character(expected_child))
})
