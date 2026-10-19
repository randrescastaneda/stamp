test_that("explicit NULL content differs from an omitted comparison", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", store_file_hash = FALSE,
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", verbose = FALSE)
  paths <- c(stamp:::.st_artifact_path("value.rds"),
              stamp:::.st_catalog_path())
  before <- tools::md5sum(paths)
  omitted <- st_changed("value.rds", mode = "content")
  explicit <- st_changed("value.rds", x = NULL, mode = "content")
  expect_identical(omitted$details$content_changed, NA)
  expect_false(omitted$changed)
  expect_identical(explicit$details$content_changed, TRUE)
  expect_true(explicit$changed)
  expect_identical(explicit$reason, "content")
  expect_identical(st_changed_reason("value.rds"), "no_change")
  expect_identical(st_changed_reason("value.rds", x = NULL), "content")
  expect_false(st_should_save("value.rds")$save)
  expect_identical(st_should_save("value.rds", x = NULL),
                   list(save = TRUE, reason = "content"))
  expect_identical(tools::md5sum(paths), before)
})

test_that("native NULL replacements round-trip and preserve historical values", {
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
        tick <- 0L
        local_audit_binding(".st_now_utc", function() {
          tick <<- tick + 1L
          sprintf("2024-01-01T00:00:%02d.000000Z", tick)
        })
        file <- paste0("value.", format)
        first <- st_save(11L, file, verbose = FALSE)
        saved_null <- st_save(NULL, file, verbose = FALSE)
        expect_false(isTRUE(saved_null$skipped))
        expect_type(saved_null$version_id, "character")
        expect_identical(st_load(file, verbose = FALSE), NULL)
        payload <- stamp:::.st_artifact_path(file)
        raw_object <- if (format == "rds") readRDS(payload) else qs2::qs_read(payload)
        expect_identical(raw_object, NULL)
        expect_identical(st_read_sidecar(file)$content_hash,
                         secretbase::siphash13(serialize(NULL, NULL, version = 3)))
        expect_identical(st_load_version(file, first$version_id, verbose = FALSE), 11L)
        expect_identical(st_load_version(file, saved_null$version_id,
                                         verbose = FALSE), NULL)
        expect_equal(nrow(st_versions(file)), 2L)
        before <- tools::md5sum(c(payload, stamp:::.st_catalog_path()))
        expect_identical(st_changed(file, x = NULL)$details$content_changed, FALSE)
        expect_false(st_should_save(file, x = NULL)$save)
        expect_identical(st_changed_reason(file, x = NULL), "no_change")
        expect_true(st_save(NULL, file, verbose = FALSE)$skipped)
        expect_identical(tools::md5sum(c(payload, stamp:::.st_catalog_path())), before)
        expect_equal(nrow(st_versions(file)), 2L)
        next_value <- st_save(22L, file, verbose = FALSE)
        expect_type(next_value$version_id, "character")
        expect_identical(st_load(file, verbose = FALSE), 22L)
        expect_identical(st_restore(file, saved_null$version_id, verbose = FALSE), NULL)
        expect_identical(st_load(file, verbose = FALSE), NULL)
        expect_equal(nrow(st_versions(file)), 4L)
        expect_identical(st_load_version(file, next_value$version_id,
                                         verbose = FALSE), 22L)
      })
    }
  }
})

test_that("fresh native NULL saves are actual retained artifacts", {
  for (format in c("rds", "qs2")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = format, versioning = "content",
                    warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      file <- paste0("fresh.", format)
      expect_identical(st_should_save(file, x = NULL),
                       list(save = TRUE, reason = "missing_artifact"))
      saved <- st_save(NULL, file, verbose = FALSE)
      expect_type(saved$version_id, "character")
      expect_true(file.exists(stamp:::.st_artifact_path(file)))
      expect_identical(st_load(file, verbose = FALSE), NULL)
      expect_identical(st_load_version(file, saved$version_id, verbose = FALSE), NULL)
      expect_false(st_should_save(file, x = NULL)$save)
    })
  }
})

test_that("NULL is distinct from empty objects and missing values", {
  local_stamp_state()
  local_st_opts(default_format = "rds", versioning = "content",
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(NULL, "value.rds", verbose = FALSE)
  for (value in list(list(), list(NULL), data.frame(), NA_integer_, numeric())) {
    expect_true(st_changed("value.rds", x = value, mode = "content")$changed)
    expect_false(identical(st_hash_obj(value), st_hash_obj(NULL)))
  }
  expect_identical(st_load("value.rds", verbose = FALSE), NULL)
})

test_that("omitted wrapper objects preserve code and file comparisons", {
  local_stamp_state()
  local_st_opts(default_format = "rds", versioning = "content",
                store_file_hash = TRUE, code_hash = TRUE,
                warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", code = "old", verbose = FALSE)
  expect_identical(st_changed("value.rds", code = "new")$details$content_changed, NA)
  expect_identical(st_changed_reason("value.rds", code = "new"), "code")
  expect_identical(st_should_save("value.rds", code = "new"),
                   list(save = TRUE, reason = "code"))
  expect_identical(st_changed_reason("value.rds", x = NULL, code = "new"),
                   "content+code")
  saveRDS(99L, stamp:::.st_artifact_path("value.rds"))
  expect_identical(st_changed_reason("value.rds", mode = "file"), "file")
  expect_identical(st_should_save("value.rds"), list(save = TRUE, reason = "file"))
})

test_that("omitted forwarding never evaluates the object digest", {
  local_stamp_state()
  local_st_opts(default_format = "rds", versioning = "content",
                store_file_hash = FALSE, warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", verbose = FALSE)
  calls <- 0L
  original <- st_hash_obj
  local_audit_binding("st_hash_obj", function(x) {
    calls <<- calls + 1L
    original(x)
  })
  expect_false(st_changed("value.rds")$changed)
  expect_identical(st_changed_reason("value.rds"), "no_change")
  expect_false(st_should_save("value.rds")$save)
  expect_identical(calls, 0L)
  expect_true(st_changed("value.rds", x = NULL)$changed)
  expect_identical(calls, 1L)
  expect_identical(st_changed_reason("value.rds", x = NULL), "content")
  expect_identical(calls, 2L)
  expect_true(st_should_save("value.rds", x = NULL)$save)
  expect_identical(calls, 3L)
})

test_that("NULL table writes fail visibly without replacing committed files", {
  for (format in c("csv", "parquet")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = format, meta_format = "json", versioning = "content",
                    warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      file <- paste0("table.", format)
      st_save(data.frame(id = 1L), file, verbose = FALSE)
      paths <- c(stamp:::.st_artifact_path(file), stamp:::.st_catalog_path(),
                  stamp:::.st_sidecar_path(file, "json"))
      before <- tools::md5sum(paths)
      expect_warning(failed <- st_save(NULL, file, verbose = TRUE), "NULL")
      expect_null(failed$version_id)
      expect_null(failed$metadata)
      expect_identical(tools::md5sum(paths), before)
    })
  }
})

test_that("optional FST NULL writes preserve the previous artifact", {
  skip_if_not_installed("fst")
  local_stamp_state()
  local_st_opts(default_format = "fst", meta_format = "json",
                versioning = "content", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(data.frame(id = 1L), "table.fst", verbose = FALSE)
  paths <- c(stamp:::.st_artifact_path("table.fst"), stamp:::.st_catalog_path(),
              stamp:::.st_sidecar_path("table.fst", "json"))
  before <- tools::md5sum(paths)
  expect_warning(failed <- st_save(NULL, "table.fst", verbose = TRUE), "NULL")
  expect_null(failed$version_id)
  expect_null(failed$metadata)
  expect_identical(tools::md5sum(paths), before)
})
