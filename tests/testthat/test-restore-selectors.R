test_that("restore selectors use zero and negative retained-history offsets", {
  versions <- data.frame(version_id = c("new", "middle", "old"))
  resolve <- stamp:::.st_resolve_version_identifier
  for (offset in c(0L, -1L, -2L, 0, -1, -2)) {
    expect_identical(resolve(offset, versions, "value.rds"),
                     c("new", "middle", "old")[[1 - offset]])
  }
  expect_identical(resolve(0L, versions[1L, , drop = FALSE], "value.rds"), "new")
  expect_error(resolve(-1L, versions[1L, , drop = FALSE], "value.rds"),
               "out of range")
  expect_error(resolve(-3L, versions, "value.rds"), "out of range")
  expect_identical(resolve("latest", versions, "value.rds"), "new")
  expect_identical(resolve("oldest", versions, "value.rds"), "old")
  expect_identical(resolve("middle", versions, "value.rds"), "middle")
})

test_that("positive restore selectors warn and preserve legacy positions", {
  versions <- data.frame(version_id = c("new", "middle", "old"))
  resolve <- stamp:::.st_resolve_version_identifier
  for (position in 1:3) {
    expect_warning(id <- resolve(position, versions, "value.rds"),
                    class = "stamp_deprecated_positive_version")
    expect_identical(id, versions$version_id[[position]])
    expect_identical(id, resolve(1 - position, versions, "value.rds"))
  }
  expect_warning(resolve(2L, versions, "value.rds"), "version = -1")
  expect_warning(expect_error(resolve(4L, versions, "value.rds"),
                              "out of range"), NA)
})

test_that("restore selectors reject malformed and unavailable values cleanly", {
  versions <- data.frame(version_id = c("new", "middle", "old"))
  resolve <- stamp:::.st_resolve_version_identifier
  invalid_numbers <- list(numeric(), c(0, -1), NA_real_, NA_integer_, NaN,
                          Inf, -Inf, 0.5, -1.5)
  for (value in invalid_numbers) {
    expect_warning(expect_error(resolve(value, versions, "value.rds"),
                                 "single finite integer"), NA)
  }
  for (value in c(1e12, -1e12)) {
    expect_warning(expect_error(resolve(value, versions, "value.rds"),
                                 "out of range"), NA)
  }
  for (value in list(NULL, TRUE, list(1), 1 + 0i, character(), NA_character_,
                     c("new", "old"))) {
    expect_error(resolve(value, versions, "value.rds"), "single")
  }
  expect_error(resolve("absent", versions, "value.rds"), "not found")
  expect_error(resolve(0L, versions[0L, , drop = FALSE], "value.rds"),
               "No versions")
})

test_that("public signed restore selectors match historical loads and keep defaults", {
  selectors <- list(0L, -1L, -2L, "latest", "oldest")
  expected <- c(30L, 20L, 10L, 30L, 10L, 10L)
  expect_identical(formals(st_restore)$version, "oldest")
  for (case in seq_along(expected)) {
    local({
      local_stamp_state()
      local_st_opts(default_format = "rds", meta_format = "json",
                    versioning = "timestamp", retain_versions = Inf,
                    verify_on_load = FALSE, warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      tick <- 0L
      local_audit_binding(".st_now_utc", function() {
        tick <<- tick + 1L
        sprintf("2024-01-01T00:00:%02d.000000Z", tick)
      })
      saved <- lapply(c(10L, 20L, 30L), function(value) {
        st_save(value, "value.rds", verbose = FALSE)
      })
      original_ids <- vapply(saved, `[[`, character(1), "version_id")
      expect_identical(st_versions("value.rds")$version_id, rev(original_ids))
      if (case == 1L) {
        saveRDS(999L, file.path(root, "value.rds", "value.rds"))
        expect_identical(st_load("value.rds", verbose = FALSE), 999L)
      }
      if (case <= 3L) {
        expect_identical(st_load("value.rds", version = selectors[[case]],
                                  verbose = FALSE), expected[[case]])
      }
      value <- if (case <= length(selectors)) {
        st_restore("value.rds", version = selectors[[case]], verbose = FALSE)
      } else st_restore("value.rds", verbose = FALSE)
      expect_identical(value, expected[[case]])
      expect_identical(st_load("value.rds", verbose = FALSE), expected[[case]])
      expect_true(all(original_ids %in% st_versions("value.rds")$version_id))
      expect_identical(st_load_version("value.rds", original_ids[[1L]],
                                       verbose = FALSE), 10L)
    })
  }
})

test_that("public positive restore compatibility keeps the selected old value", {
  for (position in 1:3) {
    local({
      local_stamp_state()
      local_st_opts(default_format = "rds", meta_format = "json",
                    versioning = "timestamp", retain_versions = Inf,
                    warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      tick <- 0L
      local_audit_binding(".st_now_utc", function() {
        tick <<- tick + 1L
        sprintf("2024-01-01T00:00:%02d.000000Z", tick)
      })
      lapply(c(10L, 20L, 30L), function(value) {
        st_save(value, "value.rds", verbose = FALSE)
      })
      expect_warning(value <- st_restore("value.rds", position, verbose = FALSE),
                      class = "stamp_deprecated_positive_version")
      expect_identical(value, c(30L, 20L, 10L)[[position]])
      expect_identical(st_load("value.rds", verbose = FALSE), value)
    })
  }
})

test_that("invalid public restore selectors leave payload and catalog unchanged", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                retain_versions = Inf, warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(30L, "value.rds", verbose = FALSE)
  paths <- c(stamp:::.st_artifact_path("value.rds"),
              stamp:::.st_catalog_path(),
              stamp:::.st_sidecar_path("value.rds", "json"))
  before <- tools::md5sum(paths)
  ids <- st_versions("value.rds")$version_id
  for (value in list(-1L, 2L, NA_real_, Inf, -0.5, c(0L, -1L), "absent")) {
    expect_warning(expect_error(st_restore("value.rds", value, verbose = FALSE)), NA)
    expect_identical(tools::md5sum(paths), before)
    expect_identical(st_versions("value.rds")$version_id, ids)
    expect_identical(st_load("value.rds", verbose = FALSE), 30L)
  }
  expect_error(st_restore("missing.rds", 0L, verbose = FALSE), "No versions")
})
