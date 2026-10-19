test_that("catalog templates and legacy data.frames preserve schema and values", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  empty <- stamp:::.st_catalog_read("av")
  expect_named(empty, c("artifacts", "versions", "parents_index"))
  expect_identical(vapply(empty, nrow, integer(1)),
                   c(artifacts = 0L, versions = 0L, parents_index = 0L))
  expect_true(all(vapply(empty, data.table::is.data.table, logical(1))))
  legacy <- list(artifacts = as.data.frame(empty$artifacts),
                 versions = as.data.frame(empty$versions))
  stamp:::.st_write_qs2(legacy, stamp:::.st_catalog_path("av"))
  expect_equal(stamp:::.st_catalog_read("av"), empty)
  writeBin(charToRaw("not a catalog"), stamp:::.st_catalog_path("av"))
  expect_error(stamp:::.st_catalog_read("av"))
})

test_that("catalog upsert append and record maintain exact identity and edges", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- as.character(fs::path(td, "item.rds"))
  parent <- as.character(fs::path(td, "parent.rds"))
  cat <- stamp:::.st_catalog_empty()
  cat <- stamp:::.st_catalog_upsert_artifact(cat, "a", p, "rds", "v1")
  cat <- stamp:::.st_catalog_upsert_artifact(cat, "a", p, "rds", "v2")
  expect_identical(cat$artifacts$latest_version_id, "v2")
  expect_identical(cat$artifacts$n_versions, 2L)
  expect_identical(nrow(cat$artifacts), 1L)
  cat <- stamp:::.st_catalog_append_version(cat, list(
    version_id = "v1", artifact_id = "a", content_hash = "hash",
    code_hash = NA_character_, size_bytes = 3, created_at = "2026-01-01Z",
    sidecar_format = "none"))
  expect_identical(cat$versions$version_id, "v1")
  expect_identical(cat$versions$size_bytes, 3)
  vid <- stamp:::.st_catalog_record_version(p, "rds", 3, "hash", "code",
    "2026-01-01Z", "none", alias = "av",
    parents = list(path = parent, version_id = "pv"))
  aid <- stamp:::.st_artifact_id(p)
  expect_identical(vid, secretbase::siphash13(
    paste(aid, "hash", "code", "2026-01-01Z", sep = "|")))
  written <- stamp:::.st_catalog_read("av")
  expect_identical(written$artifacts$artifact_id, aid)
  expect_identical(written$versions$version_id, vid)
  expect_identical(written$parents_index$parent_artifact_id,
                   stamp:::.st_artifact_id(parent))
  expect_identical(written$parents_index$parent_version_id, "pv")
  expect_identical(written$parents_index$child_version_id, vid)
  expect_identical(stamp:::.st_artifact_path_from_id(aid, written), p)
  expect_identical(stamp:::.st_artifact_path_from_id("missing", written),
                   NA_character_)
})

test_that("version ordering handles ties missing timestamps and stale pointers", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- as.character(fs::path(td, "item.rds"))
  aid <- stamp:::.st_artifact_id(stamp:::.st_normalize_user_path(
    p, alias = "av", must_exist = FALSE)$logical_path)
  cat <- stamp:::.st_catalog_empty()
  for (vid in c("a", "z", "bad")) {
    cat <- stamp:::.st_catalog_append_version(cat, list(
      version_id = vid, artifact_id = aid, content_hash = NA_character_,
      code_hash = NA_character_, size_bytes = 1,
      created_at = if (vid == "bad") "" else "2026-01-01Z",
      sidecar_format = "none"))
  }
  cat <- stamp:::.st_catalog_upsert_artifact(cat, aid, p, "rds", "a")
  stamp:::.st_catalog_write(cat, "av")
  expect_warning(vers <- st_versions(p, alias = "av"), "Dropped 1 corrupt")
  expect_identical(vers$version_id, c("z", "a"))
  expect_warning(latest <- st_latest(p, alias = "av"), "Dropped 1 corrupt")
  expect_identical(latest, "z")
  expect_identical(nrow(stamp:::.st_catalog_read("av")$versions), 3L)
  cat$versions <- cat$versions[version_id != "bad"]
  cat$versions$created_at <- list(list("2026-01-01Z"), "2026-01-01Z")
  stamp:::.st_catalog_write(cat, "av")
  expect_identical(st_versions(p, alias = "av")$version_id, c("z", "a"))
  expect_identical(st_latest("absent.rds", alias = "av"), NA_character_)
  cat$versions[, content_hash := NULL]
  stamp:::.st_catalog_write(cat, "av")
  expect_error(st_versions(p, alias = "av"), "Missing columns: content_hash")
})

test_that("version selectors enforce finite integer offsets and exact IDs", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- fs::path(td, "item.rds")
  first <- st_save(list(x = 1L), p, alias = "av", verbose = FALSE)
  second <- st_save(list(x = 2L), p, alias = "av", verbose = FALSE)
  expect_identical(stamp:::.st_resolve_version(p, NULL, "av"), second$version_id)
  expect_identical(stamp:::.st_resolve_version(p, 0, "av"), second$version_id)
  expect_identical(stamp:::.st_resolve_version(p, -1, "av"), first$version_id)
  expect_identical(stamp:::.st_resolve_version(p, first$version_id, "av"),
                   first$version_id)
  for (invalid in list(1, -0.5, NA_real_, Inf, -Inf, numeric(), c(0, -1),
                       TRUE, NA_character_, character(), c("a", "b"))) {
    expect_error(stamp:::.st_resolve_version(p, invalid, "av"))
  }
  expect_error(stamp:::.st_resolve_version(p, -2, "av"), "beyond")
  expect_error(stamp:::.st_resolve_version(p, "missing", "av"), "not found")
  expect_error(stamp:::.st_resolve_version("absent.rds", -1, "av"), "No versions")
  if (!interactive()) {
    expect_error(stamp:::.st_resolve_version(p, "pick", "av"),
                 "not interactive")
  }
})

test_that("historical loads use committed format after default changes", {
  local_stamp_state()
  local_st_opts(default_format = "json", meta_format = "json",
                warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  x <- data.frame(id = 1:2, date = as.Date(c("2026-01-01", "2026-01-02")),
                  group = factor(c("a", "b")), row.names = c("one", "two"))
  for (name in c("extensionless", "conflict.json")) {
    p <- fs::path(td, name)
    saved <- st_save(x, p, format = "rds", alias = "av", verbose = FALSE)
    old <- st_load_version(p, saved$version_id, alias = "av", verbose = FALSE)
    expect_identical(old, x)
    expect_identical(class(old$date), "Date")
    expect_identical(class(old$group), "factor")
    expect_identical(row.names(old), c("one", "two"))
    expect_error(st_load_version(p, "absent", alias = "av", verbose = FALSE),
                 "not found")
  }
})

test_that("historical custom readers receive arguments and QS2 snapshot metadata", {
  local_stamp_state()
  local_st_opts(default_format = "json", meta_format = "qs2")
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  st_register_format("audit_rds", read = function(path, verbose = FALSE,
                                                increment = 0L, ...) {
    value <- readRDS(path)
    value$x <- value$x + increment
    value
  }, write = function(x, path, verbose = FALSE, ...) saveRDS(x, path))
  p <- fs::path(td, "custom")
  saved <- st_save(list(x = 4L), p, format = "audit_rds", alias = "av",
                   verbose = FALSE)
  expect_identical(stamp:::.st_sidecar_present("custom", "av"), "qs2")
  expect_identical(st_load_version(p, saved$version_id, alias = "av",
                                   verbose = FALSE, increment = 3L)$x, 7L)
  rlang::env_unbind(stamp:::.st_formats_env, "audit_rds")
  expect_error(st_load_version(p, saved$version_id, alias = "av", verbose = FALSE),
               "Unknown format")
})

test_that("historical verification respects current warning and quiet policy", {
  local_stamp_state()
  local_st_opts(verify_on_load = TRUE, store_file_hash = TRUE,
                warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- fs::path(td, "item.rds")
  saved <- st_save(list(x = 1L), p, alias = "av", verbose = FALSE)
  vdir <- stamp:::.st_version_dir("item.rds", saved$version_id, "av")
  saveRDS(list(x = 99L), fs::path(vdir, "artifact"))
  warnings <- character()
  value <- withCallingHandlers(
    st_load_version(p, saved$version_id, alias = "av", verbose = TRUE),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_identical(value$x, 99L)
  expect_length(warnings, 2L)
  expect_match(warnings[[1]], "File hash mismatch")
  expect_match(warnings[[2]], "Loaded object hash mismatch")
  expect_warning(st_load_version(p, saved$version_id, alias = "av",
                                 verbose = FALSE), NA)
  st_opts(verify_on_load = FALSE)
  expect_warning(st_load_version(p, saved$version_id, alias = "av",
                                 verbose = TRUE), NA)
  st_opts(verify_on_load = TRUE)
  local_audit_binding("st_hash_file", function(...) stop("injected hash"))
  local_audit_binding("st_hash_obj", function(...) stop("injected hash"))
  expect_warning(value <- st_load_version(p, saved$version_id, alias = "av",
                                          verbose = TRUE), NA)
  expect_identical(value$x, 99L)
})

test_that("snapshot commits refuse mutation and clean failed staging", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- fs::path(td, "item.rds")
  saved <- st_save(list(x = 1L), p, alias = "av", verbose = FALSE)
  vdir <- stamp:::.st_version_dir("item.rds", saved$version_id, "av")
  hash <- st_hash_file(fs::path(vdir, "artifact"))
  saveRDS(list(x = 9L), stamp:::.st_artifact_path("item.rds", "av"))
  expect_error(stamp:::.st_version_commit_files("item.rds", saved$version_id,
    alias = "av"), "immutable")
  expect_identical(st_hash_file(fs::path(vdir, "artifact")), hash)
  expect_identical(st_load_version(p, saved$version_id, alias = "av",
                                   verbose = FALSE)$x, 1L)
  expect_error(stamp:::.st_version_commit_files("absent.rds", "new",
                                               alias = "av"))
  missing <- stamp:::.st_version_dir("absent.rds", "new", "av")
  expect_false(fs::dir_exists(missing))
  expect_length(fs::dir_ls(fs::path_dir(missing)), 0L)
  expect_identical(stamp:::.st_version_dir_latest("item.rds", "av"), vdir)
  expect_identical(stamp:::.st_version_dir_latest("missing.rds", "av"),
                   NA_character_)
})

test_that("parent normalization and snapshots support legacy shapes and corrupt JSON", {
  local_stamp_state()
  td <- withr::local_tempdir()
  parent <- list(path = "a", version_id = "v")
  expect_identical(stamp:::.st_parents_normalize(NULL), list())
  expect_identical(stamp:::.st_parents_normalize(parent), list(parent))
  expect_identical(stamp:::.st_parents_normalize(list(parent, list(path = "b"))),
                   list(parent))
  expect_identical(stamp:::.st_parents_normalize(
    data.frame(path = "a", version_id = "v")), list(parent))
  expect_identical(stamp:::.st_parents_normalize(data.frame(path = "a")), list())
  expect_identical(stamp:::.st_parents_normalize("a"), list())
  expect_identical(stamp:::.st_version_read_parents(NA_character_), list())
  expect_identical(stamp:::.st_version_read_parents(td), list())
  stamp:::.st_version_write_parents(td, list(parent))
  expect_identical(stamp:::.st_version_read_parents(td), list(parent))
  writeLines("{bad", fs::path(td, "parents.json"))
  expect_warning(result <- stamp:::.st_version_read_parents(td), "Could not parse")
  expect_identical(result, list())
})

test_that("failed parent metadata promotion preserves the committed file", {
  local_stamp_state()
  td <- withr::local_tempdir()
  original <- list(list(path = "a", version_id = "v"))
  stamp:::.st_version_write_parents(td, original)
  local_audit_binding("file_move", function(...) stop("injected promotion"),
                       env = asNamespace("fs"))
  expect_error(stamp:::.st_version_write_parents(td,
    list(list(path = "b", version_id = "w"))), "injected promotion")
  expect_identical(stamp:::.st_version_read_parents(td), original)
  expect_identical(as.character(fs::path_file(fs::dir_ls(td))), "parents.json")
})

test_that("legacy snapshots without metadata retain extension format fallback", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  vdir <- stamp:::.st_version_dir("legacy.rds", "legacy", "av")
  fs::dir_create(vdir)
  saveRDS(list(value = 42L), fs::path(vdir, "artifact"))
  expect_identical(st_load_version("legacy.rds", "legacy", alias = "av",
                                   verbose = FALSE), list(value = 42L))
  writeLines("{bad", fs::path(vdir, "sidecar.json"))
  expect_identical(st_load_version("legacy.rds", "legacy", alias = "av",
                                   verbose = FALSE), list(value = 42L))
  writeLines("42", fs::path(vdir, "sidecar.json"))
  expect_identical(st_load_version("legacy.rds", "legacy", alias = "av",
                                   verbose = FALSE), list(value = 42L))
})

test_that("lineage and children return exact chain edges with alias-relative paths", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  paths <- as.character(fs::path(td, c("a.rds", "b.rds", "c.rds")))
  a <- st_save(1L, paths[[1]], alias = "av", verbose = FALSE)
  b <- st_save(2L, paths[[2]], alias = "av", verbose = FALSE,
    parents = list(path = paths[[1]], version_id = a$version_id))
  c <- st_save(3L, paths[[3]], alias = "av", verbose = FALSE,
    parents = list(path = paths[[2]], version_id = b$version_id))
  lineage <- st_lineage("c.rds", depth = Inf, alias = "av")
  expect_equal(st_lineage(paths[[3]], depth = Inf, alias = "av"), lineage)
  expect_identical(lineage$level, 1:2)
  expect_identical(lineage$child_version, c(c$version_id, b$version_id))
  expect_identical(lineage$parent_version, c(b$version_id, a$version_id))
  children <- st_children("a.rds", depth = Inf, alias = "av")
  expect_identical(children$level, 1:2)
  expect_identical(children$child_version, c(b$version_id, c$version_id))
  expect_identical(children$parent_version, c(a$version_id, b$version_id))
  expect_identical(tolower(children$child_path), tolower(paths[2:3]))
  expect_identical(nrow(st_children(paths[[1]], "missing", alias = "av")), 0L)
  expect_false(st_is_stale(paths[[2]], alias = "av"))
  st_save(4L, paths[[1]], alias = "av", verbose = FALSE)
  expect_true(st_is_stale(paths[[2]], alias = "av"))
  expect_false(st_is_stale(paths[[3]], alias = "av"))
  # Legacy catalogs have no parents index; snapshot scanning must agree.
  cat <- stamp:::.st_catalog_read("av")
  cat$parents_index <- stamp:::.st_catalog_empty()$parents_index
  stamp:::.st_catalog_write(cat, "av")
  expect_equal(st_children("a.rds", depth = Inf, alias = "av"), children)
  expect_identical(nrow(st_lineage("missing.rds", alias = "av")), 0L)
  expect_false(st_is_stale("missing.rds", alias = "av"))
})

test_that("children traversal terminates on cyclic indexed graphs", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- as.character(fs::path(td, c("a.rds", "b.rds")))
  p <- vapply(p, function(path) stamp:::.st_normalize_user_path(
    path, alias = "av", must_exist = FALSE)$logical_path, character(1))
  a <- st_save(1L, p[[1]], alias = "av", verbose = FALSE)
  b <- st_save(2L, p[[2]], alias = "av", verbose = FALSE,
    parents = list(path = p[[1]], version_id = a$version_id))
  # Hand-built graph fixture, not a save-order-dependent impossible cycle.
  cat <- stamp:::.st_catalog_read("av")
  cat$parents_index <- data.table::rbindlist(list(cat$parents_index,
    data.table::data.table(parent_artifact_id = stamp:::.st_artifact_id(p[[2]]),
      parent_version_id = b$version_id,
      child_artifact_id = stamp:::.st_artifact_id(p[[1]]),
      child_version_id = a$version_id)))
  stamp:::.st_catalog_write(cat, "av")
  result <- st_children(p[[1]], version_id = a$version_id, depth = Inf,
                         alias = "av")
  expect_identical(result$child_version, c(b$version_id, a$version_id))
  expect_identical(result$level, 1:2)
  stamp:::.st_version_write_parents(
    stamp:::.st_version_dir("a.rds", a$version_id, "av"),
    list(list(path = p[[2]], version_id = b$version_id)))
  ancestry <- st_lineage(p[[1]], depth = Inf, alias = "av")
  expect_identical(ancestry$parent_version, c(b$version_id, a$version_id))
  expect_identical(ancestry$level, 1:2)
})

test_that("cross-alias multi-parent lineage uses each committed snapshot", {
  local_stamp_state()
  one <- withr::local_tempdir()
  two <- withr::local_tempdir()
  st_init(one, alias = "av_one", verbose = FALSE)
  st_init(two, alias = "av_two", verbose = FALSE)
  a_path <- as.character(fs::path(one, "a.rds"))
  b_path <- as.character(fs::path(two, "b.rds"))
  c_path <- as.character(fs::path(two, "c.rds"))
  a <- st_save(1L, a_path, alias = "av_one", verbose = FALSE)
  b <- st_save(2L, b_path, alias = "av_two", verbose = FALSE,
    parents = list(path = a_path, version_id = a$version_id))
  c <- st_save(3L, c_path, alias = "av_two", verbose = FALSE,
    parents = list(list(path = a_path, version_id = a$version_id),
                   list(path = b_path, version_id = b$version_id)))
  rows <- st_lineage(c_path, depth = Inf, alias = "av_two")
  expect_identical(rows$child_version,
                   c(c$version_id, c$version_id, b$version_id))
  expect_identical(rows$parent_version,
                   c(a$version_id, b$version_id, a$version_id))
  expect_identical(rows$level, c(1L, 1L, 2L))
  expect_false(st_is_stale(c_path, alias = "av_two"))
  st_save(4L, a_path, alias = "av_one", verbose = FALSE)
  expect_true(st_is_stale(c_path, alias = "av_two"))
})

test_that("live primary key metadata does not rewrite historical snapshots", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- fs::path(td, "item.rds")
  saved <- st_save(data.frame(id = 1:2, x = c("a", "b")), p,
                   alias = "av", verbose = FALSE)
  snapshot <- fs::path(stamp:::.st_version_dir("item.rds", saved$version_id,
                                              "av"), "sidecar.json")
  hash <- st_hash_file(snapshot)
  st_add_pk(p, keys = "id")
  expect_identical(st_read_sidecar(p, alias = "av")$pk$keys, "id")
  expect_identical(st_hash_file(snapshot), hash)
  historical <- st_load_version(p, saved$version_id, alias = "av", verbose = FALSE)
  expect_identical(historical, data.frame(id = 1:2, x = c("a", "b")))
  expect_null(attr(historical, "stamp_pk"))
  expect_identical(st_versions(p, alias = "av")$version_id, saved$version_id)
})

test_that("version path and compact ID helpers retain their existing contracts", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  expect_identical(stamp:::.st_root_dir("av"), st_alias_get("av")$root)
  expect_identical(stamp:::.st_state_dir_abs("av"), st_alias_get("av")$stamp_path)
  expect_equal(stamp:::.st_catalog_path("av"),
               fs::path(st_alias_get("av")$stamp_path, "catalog.qs2"))
  expect_warning(legacy <- stamp:::.st_versions_root("av"), "per-artifact")
  expect_equal(legacy, fs::path(st_alias_get("av")$stamp_path, "versions"))
  expect_identical(stamp:::.st_norm_path("item.rds"),
                   as.character(fs::path_abs("item.rds")))
  expect_identical(stamp:::.st_artifact_id("item.rds"),
                   secretbase::siphash13(as.character(fs::path_abs("item.rds"))))
  expect_identical(stamp:::.st_version_id("2026-01-02T03:04:05.123Z",
    "abcdef1234", "code"), "20260102T030405123Z-abcdef12")
  expect_identical(stamp:::.st_version_id("2026-01-02Z", NA_character_, "code"),
                   "20260102Z-code")
  expect_identical(stamp:::.st_version_id("2026-01-02Z"), "20260102Z")
  for (id in list(NULL, character(), NA_character_, "")) {
    expect_identical(stamp:::.st_version_dir("item.rds", id, "av"), NA_character_)
  }
  expect_identical(stamp:::.st_sidecar_present("item.rds", "av"), "none")
  json <- stamp:::.st_sidecar_path("item.rds", "json", "av")
  qs2 <- stamp:::.st_sidecar_path("item.rds", "qs2", "av")
  fs::dir_create(fs::path_dir(json))
  writeLines("{}", json)
  expect_identical(stamp:::.st_sidecar_present("item.rds", "av"), "json")
  writeLines("", qs2)
  expect_identical(stamp:::.st_sidecar_present("item.rds", "av"), "both")
  fs::file_delete(json)
  expect_identical(stamp:::.st_sidecar_present("item.rds", "av"), "qs2")
  rlang::env_unbind(stamp:::.stamp_aliases, "default")
  stamp:::st_state_set(root_dir = td, state_dir = "legacy")
  expect_identical(stamp:::.st_root_dir(), td)
  expect_equal(stamp:::.st_state_dir_abs(), fs::path(td, "legacy"))
})

test_that("children re-expand convergent nodes reached by a shorter path", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  paths <- vapply(c("a", "b", "x", "y", "z"), function(name) {
    stamp:::.st_normalize_user_path(fs::path(td, paste0(name, ".rds")),
      alias = "av", must_exist = FALSE)$logical_path
  }, character(1))
  a <- st_save(1L, paths[["a"]], alias = "av", verbose = FALSE)
  b <- st_save(2L, paths[["b"]], alias = "av", verbose = FALSE,
    parents = list(path = paths[["a"]], version_id = a$version_id))
  x <- st_save(3L, paths[["x"]], alias = "av", verbose = FALSE,
    parents = list(list(path = paths[["b"]], version_id = b$version_id),
                   list(path = paths[["a"]], version_id = a$version_id)))
  y <- st_save(4L, paths[["y"]], alias = "av", verbose = FALSE,
    parents = list(path = paths[["x"]], version_id = x$version_id))
  z <- st_save(5L, paths[["z"]], alias = "av", verbose = FALSE,
    parents = list(path = paths[["y"]], version_id = y$version_id))
  result <- st_children(paths[["a"]], depth = 3L, alias = "av")
  expect_setequal(result$child_version,
                   c(b$version_id, x$version_id, y$version_id, z$version_id))
  expect_identical(result$child_version[result$child_path == paths[["z"]]],
                   z$version_id)
  expect_identical(result$level[result$child_path == paths[["z"]]], 3L)
  expect_identical(nrow(result), 4L)
})

test_that("restore explicit IDs preserves values and reports failed saves", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, alias = "av", verbose = FALSE)
  p <- fs::path(td, "item.rds")
  first <- st_save(data.frame(id = 1L, value = "old"), p, alias = "av",
                   verbose = FALSE)
  second <- st_save(data.frame(id = 2L, value = "new"), p, alias = "av",
                    verbose = FALSE)
  old <- st_restore(p, version = first$version_id, alias = "av", verbose = FALSE)
  expect_identical(old, data.frame(id = 1L, value = "old"))
  expect_identical(st_load(p, alias = "av", verbose = FALSE), old)
  ids <- st_versions(p, alias = "av")$version_id
  expect_length(ids, 3L)
  expect_true(all(c(first$version_id, second$version_id) %in% ids))
  expect_false(ids[[1]] %in% c(first$version_id, second$version_id))
  st_register_format("audit_fail", read = function(...) NULL,
    write = function(...) stop("injected writer failure"))
  expect_error(st_restore(p, version = second$version_id, alias = "av",
    verbose = FALSE, format = "audit_fail"), "[Ff]ail|[Rr]estor")
  expect_identical(st_load(p, alias = "av", verbose = FALSE), old)
  expect_identical(st_versions(p, alias = "av")$version_id, ids)
})

test_that("switch success and failure preserve exact active alias", {
  local_stamp_state()
  one <- withr::local_tempdir()
  two <- withr::local_tempdir()
  st_init(one, alias = "av_one", verbose = FALSE)
  st_init(two, alias = "av_two", verbose = FALSE)
  expect_identical(st_switch("av_one"), "av_one")
  expect_identical(st_alias_get(), st_alias_get("av_one"))
  expect_error(st_switch("audit_missing"), "not")
  expect_identical(st_alias_get(), st_alias_get("av_one"))
  expect_identical(st_switch("av_two"), "av_two")
  expect_identical(st_alias_get(), st_alias_get("av_two"))
})
test_that("snapshot scanning takes relative paths from consistent Windows spelling", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  root <- file.path(withr::local_tempdir(), "MixedCASE")
  dir.create(root)
  st_init(root, verbose = FALSE)
  parent <- file.path(root, "a.rds")
  child <- file.path(root, "b.rds")
  a <- st_save(11L, parent, verbose = FALSE)
  b <- st_save(22L, child, parents = list(list(
    path = parent, version_id = a$version_id
  )), verbose = FALSE)
  cat <- stamp:::.st_catalog_read()
  cat$parents_index <- cat$parents_index[0L]
  stamp:::.st_catalog_write(cat)
  original <- stamp:::.st_version_dir
  relative_paths <- character()
  local_audit_binding(".st_version_dir", function(rel_path, version_id, alias = NULL) {
    relative_paths <<- c(relative_paths, rel_path)
    original(rel_path, version_id, alias = alias)
  })
  result <- stamp:::.st_children_once(parent, a$version_id)
  expect_setequal(relative_paths, c("a.rds", "b.rds"))
  expect_equal(nrow(result), 1L)
  expect_identical(result$child_version, b$version_id)
})
