test_that("native loads preserve only keys recorded on original data.tables", {
  for (format in c("rds", "qs2")) {
    for (meta_format in c("json", "qs2", "both")) {
      local({
        local_stamp_state()
        local_st_opts(default_format = format, meta_format = meta_format,
                      versioning = "content", retain_versions = Inf,
                      verify_on_load = TRUE, store_file_hash = TRUE,
                      warn_missing_pk_on_load = FALSE)
        root <- withr::local_tempdir()
        st_init(root, verbose = FALSE)
        x <- data.table::data.table(id = c(NA_integer_, 1L, 1L, 2L),
                                    group = c("a", "a", "b", "b"), value = 1:4)
        data.table::setkeyv(x, c("id", "group"))
        before <- data.table::copy(x)
        file <- paste0("value.", format)
        saved <- st_save(x, file, metadata = list(attrs = list(note = "kept")),
                         verbose = FALSE)
        expect_identical(x, before)
        expect_type(saved$version_id, "character")
        expect_identical(st_read_sidecar(file)$attrs$note, "kept")
        expect_identical(st_read_sidecar(file)$attrs$stamp_data_table$version, 1L)
        for (out in list(st_load(file, verbose = FALSE),
                         st_load_version(file, saved$version_id, verbose = FALSE))) {
          expect_s3_class(out, "data.table")
          expect_identical(data.table::key(out), c("id", "group"))
          expect_identical(as.data.frame(out), as.data.frame(before))
          expect_identical(st_hash_obj(out), saved$metadata$content_hash)
          expect_identical(st_get_pk(out), character())
        }
        payload <- if (format == "rds") readRDS(stamp:::.st_artifact_path(file)) else
          qs2::qs_read(stamp:::.st_artifact_path(file))
        expect_null(attr(payload, "sorted"))
        expect_null(attr(payload, "stamp_data_table"))
        expect_identical(st_hash_obj(x), st_hash_obj(payload))
      })
    }
  }
})

test_that("unkeyed sorted inputs and primary keys never become data.table keys", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3, value = letters[1:3])
  expect_null(data.table::key(x))
  saved <- st_save(x, "plain.rds", pk = "id", verbose = FALSE)
  out <- st_load("plain.rds", verbose = FALSE)
  expect_null(data.table::key(x))
  expect_null(data.table::key(out))
  expect_identical(st_get_pk(out), "id")
  expect_identical(out$id, 1:3)
  historical <- st_load_version("plain.rds", saved$version_id, verbose = FALSE)
  expect_null(data.table::key(historical))
  df <- data.frame(id = 1:3)
  st_save(df, "frame.rds", pk = "id", verbose = FALSE)
  expect_identical(class(st_load("frame.rds", verbose = FALSE)), "data.frame")
  expect_null(st_read_sidecar("frame.rds")$attrs$stamp_data_table)
})

test_that("key-only changes create metadata versions without changing data hashes", {
  for (meta_format in c("json", "qs2", "both")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = "rds", meta_format = meta_format,
                    versioning = "content", retain_versions = Inf,
                    warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      tick <- 0L
      local_audit_binding(".st_now_utc", function() {
        tick <<- tick + 1L
        sprintf("2024-01-01T00:00:%02d.000000Z", tick)
      })
      x <- data.table::data.table(id = 1:3, group = letters[1:3])
      hash <- st_hash_obj(x)
      states <- list(character(), "id", c("id", "group"), c("group", "id"),
                     character())
      ids <- character()
      for (i in seq_along(states)) {
        data.table::setkeyv(x, if (length(states[[i]])) states[[i]] else NULL)
        expect_identical(st_hash_obj(x), hash)
        if (i > 1L) {
          changed <- st_changed("value.rds", x = x)
          expect_true(changed$changed)
          expect_identical(changed$reason, "metadata")
          expect_false(changed$details$content_changed)
          expect_true(changed$details$metadata_changed)
          expect_false(st_changed("value.rds", x = x, mode = "content")$changed)
          expect_identical(st_changed_reason("value.rds", x = x), "metadata")
          expect_true(st_should_save("value.rds", x = x)$save)
        }
        saved <- st_save(x, "value.rds", verbose = FALSE)
        expect_type(saved$version_id, "character")
        ids <- c(ids, saved$version_id)
        expect_identical(saved$metadata$content_hash, hash)
        expect_identical(data.table::key(st_load("value.rds", verbose = FALSE)),
                         if (length(states[[i]])) states[[i]] else NULL)
        expect_true(st_save(x, "value.rds", verbose = FALSE)$skipped)
      }
      expect_equal(nrow(st_versions("value.rds")), length(states))
      for (i in seq_along(ids)) {
        old <- st_load_version("value.rds", ids[[i]], verbose = FALSE)
        expect_identical(data.table::key(old),
                         if (length(states[[i]])) states[[i]] else NULL)
      }
      restored <- st_restore("value.rds", ids[[2L]], verbose = FALSE)
      expect_identical(data.table::key(restored), "id")
      expect_identical(data.table::key(st_load("value.rds", verbose = FALSE)), "id")
      expect_equal(nrow(st_versions("value.rds")), length(states) + 1L)
    })
  }
})

test_that("recorded keys do not use sorting key setters during loading", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3, value = letters[1:3])
  data.table::setkey(x, id)
  saved <- st_save(x, "value.rds", verbose = FALSE)
  local_audit_binding("setkey", function(...) stop("unexpected key creation"),
                      env = asNamespace("data.table"))
  original <- get("setkeyv", asNamespace("data.table"))
  local_audit_binding("setkeyv", function(x, cols, ...) {
    if (length(cols)) stop("unexpected key sorting")
    original(x, cols, ...)
  }, env = asNamespace("data.table"))
  expect_identical(data.table::key(st_load("value.rds", verbose = FALSE)), "id")
  expect_identical(data.table::key(st_load_version("value.rds", saved$version_id,
                                                   verbose = FALSE)), "id")
})

test_that("legacy missing descriptors never cause a key to be inferred", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3)
  data.table::setkey(x, id)
  saved <- st_save(x, "value.rds", verbose = FALSE)
  meta <- st_read_sidecar("value.rds")
  meta$attrs$stamp_data_table <- NULL
  stamp:::.st_write_sidecar("value.rds", meta)
  vdir <- stamp:::.st_version_dir("value.rds", saved$version_id)
  jsonlite::write_json(meta, file.path(vdir, "sidecar.json"), auto_unbox = TRUE,
                       null = "null", na = "null")
  expect_null(data.table::key(st_load("value.rds", verbose = FALSE)))
  expect_null(data.table::key(st_load_version("value.rds", saved$version_id,
                                               verbose = FALSE)))
  expect_true(st_should_save("value.rds", x = x)$save)
})

test_that("key descriptors are validated without reordering loaded rows", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                verify_on_load = FALSE, warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3, value = letters[1:3])
  data.table::setkey(x, id)
  st_save(x, "value.rds", verbose = FALSE)
  good <- st_read_sidecar("value.rds")
  bad <- list(list(version = 2L, key = "id"),
               list(version = 1L, key = c("id", "id")),
               list(version = 1L, key = NA_character_),
               list(version = 1L, key = "absent"),
               list(version = 1L, key = 1L))
  for (descriptor in bad) {
    meta <- good
    meta$attrs$stamp_data_table <- descriptor
    stamp:::.st_write_sidecar("value.rds", meta)
    expect_error(st_load("value.rds", verbose = FALSE), "data.table key|key metadata")
  }
  stamp:::.st_write_sidecar("value.rds", good)
  payload <- stamp:::.st_artifact_path("value.rds")
  raw <- readRDS(payload)
  raw$id <- rev(raw$id)
  saveRDS(raw, payload)
  before <- readRDS(payload)
  expect_error(st_load("value.rds", verbose = FALSE), "row order")
  expect_identical(readRDS(payload), before)
  expect_identical(x$id, 1:3)
})

test_that("empty keyed tables and reserved descriptors preserve original state", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = integer(), value = character())
  data.table::setkey(x, id)
  st_save(x, "empty.rds", verbose = FALSE)
  out <- st_load("empty.rds", verbose = FALSE)
  expect_identical(data.table::key(out), "id")
  expect_identical(as.data.frame(out), as.data.frame(x))
  plain <- data.table::data.table(id = 1:3)
  st_save(plain, "unkeyed.rds", metadata = list(attrs = list(
    stamp_data_table = list(version = 1L, key = "id"), note = "kept")), verbose = FALSE)
  expect_null(data.table::key(st_load("unkeyed.rds", verbose = FALSE)))
  expect_identical(st_read_sidecar("unkeyed.rds")$attrs$note, "kept")
})

test_that("known-unkeyed metadata does not inherit a custom reader's key", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3)
  saved <- st_save(x, "unkeyed.rds", verbose = FALSE)
  shared <- data.table::copy(x)
  data.table::setkey(shared, id)
  expect_message(st_register_format("rds", read = function(...) shared,
                                    write = saveRDS), "Replaced")
  expect_null(data.table::key(st_load("unkeyed.rds", verbose = FALSE)))
  expect_null(data.table::key(st_load_version("unkeyed.rds", saved$version_id,
                                               verbose = FALSE)))
  expect_identical(data.table::key(shared), "id")
  expect_null(data.table::key(x))
})

test_that("recorded keys do not coerce incompatible custom output into a table", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3)
  data.table::setkey(x, id)
  saved <- st_save(x, "keyed.rds", verbose = FALSE)
  expect_message(st_register_format("rds", read = function(...) data.frame(id = 1:3),
                                    write = saveRDS), "Replaced")
  expect_error(st_load("keyed.rds", verbose = FALSE), "requires a data.table")
  expect_error(st_load_version("keyed.rds", saved$version_id, verbose = FALSE),
               "requires a data.table")
})

test_that("live primary-key annotation preserves recorded snapshot keys", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "both",
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3, value = letters[1:3])
  data.table::setkey(x, id)
  saved <- st_save(x, "keyed.rds", verbose = FALSE)
  snapshot <- stamp:::.st_version_dir("keyed.rds", saved$version_id)
  files <- file.path(snapshot, c("artifact", "sidecar.json", "sidecar.qs2"))
  before <- tools::md5sum(files)
  st_add_pk("keyed.rds", keys = "id")
  expect_identical(st_read_sidecar("keyed.rds")$attrs$stamp_data_table$key, "id")
  expect_identical(data.table::key(st_load("keyed.rds", verbose = FALSE)), "id")
  expect_identical(data.table::key(st_load_version("keyed.rds", saved$version_id,
                                                   verbose = FALSE)), "id")
  expect_identical(tools::md5sum(files), before)
  expect_identical(st_get_pk(st_load_version("keyed.rds", saved$version_id,
                                             verbose = FALSE)), character())
})

test_that("key validation distrusts custom readers' stale sorted attributes", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                verify_on_load = FALSE, warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  x <- data.table::data.table(id = 1:3)
  data.table::setkey(x, id)
  saved <- st_save(x, "keyed.rds", verbose = FALSE)
  shared <- data.table::data.table(id = c(3L, 1L, 2L))
  data.table::setattr(shared, "sorted", "id")
  expect_message(st_register_format("rds", read = function(...) shared,
                                    write = saveRDS), "Replaced")
  expect_error(st_load("keyed.rds", verbose = FALSE), "row order")
  expect_error(st_load_version("keyed.rds", saved$version_id, verbose = FALSE),
               "row order")
  expect_identical(shared$id, c(3L, 1L, 2L))
  expect_identical(data.table::key(shared), "id")
})

test_that("native keys retain original special column names", {
  for (format in c("rds", "qs2")) {
    for (name in c(".xi", "a`b", ".stamp_row_order")) {
      local({
        local_stamp_state()
        local_st_opts(default_format = format, meta_format = "json",
                      warn_missing_pk_on_load = FALSE)
        root <- withr::local_tempdir()
        st_init(root, verbose = FALSE)
        x <- data.table::data.table(id = 1:3, value = letters[1:3])
        data.table::setkey(x, id)
        data.table::setnames(x, "id", name)
        file <- paste0("special.", format)
        saved <- st_save(x, file, verbose = FALSE)
        out <- st_load(file, verbose = FALSE)
        expect_identical(data.table::key(out), name)
        expect_identical(names(out), c(name, "value"))
        expect_identical(as.data.frame(out), as.data.frame(x))
        expect_identical(data.table::key(st_load_version(file, saved$version_id,
                                                         verbose = FALSE)), name)
      })
    }
  }
})
