test_that("current loader error callbacks preserve exact readable payloads", {
  for (failure in c("metadata", "file_hash", "object_hash")) {
    local({
      local_stamp_state()
      local_st_opts(default_format = "rds", meta_format = "json",
                    verify_on_load = TRUE, store_file_hash = TRUE,
                    warn_missing_pk_on_load = FALSE)
      root <- withr::local_tempdir()
      st_init(root, verbose = FALSE)
      st_save(11L, "value.rds", verbose = FALSE)
      stored <- readRDS(file.path(root, "value.rds", "value.rds"))
      expect_identical(as.integer(stored), 11L)
      expect_identical(attr(stored, "st_original_format"), "integer")
      expect_identical(attr(stored, "stamp_sanitized"), TRUE)
      calls <- 0L
      if (failure == "metadata") {
        writeLines("{", file.path(root, "value.rds", "stmeta",
                                 "value.rds.stmeta.json"))
        expect_error(st_read_sidecar("value.rds"))
        reader <- st_read_sidecar
        local_audit_binding("st_read_sidecar", function(...) {
          calls <<- calls + 1L
          reader(...)
        })
      } else {
        name <- if (failure == "file_hash") "st_hash_file" else "st_hash_obj"
        local_audit_binding(name, function(...) {
          calls <<- calls + 1L
          stop("injected digest failure")
        })
        expect_error(get(name, asNamespace("stamp"))(NULL), "injected digest failure")
        calls <- 0L
      }
      value <- expect_warning(st_load("value.rds", verbose = TRUE), NA)
      expect_identical(value, 11L)
      expect_identical(calls, 1L)
    })
  }
})

test_that("alias list maps configured and NULL bindings to exact rows", {
  local_stamp_state()
  aliases <- stamp:::.stamp_aliases
  rm(list = ls(aliases, all.names = TRUE), envir = aliases)
  expect_identical(st_alias_list(), data.frame(alias = character(),
    root = character(), state_dir = character(), stamp_path = character()))
  assign("configured", list(root = "root", state_dir = ".state",
    stamp_path = "root/.state"), envir = aliases)
  assign("empty", NULL, envir = aliases)
  rows <- st_alias_list()
  rows <- rows[order(rows$alias), , drop = FALSE]
  rownames(rows) <- NULL
  expect_identical(rows, data.frame(
    alias = c("configured", "empty"), root = c("root", NA_character_),
    state_dir = c(".state", NA_character_),
    stamp_path = c("root/.state", NA_character_)))
})

test_that("save decision metadata failures report missing metadata exactly", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json",
                versioning = "content", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", verbose = FALSE)
  writeLines("{", file.path(root, "value.rds", "stmeta", "value.rds.stmeta.json"))
  expect_error(st_read_sidecar("value.rds"))
  expect_identical(st_should_save("value.rds", 11L),
                   list(save = TRUE, reason = "missing_meta"))
  expect_identical(as.integer(readRDS(file.path(root, "value.rds", "value.rds"))), 11L)
})

test_that("option messages report exact string and logical setting values", {
  local_stamp_state()
  local_st_opts()
  withr::local_options(list(cli.num_colors = 1L, cli.unicode = FALSE,
                            useFancyQuotes = FALSE))
  expect_message(st_opts(default_format = "rds", code_hash = FALSE),
                 'default_format = "rds", code_hash = "FALSE"')
  expect_identical(st_opts("default_format", .get = TRUE), "rds")
  expect_identical(st_opts("code_hash", .get = TRUE), FALSE)
})

test_that("absolute path fallback returns its lexical input after filesystem error", {
  calls <- 0L
  local_audit_binding("path_abs", function(...) {
    calls <<- calls + 1L
    stop("injected path failure")
  }, env = asNamespace("fs"))
  expect_identical(stamp:::.st_make_abs("relative-file.rds"), "relative-file.rds")
  expect_identical(calls, 1L)
})

test_that("lineage sidecar read failures return the exact empty edge schema", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  saved <- st_save(11L, "value.rds", verbose = FALSE)
  calls <- 0L
  local_audit_binding("st_read_sidecar", function(...) {
    calls <<- calls + 1L
    stop("injected sidecar failure")
  })
  expect_identical(st_lineage("value.rds"), data.frame(level = integer(),
    child_path = character(), child_version = character(),
    parent_path = character(), parent_version = character()))
  expect_identical(st_latest("value.rds"), saved$version_id)
  expect_identical(calls, 1L)
})

test_that("restore selector helper preserves explicit IDs and keyword contracts", {
  versions <- data.frame(version_id = c("v4", "v3", "v2", "v1"))
  resolve <- stamp:::.st_resolve_version_identifier
  expect_identical(resolve("v2", versions, "value.rds"), "v2")
  expect_identical(resolve("latest", versions, "value.rds"), "v4")
  expect_identical(resolve("oldest", versions, "value.rds"), "v1")
  expect_error(resolve(TRUE, versions, "value.rds"), "single value")
  expect_error(resolve(c("v1", "v2"), versions, "value.rds"), "single value")
  expect_error(resolve("absent", versions, "value.rds"), "and 1 more")
  expect_error(resolve("absent", versions[1:2, , drop = FALSE], "value.rds"),
               "not found")
  # Signed offsets and deprecated positive positions have dedicated regression tests.
})

test_that("new divergence diagnostics preserve quiet-save warning policy", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "both",
                warn_missing_pk_on_load = FALSE)
  withr::local_options(list(cli.num_colors = 1L, cli.unicode = FALSE))
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_save(11L, "value.rds", verbose = FALSE)
  for (quiet in c(TRUE, FALSE)) {
    meta <- st_read_sidecar("value.rds")
    meta$content_hash <- "divergent"
    qs2::qs_save(meta, file.path(root, "value.rds", "stmeta",
                                "value.rds.stmeta.qs2"))
    warnings <- character()
    value <- if (quiet) 22L else 33L
    saved <- withCallingHandlers(
      suppressMessages(st_save(value, "value.rds", verbose = !quiet)),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
    expected <- if (quiet) character() else paste0(
      "Sidecar metadata differs between JSON and QS2 for 'value.rds'; ",
      "using JSON.")
    expect_setequal(warnings, expected)
    expect_type(saved$version_id, "character")
    expect_identical(st_load("value.rds", verbose = FALSE), value)
  }
})

test_that("sidecar normalization failure retains a missing absolute-path result", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  path <- file.path(root, "missing.rds")
  expect_identical(stamp:::.st_normalize_user_path(path)$rel_path, "missing.rds")
  calls <- 0L
  local_audit_binding(".st_normalize_user_path", function(...) {
    calls <<- calls + 1L
    stop("injected normalization failure")
  })
  expect_error(stamp:::.st_normalize_user_path(path),
               "injected normalization failure")
  calls <- 0L
  expect_null(st_read_sidecar(path))
  expect_identical(calls, 1L)
})
