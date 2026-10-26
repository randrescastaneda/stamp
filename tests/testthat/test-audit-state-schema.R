test_that("state helper restores all stores, options and wd after an error", {
  local_stamp_state()
  stores <- lapply(c(
    ".stamp_aliases", ".stamp_state", ".stamp_opts", ".st_builders_env",
    ".st_formats_env", ".st_extmap_env"
  ), get, envir = asNamespace("stamp"), inherits = FALSE)
  snapshot <- function(e) as.list(e, all.names = TRUE)[sort(ls(e, all.names = TRUE))]
  before <- lapply(stores, snapshot)
  before_options <- options()
  before_wd <- getwd()
  td <- withr::local_tempdir()
  mutate <- function() {
    local_stamp_state()
    for (e in stores) {
      rm(list = ls(e, all.names = TRUE), envir = e)
      assign(".audit_added", "changed", envir = e)
    }
    options(stamp.audit_added = TRUE, cli.user_theme = list(audit = TRUE))
    setwd(td)
    stop("intentional cleanup probe")
  }
  expect_error(mutate(), "intentional cleanup probe")
  expect_identical(lapply(stores, snapshot), before)
  expect_identical(options(), before_options)
  expect_identical(getwd(), before_wd)
})

test_that("state access and lazy null fallback preserve values", {
  local_stamp_state()
  expect_identical(stamp:::`%||%`(NULL, 2L), 2L)
  expect_identical(stamp:::`%||%`(FALSE, stop("not lazy")), FALSE)
  expect_identical(stamp:::`%||%`(character(), 2L), character())
  stamp:::st_state_set(audit_value = list(1L, FALSE))
  expect_identical(stamp:::st_state_get("audit_value"), list(1L, FALSE))
  expect_identical(stamp:::st_state_get("audit_absent", 9L), 9L)
  stamp:::st_state_set(audit_value = NULL)
  expect_null(stamp:::st_state_get("audit_value", 9L))
})

test_that("options initialize idempotently, validate atomically and reset", {
  local_stamp_state()
  local_st_opts()
  st_opts_reset()
  defaults <- stamp:::.stamp_default_opts
  expect_null(stamp:::.st_opts_validate(list()))
  expect_equal(st_opts_get()[names(defaults)], defaults)
  suppressMessages(st_opts(meta_format = "both", versioning = "off"))
  expect_identical(st_opts("meta_format", .get = TRUE), "both")
  expect_identical(st_opts_get("versioning"), "off")
  stamp:::st_opts_init_defaults()
  expect_identical(st_opts_get("meta_format"), "both")
  before <- st_opts_get()
  expect_error(st_opts(meta_format = "json", made_up = TRUE), "Unknown")
  expect_equal(st_opts_get(), before)
  for (x in list(NA_character_, "bad", c("json", "both"), 1, character())) {
    expect_error(st_opts(meta_format = x), "meta_format")
  }
  for (x in list(NA_character_, "bad", c("off", "content"), 1, character())) {
    expect_error(st_opts(versioning = x), "versioning")
  }
  for (x in list(NA, 1, logical(), c(TRUE, FALSE))) {
    expect_error(st_opts(force_on_code_change = x), "force_on_code_change")
  }
  expect_error(st_opts(default_format = 1), "default_format")
  expect_error(st_opts("a", "b", .get = TRUE), "For getting")
  expect_null(st_opts_get("audit_absent"))
  expect_null(st_opts())
  st_opts_reset()
  expect_equal(st_opts(.get = TRUE)[names(defaults)], defaults)
  rlang::env_unbind(stamp:::.stamp_opts, "meta_format")
  stamp:::st_opts_init_defaults()
  expect_identical(st_opts_get("meta_format"), "json")
})

test_that("alias helpers match root boundaries and longest registered roots", {
  local_stamp_state()
  td <- withr::local_tempdir()
  inner <- fs::path(td, "inner")
  fs::dir_create(inner)
  stamp:::.st_alias_register("audit_outer", td, ".stamp", fs::path(td, ".stamp"))
  stamp:::.st_alias_register("audit_inner", inner, ".s", fs::path(inner, ".s"))
  rlang::env_poke(stamp:::.stamp_aliases, "audit_null", NULL)
  expect_identical(stamp:::.st_alias_get("audit_inner")$root, inner)
  expect_null(stamp:::.st_alias_get("audit_unknown"))
  expect_true(stamp:::.st_path_matches_alias(td, "audit_outer"))
  expect_true(stamp:::.st_path_matches_alias(fs::path(inner, "x"), "audit_outer"))
  expect_false(stamp:::.st_path_matches_alias(paste0(td, "-sibling"), "audit_outer"))
  expect_false(stamp:::.st_path_matches_alias(td, "audit_unknown"))
  expect_true(stamp:::.st_path_matches_alias(td, NULL))
  expect_identical(stamp:::.st_detect_alias_from_path(fs::path(inner, "x")),
                   "audit_inner")
  expect_null(stamp:::.st_detect_alias_from_path(paste0(td, "-sibling")))
  expect_error(stamp:::.st_alias_register("", td, ".s", td))
  expect_error(stamp:::.st_make_abs(character()))
  expect_identical(stamp:::.st_make_abs(td), as.character(fs::path_abs(td)))
})

test_that("path helpers distinguish logical, physical and metadata paths", {
  local_stamp_state()
  td <- withr::local_tempdir()
  st_init(td)
  logical <- fs::path(td, "nested", "a.rds")
  physical <- fs::path(logical, "a.rds")
  norm <- stamp:::.st_normalize_user_path("nested/a.rds")
  expect_identical(as.character(norm$storage_path), as.character(physical))
  expect_identical(norm$logical_path, stamp:::.st_normalize_path(logical))
  expect_identical(norm$rel_path, "nested/a.rds")
  expect_identical(norm$alias, "default")
  expect_false(norm$is_absolute)
  expect_identical(stamp:::.st_artifact_path("nested/a.rds"), physical)
  expect_identical(stamp:::.st_extract_rel_path(physical), "nested/a.rds")
  expect_identical(stamp:::.st_extract_rel_path(fs::path(logical, "stmeta", "x")),
                   "nested/a.rds")
  expect_identical(stamp:::.st_extract_rel_path(fs::path(logical, "versions", "v")),
                   "nested/a.rds")
  expect_null(stamp:::.st_extract_rel_path(paste0(td, "-outside/a")))
  expect_null(stamp:::.st_extract_rel_path(logical, "audit_unknown"))
  expect_error(stamp:::.st_file_storage_dir("a", "audit_unknown"), "not found")
  for (x in list(NA_character_, "", character(), c("a", "b"), 1)) {
    expect_error(stamp:::.st_normalize_user_path(x), "character scalar")
  }
  expect_error(stamp:::.st_normalize_user_path(logical, must_exist = TRUE),
               "does not exist")
  expect_error(stamp:::.st_normalize_user_path(paste0(td, "-outside/a")),
               "not under alias root")
  fs::dir_create(fs::path_dir(physical))
  writeLines("fixture", physical)
  absolute <- stamp:::.st_normalize_user_path(physical, must_exist = TRUE)
  expect_true(absolute$is_absolute)
  # An absolute physical path is not silently collapsed to a logical path.
  expect_identical(absolute$logical_path, stamp:::.st_normalize_path(physical))
  stamp:::.st_dir_create(fs::path(td, "new", "deep"))
  expect_true(fs::dir_exists(fs::path(td, "new", "deep")))
  expect_null(stamp:::.st_dir_create(fs::path(td, "new", "deep")))
  expect_match(stamp:::.st_now_utc(),
               "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{6}Z$")
})

test_that("extension defaults seed missing bindings without replacing custom ones", {
  local_stamp_state()
  defaults <- stamp:::st_extmap_defaults()
  expect_identical(defaults$ext, c("qs2", "rds", "csv", "fst", "json"))
  rlang::env_poke(stamp:::.st_extmap_env, "rds", "audit_custom")
  rlang::env_unbind(stamp:::.st_extmap_env, "csv")
  report <- stamp:::st_extmap_report()
  expect_identical(report$current_format[report$ext == "rds"], "audit_custom")
  expect_true(is.na(report$current_format[report$ext == "csv"]))
  stamp:::.seed_extmap()
  stamp:::.seed_extmap()
  report <- stamp:::st_extmap_report()
  expect_identical(report$current_format[report$ext == "rds"], "audit_custom")
  expect_identical(report$current_format[report$ext == "csv"], "csv")
})

test_that("paths handle missing aliases, automatic selection and explicit mismatch", {
  local_stamp_state()
  rlang::env_unbind(stamp:::.stamp_aliases,
                    ls(stamp:::.stamp_aliases, all.names = TRUE))
  expect_error(stamp:::.st_file_storage_dir("a"), "No stamp folder")
  expect_error(stamp:::.st_normalize_user_path("a"), "No stamp folder")
  expect_error(stamp:::.st_normalize_user_path("a", "unknown"), "not found")
  a <- withr::local_tempdir()
  b <- withr::local_tempdir()
  st_init(a, alias = "audit_a", verbose = FALSE)
  st_init(b, alias = "audit_b", verbose = FALSE)
  path <- fs::path(a, "a.rds")
  expect_identical(stamp:::.st_normalize_user_path(path)$alias, "audit_a")
  expect_warning(switched <- stamp:::.st_normalize_user_path(path, "audit_b"),
                  "outside the root")
  expect_identical(switched$alias, "audit_a")
  expect_identical(switched$rel_path, "a.rds")
  expect_identical(stamp:::.st_normalize_user_path(path, "audit_b",
                                                 verbose = FALSE)$alias,
                   "audit_a")
  expect_identical(stamp:::.st_normalize_user_path(path, "audit_b",
                                                 auto_switch = FALSE)$alias,
                   "audit_b")
  st_switch("audit_a")
  expect_identical(st_alias_get(), st_alias_get("audit_a"))
  expect_identical(stamp:::st_state_get("root_dir"), fs::path_abs(a))
  expect_identical(stamp:::st_state_get("state_dir"), ".stamp")
  root_norm <- stamp:::.st_normalize_user_path(a)
  expect_identical(root_norm$rel_path, fs::path_file(a))
  if (.Platform$OS.type == "windows") {
    backslash <- gsub("/", "\\", as.character(a), fixed = TRUE)
    expect_identical(stamp:::.st_normalize_path(backslash),
                     stamp:::.st_normalize_path(a))
    expect_identical(stamp:::.st_detect_alias_from_path(toupper(as.character(path))),
                     "audit_a")
  }
})

test_that("deferred st_path S3 printing preserves the path object", {
  local_stamp_state()
  path <- stamp:::st_path("audit.rds")
  expect_identical(path, structure(list(path = "audit.rds", format = "rds"),
                                   class = "st_path"))
  expect_message(result <- print(path), "audit.rds.*rds")
  expect_identical(result, path)
  expect_identical(stamp:::st_path("extensionless", format = "rds")$format, "rds")
  expect_error(stamp:::st_path(c("a", "b")))
})

test_that("option mirrors fill missing keys but respect session overrides", {
  local_stamp_state()
  local_st_opts(meta_format = "both")
  options(stamp.meta_format = NULL, stamp.versioning = "user_override")
  stamp:::.mirror_opts_to_base()
  expect_identical(getOption("stamp.meta_format"), "both")
  expect_identical(getOption("stamp.versioning"), "user_override")
  suppressMessages(st_opts(meta_format = "json"))
  expect_identical(getOption("stamp.meta_format"), "both")
})

test_that("lifecycle hooks restore absent and existing CLI themes in child R", {
  local_stamp_state()
  td <- withr::local_tempdir()
  script <- fs::path(td, "lifecycle.R")
  result <- fs::path(td, "result.rds")
  ns_path <- find.package("stamp", lib.loc = .libPaths())
  writeLines(c(
    paste0(".libPaths(", paste(deparse(.libPaths()), collapse = ""), ")"),
    "args <- commandArgs(TRUE)",
    "options(cli.user_theme = NULL, stamp.meta_format = NULL)",
    "loadNamespace('stamp', lib.loc = args[1])",
    "stopifnot(identical(getOption('stamp.meta_format'), 'json'))",
    "stopifnot(identical(getOption('cli.user_theme')$span.red$color, 'red'))",
    "unloadNamespace('stamp')",
    "stopifnot(is.null(getOption('cli.user_theme')))",
    "prior <- list(custom = list(color = 'green'))",
    "options(cli.user_theme = prior, stamp.meta_format = 'user_override')",
    "loadNamespace('stamp', lib.loc = args[1])",
    "stopifnot(identical(getOption('stamp.meta_format'), 'user_override'))",
    "unloadNamespace('stamp')",
    "stopifnot(identical(getOption('cli.user_theme'), prior))",
    "saveRDS(TRUE, args[2])"
  ), script)
  r <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "R.exe" else "R")
  output <- system2(r, c("--vanilla", "--slave", "-f", shQuote(script),
                         "--args", shQuote(dirname(ns_path)), shQuote(result)),
                    stdout = TRUE, stderr = TRUE)
  status <- attr(output, "status")
  expect_true(is.null(status) || identical(status, 0L),
              info = paste(output, collapse = "\n"))
  expect_true(file.exists(result))
  if (file.exists(result)) expect_identical(readRDS(result), TRUE)
})

test_that("PK normalization validates keys and uniqueness without mutating data", {
  local_stamp_state()
  df <- data.frame(id = c(1L, 2L), label = c("a", "b"))
  before <- df
  expect_identical(st_pk(df, c("id", "id")), list(keys = "id"))
  expect_identical(st_pk(keys = "id"), list(keys = "id"))
  expect_identical(st_pk(df, "absent", validate = FALSE), list(keys = "absent"))
  expect_error(st_pk(df, "absent"), "not in data")
  expect_error(st_pk(1, "id"), "data.frame")
  for (keys in list(NA_character_, "", character(), 1L)) {
    expect_error(st_pk(keys = keys))
  }
  expect_error(st_pk(data.frame(id = c(1, 1)), "id", check_unique = TRUE),
               "not unique")
  expect_identical(st_pk(df[FALSE, ], "id", check_unique = TRUE), list(keys = "id"))
  expect_identical(st_pk(data.frame(id = c(NA, 1)), "id", check_unique = TRUE),
                   list(keys = "id"))
  expect_error(st_pk(data.frame(id = c(NA, NA)), "id", check_unique = TRUE),
               "not unique")
  marked <- st_with_pk(df, "id")
  expect_identical(st_get_pk(marked), "id")
  expect_identical(df, before)
  expect_identical(st_get_pk(df), character())
  expect_identical(st_get_pk(list(pk = list(keys = c("id", "label")))),
                   c("id", "label"))
  expect_identical(st_get_pk(1), character())
  expect_identical(st_get_pk(list(pk = list())), character())
  marked <- stamp:::st_set_pk(df, "id", domain = "audit")
  expect_identical(attr(marked, "stamp_domain"), "audit")
  expect_true(stamp:::st_assert_pk(marked))
  expect_true(stamp:::st_assert_pk(df))
  marked$id <- NULL
  expect_error(stamp:::st_assert_pk(marked), "missing columns")
  expect_error(stamp:::st_set_pk(data.frame(id = c(1, 1)), "id"), "not unique")
  expect_identical(st_get_pk(stamp:::st_set_pk(data.frame(id = c(1, 1)),
                                              "id", unique = FALSE)), "id")
})

test_that("filtering preserves values, classes, empty selections and input", {
  local_stamp_state()
  df <- data.frame(id = c(1L, 2L, NA_integer_),
                   kind = factor(c("a", "b", "a")))
  before <- df
  expect_identical(st_filter(df, list(id = 2L)), df[2L, , drop = FALSE])
  expect_identical(st_filter(df, list(id = NA_integer_)), df[3L, , drop = FALSE])
  expect_identical(st_filter(df, list(id = integer())), df[FALSE, , drop = FALSE])
  expect_identical(st_filter(df[FALSE, ], list(kind = "a")), df[FALSE, ])
  expect_error(st_filter(df, setNames(list(1), NA_character_)), "must be named")
  expect_error(st_filter(df, setNames(list(1), NA_character_), strict = FALSE),
               "must be named")
  expect_error(st_filter(df, 1), "named list")
  expect_identical(df, before)
  dt <- data.table::as.data.table(df)
  data.table::setkey(dt, id)
  dt_before <- data.table::copy(dt)
  selected <- st_filter(dt, list(id = 2L))
  expect_identical(selected$id, 2L)
  expect_identical(selected$kind, factor("b", levels = c("a", "b")))
  expect_identical(data.table::key(selected), "id")
  expect_equal(dt, dt_before)
})

test_that("PK inspection failure and metadata-only updates have explicit results", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td, verbose = FALSE)
  expect_identical(st_inspect_pk("missing.rds"), character())
  expect_identical(st_inspect_pk(NA_character_), character())
  expect_error(st_add_pk("missing.rds", "id"), "Artifact not found")
  expect_error(st_add_pk(NA_character_, "id"), "Could not determine")
  st_save(data.frame(id = 1:2), "a.rds")
  expect_identical(st_add_pk("a.rds", "id", validate = TRUE), "id")
  expect_identical(st_inspect_pk("a.rds"), "id")
  expect_identical(st_add_pk("a.rds", "absent", validate = FALSE), "absent")
  expect_identical(st_inspect_pk("a.rds"), "absent")
  writeLines("{invalid", stamp:::.st_sidecar_path("a.rds", "json"))
  expect_identical(st_inspect_pk("a.rds"), character())
  expect_identical(st_add_pk("a.rds", "id", validate = FALSE), "id")
  expect_identical(st_inspect_pk("a.rds"), "id")
})
