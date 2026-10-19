test_that("six builtin handlers have independent reader and writer assertions", {
  x <- data.frame(id = 1:3, value = c(1.25, NA_real_, -2.5),
                  label = c("alpha", "beta", "gamma"), flag = c(TRUE, FALSE, TRUE))
  native <- list(
    qs2 = list(read = qs2::qs_read, write = qs2::qs_save),
    rds = list(read = readRDS, write = saveRDS),
    csv = list(read = data.table::fread, write = data.table::fwrite),
    parquet = list(read = nanoparquet::read_parquet,
                   write = function(x, path) nanoparquet::write_parquet(x, path)),
    json = list(read = function(path) jsonlite::read_json(path, simplifyVector = TRUE),
                write = function(x, path) jsonlite::write_json(
                  x, path, auto_unbox = TRUE, digits = NA))
  )
  if (requireNamespace("fst", quietly = TRUE)) {
    native$fst <- list(read = fst::read_fst, write = fst::write_fst)
  }
  for (fmt in names(native)) {
    p <- withr::local_tempfile(fileext = paste0(".", fmt))
    h <- stamp:::.st_formats_env[[fmt]]
    h$write(x, p)
    actual <- as.data.frame(native[[fmt]]$read(p))
    expect_equal(actual, x, info = paste(fmt, "writer interoperability"))
    native[[fmt]]$write(x, p)
    actual <- as.data.frame(h$read(p))
    expect_equal(actual, x, info = paste(fmt, "reader interoperability"))
  }
})

test_that("RDS retains attributes while text formats promise only table values", {
  x <- data.frame(f = factor(c("a", "b"), levels = c("b", "a", "unused")),
                  d = as.Date(c("2020-01-01", "2020-01-02")),
                  row.names = c("row_a", "row_b"))
  attr(x, "note") <- "preserved in R serialization"
  p <- withr::local_tempfile()
  stamp:::.st_rds_write(x, p, compress = FALSE, version = 2L)
  expect_identical(readRDS(p), x)
  saveRDS(x, p, version = 2L)
  expect_identical(stamp:::.st_rds_read(p), x)
  stamp:::.st_csv_write(data.frame(a = c("a", "b"), b = 1:2), p, sep = ";")
  expect_identical(readLines(p), c("a;b", "a;1", "b;2"))
  expect_equal(as.data.frame(stamp:::.st_csv_read(p, sep = ";")),
               data.frame(a = c("a", "b"), b = 1:2))
})

test_that("optional fst absence is explicit and Imports are structural", {
  # Clone the handler environment so no namespace or registry mutation is needed.
  for (name in c(".st_fst_read", ".st_fst_write")) {
    fn <- get(name, asNamespace("stamp"))
    environment(fn) <- list2env(list(
      requireNamespace = function(package, quietly) FALSE
    ), parent = environment(fn))
    if (name == ".st_fst_read") {
      expect_error(fn("missing.fst"), "fst.*required.*read")
    } else {
      expect_error(fn(data.frame(a = 1), "missing.fst"), "fst.*required.*write")
    }
  }
  # DESCRIPTION Imports must be installed to load stamp; absence is not optional.
  desc <- utils::packageDescription("stamp")$Imports
  expect_match(desc, "qs2")
  expect_match(desc, "nanoparquet")
  expect_true(requireNamespace("qs2", quietly = TRUE))
  expect_true(requireNamespace("nanoparquet", quietly = TRUE))
})

test_that("all metadata representation transitions read the latest value", {
  local_stamp_state()
  local_st_opts()
  td <- withr::local_tempdir()
  st_init(td)
  expect_null(st_read_sidecar("absent.rds"))
  formats <- c("json", "qs2", "both")
  for (from in formats) {
    for (to in formats) {
      rel <- paste0(from, "-", to, ".rds")
      st_opts(meta_format = from)
      stamp:::.st_write_sidecar(rel, list(value = "old", n = 1L))
      st_opts(meta_format = to)
      expect_no_warning(stamp:::.st_write_sidecar(rel, list(value = "new", n = 2L)))
      expect_identical(st_read_sidecar(rel)$value, "new")
      expect_equal(st_read_sidecar(fs::path(td, rel))$n, 2)
      expect_identical(unname(fs::file_exists(stamp:::.st_sidecar_path(rel, "json"))),
                       to %in% c("json", "both"))
      expect_identical(unname(fs::file_exists(stamp:::.st_sidecar_path(rel, "qs2"))),
                       to %in% c("qs2", "both"))
      if (to %in% c("json", "both")) {
        expect_identical(jsonlite::read_json(
          stamp:::.st_sidecar_path(rel, "json"), simplifyVector = TRUE
        )$value, "new")
      }
      if (to %in% c("qs2", "both")) {
        expect_identical(qs2::qs_read(
          stamp:::.st_sidecar_path(rel, "qs2")
        )$value, "new")
      }
    }
  }
})

test_that("corrupt and divergent metadata is visible without changing JSON priority", {
  local_stamp_state()
  local_st_opts(meta_format = "both")
  td <- withr::local_tempdir()
  st_init(td)
  stamp:::.st_write_sidecar("dual.rds", list(value = "json"))
  scq <- stamp:::.st_sidecar_path("dual.rds", "qs2")
  scj <- stamp:::.st_sidecar_path("dual.rds", "json")
  qs2::qs_save(list(value = "qs2"), scq)
  expect_warning(meta <- st_read_sidecar("dual.rds"), "differs.*JSON.*QS2")
  expect_identical(meta$value, "json")
  writeLines("invalid qs2", scq)
  expect_warning(meta <- st_read_sidecar("dual.rds"), "QS2.*unreadable")
  expect_identical(meta$value, "json")
  fs::file_delete(scq)
  writeLines("{broken", scj)
  expect_error(st_read_sidecar("dual.rds"))
  fs::file_delete(scj)
  expect_null(st_read_sidecar("dual.rds"))
  writeLines("invalid qs2", scq)
  expect_error(st_read_sidecar("dual.rds"))
})

test_that("partition helper keys, formats and filters have exact assertions", {
  local_stamp_state()
  local_st_opts(default_format = "rds")
  expect_true(stamp:::.st_is_named_scalar_list(list(a = 1L, b = factor("x"))))
  for (bad in list(1, list(1), list(a = 1:2), list(a = list(1)))) {
    expect_false(stamp:::.st_is_named_scalar_list(bad))
  }
  expect_identical(stamp:::.st_key_normalize(list(b = TRUE, a = 2L)),
                   c(a = "2", b = "TRUE"))
  expect_identical(stamp:::.st_key_segments(list(b = "X", a = "x")),
                   c("a=x", "b=X"))
  expect_error(stamp:::.st_key_normalize(list(a = "a/b")), "cannot contain")
  expect_error(stamp:::.st_key_normalize(list(a = "a=b")), "cannot contain")
  expect_identical(stamp:::.st_guess_or_default_format("a.csv"), "csv")
  expect_identical(stamp:::.st_guess_or_default_format("a.csv", "rds"), "rds")
  expect_identical(stamp:::.st_guess_or_default_format("a.unknown"), "rds")
  expect_identical(stamp:::.st_file_basename_default("rds"), "part.rds")
  expect_true(all(c("qs2", "rds", "csv", "fst", "parquet", "json") %in%
                    stamp:::.st_known_exts()))
  expect_equal(stamp:::.st_parse_key_from_rel(
    "flag=TRUE/code=02020/ratio=1.5/year=2020/name=US/custom.rds"
  ), list(flag = TRUE, code = "02020", ratio = 1.5, year = 2020L, name = "US"))
  expect_identical(stamp:::.st_parse_key_from_rel("part.rds"), list())
  key <- list(country = "US", year = 2020L)
  expect_true(stamp:::.st_match_filter(key))
  expect_true(stamp:::.st_match_filter(key, filter_list = list(year = "2020")))
  expect_false(stamp:::.st_match_filter(key, filter_list = list(absent = 1)))
  expect_true(stamp:::.st_match_filter(key, quote(year >= 2020)))
  expect_false(stamp:::.st_match_filter(key, quote(c(TRUE, FALSE))))
  expect_false(stamp:::.st_match_filter(key, quote(NA)))
  expect_false(stamp:::.st_match_filter(key, quote("TRUE")))
  expect_false(stamp:::.st_match_filter(key, quote(absent > 1)))
})

test_that("custom filenames list logical paths and load physical payloads", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  base <- fs::path(td, "custom")
  p <- stamp:::st_part_path(base, list(country = "us"),
                           file = "custom.parquet", format = "parquet")
  st_save(data.frame(value = c(7L, 9L), extra = c("a", "b")), p,
          format = "parquet", verbose = FALSE)
  listing <- stamp:::st_list_parts(base)
  expect_identical(as.character(listing$path), as.character(p))
  expect_identical(listing$country, "us")
  physical <- fs::path(p, "custom.parquet")
  expect_true(fs::file_exists(physical))
  expect_identical(nanoparquet::read_parquet(physical)$value, c(7L, 9L))
  full <- stamp:::st_load_parts(base)
  projected <- stamp:::st_load_parts(base, columns = "value")
  expect_identical(full$value, c(7L, 9L))
  expect_identical(projected$value, c(7L, 9L))
  expect_identical(projected$country, c("us", "us"))
  expect_setequal(names(projected), c("value", "country"))
  expect_equal(nrow(stamp:::st_list_parts(base, recursive = FALSE)), 0L)
})

test_that("noncolumnar projection warns once and does not write globals", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  base <- fs::path(td, "rds")
  for (k in c("a", "b")) {
    stamp:::st_save_part(data.frame(value = 1:2, extra = 3:4), base,
                        list(k = k), format = "rds", verbose = FALSE)
  }
  before <- as.list(.GlobalEnv, all.names = TRUE)
  warnings <- character()
  x <- withCallingHandlers(stamp:::st_load_parts(base, columns = "value"),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_length(warnings, 1L)
  expect_match(warnings, "Column selection not supported")
  expect_equal(x$value, rep(1:2, 2))
  expect_setequal(names(x), c("value", "k"))
  expect_identical(as.list(.GlobalEnv, all.names = TRUE), before)
})

test_that("unreadable and missing listed partitions abort rather than lose rows", {
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  base <- fs::path(td, "parts")
  stamp:::st_save_part(data.frame(value = 1:2), base, list(k = "a"),
                      format = "parquet", verbose = FALSE)
  p <- stamp:::st_list_parts(base)$path[[1]]
  physical <- fs::path(p, fs::path_file(p))
  writeLines("not parquet", physical)
  expect_error(stamp:::st_load_parts(base), "Failed to load partition")
  expect_error(stamp:::st_load_parts(base, columns = "value"),
               "Failed to load partition")
  fs::file_delete(physical)
  expect_identical(stamp:::st_list_parts(base)$path, p)
  expect_error(stamp:::st_load_parts(base), "Failed to load partition")
  expect_error(stamp:::st_load_parts(base, columns = "value"),
               "Failed to load partition")
  fn <- stamp:::st_load_parts
  environment(fn) <- list2env(list(
    st_list_parts = function(...) data.frame(path = p, k = "a")
  ), parent = environment(fn))
  expect_error(fn(base), "Failed to load partition.*")
  expect_error(fn(base, columns = "value"), "Failed to load partition")
})

test_that("partition binding unions tables and retains non-table objects", {
  local_stamp_state()
  local_st_opts(default_format = "rds", warn_missing_pk_on_load = FALSE,
                verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  base <- fs::path(td, "union")
  stamp:::st_save_part(data.frame(a = 1L), base, list(k = "a"), verbose = FALSE)
  stamp:::st_save_part(data.frame(b = 2L), base, list(k = "b"), verbose = FALSE)
  x <- stamp:::st_load_parts(base)
  expect_identical(x$a, c(1L, NA_integer_))
  expect_identical(x$b, c(NA_integer_, 2L))
  expect_identical(x$k, c("a", "b"))
  other <- fs::path(td, "objects")
  stamp:::st_save_part(1:3, other, list(k = "x"), verbose = FALSE)
  object <- stamp:::st_load_parts(other)
  expect_identical(object$.object[[1]], 1:3)
  expect_identical(object$k, "x")
  missing <- fs::path(td, "absent")
  expect_identical(stamp:::st_list_parts(missing)$path, character())
  expect_identical(stamp:::st_load_parts(missing), data.frame())
  expect_equal(nrow(stamp:::st_load_parts(missing, as = "dt")), 0L)
})

test_that("interrupted sidecar transitions preserve a readable prior representation", {
  local_stamp_state()
  local_st_opts(meta_format = "json")
  td <- withr::local_tempdir()
  st_init(td)
  stamp:::.st_write_sidecar("item.rds", list(value = "old"))
  writer <- stamp:::.st_write_sidecar
  environment(writer) <- list2env(list(
    .st_write_qs2 = function(...) stop("injected QS2 failure")
  ), parent = environment(writer))
  st_opts(meta_format = "qs2")
  expect_error(writer("item.rds", list(value = "new")), "injected QS2 failure")
  expect_identical(st_read_sidecar("item.rds")$value, "old")
  st_opts(meta_format = "both")
  stamp:::.st_write_sidecar("dual.rds", list(value = "old"))
  expect_error(writer("dual.rds", list(value = "new")), "injected QS2 failure")
  expect_warning(meta <- st_read_sidecar("dual.rds"), "differs.*JSON.*QS2")
  expect_identical(meta$value, "new")
})

test_that("fst projection reads physical payloads and full rows agree", {
  skip_if_not_installed("fst")
  local_stamp_state()
  local_st_opts(warn_missing_pk_on_load = FALSE, verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  base <- fs::path(td, "fst")
  x <- data.frame(value = c(10L, 20L), extra = c("a", "b"))
  saved <- stamp:::st_save_part(x, base, list(k = "a"),
                               format = "fst", verbose = FALSE)
  physical <- fs::path(saved$path, fs::path_file(saved$path))
  expect_identical(fst::read_fst(physical), x)
  full <- stamp:::st_load_parts(base)
  projected <- stamp:::st_load_parts(base, columns = "value")
  expect_identical(projected$value, c(10L, 20L))
  expect_identical(projected, full[c("value", "k")])
})

test_that("unloadable partition keys produce warnings and no success manifest", {
  local_stamp_state()
  local_st_opts(versioning = "content")
  td <- withr::local_tempdir()
  st_init(td)
  warnings <- character()
  manifest <- withCallingHandlers(stamp:::st_write_parts(
    data.frame(k = "bad/value", value = 1L), fs::path(td, "bad"), "k",
    format = "rds", .progress = TRUE, verbose = FALSE
  ), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_length(warnings, 2L)
  expect_match(warnings[[1]], "Failed to save partition.*cannot contain")
  expect_match(warnings[[2]], "No partitions saved successfully")
  expect_equal(nrow(manifest), 0L)
  expect_length(manifest$path, 0L)
  base <- fs::path(td, "unchanged")
  first <- stamp:::st_save_part(data.frame(value = 1L), base, list(k = "a"),
                                format = "rds", verbose = FALSE)
  expect_no_error(skipped <- stamp:::st_save_part(
    data.frame(value = 1L), base, list(k = "a"), format = "rds", verbose = FALSE
  ))
  expect_identical(skipped$path, first$path)
  expect_null(skipped$version_id)
})

test_that("returned reader and writer wrappers propagate errors and messages", {
  read <- stamp:::.st_wrap_reader(function(path, token, ...) {
    message(token)
    if (path == "bad") stop("reader failure")
    list(path = path, dots = list(...))
  })
  expect_message(x <- read("good", token = "reader message", answer = 42L,
                            verbose = FALSE), "reader message")
  expect_identical(x, list(path = "good", dots = list(answer = 42L)))
  expect_error(suppressMessages(read("bad", token = "x", verbose = FALSE)),
               "reader failure")
  write <- stamp:::.st_wrap_writer(function(x, path, token, ...) {
    if (path == "bad") stop("writer failure")
    list(x = x, token = token, dots = list(...))
  })
  expect_identical(write(1L, "good", token = "write", answer = 23L),
                   list(x = 1L, token = "write", dots = list(answer = 23L)))
  expect_error(write(1L, "bad", token = "x", verbose = FALSE), "writer failure")
})

test_that("sidecar promotion and writer failures retain prior bytes and clean temps", {
  local_stamp_state()
  local_st_opts()
  td <- withr::local_tempdir()
  st_init(td)
  for (fmt in c("json", "qs2")) local({
    st_opts(meta_format = fmt)
    rel <- paste0("item-", fmt, ".rds")
    stamp:::.st_write_sidecar(rel, list(value = "old"))
    p <- stamp:::.st_sidecar_path(rel, fmt)
    old <- readBin(p, "raw", n = file.info(p)$size)
    before <- fs::dir_ls(fs::path_dir(p))
    local_audit_binding("file_move", function(...) {
      stop("injected sidecar promotion failure")
    }, env = asNamespace("fs"))
    expect_error(stamp:::.st_write_sidecar(rel, list(value = "new")),
                 "injected sidecar promotion failure")
    expect_identical(readBin(p, "raw", n = file.info(p)$size), old)
    expect_identical(fs::dir_ls(fs::path_dir(p)), before)
    expect_identical(st_read_sidecar(rel)$value, "old")
  })
  st_opts(meta_format = "qs2")
  stamp:::.st_write_sidecar("writer.rds", list(value = "old"))
  p <- stamp:::.st_sidecar_path("writer.rds", "qs2")
  before <- fs::dir_ls(fs::path_dir(p))
  writer <- stamp:::.st_write_sidecar
  environment(writer) <- list2env(list(
    .st_write_qs2 = function(x, path) {
      writeLines("partial temporary output", path)
      stop("injected partial writer failure")
    }
  ), parent = environment(writer))
  expect_error(writer("writer.rds", list(value = "new")),
               "injected partial writer failure")
  expect_identical(st_read_sidecar("writer.rds")$value, "old")
  expect_identical(fs::dir_ls(fs::path_dir(p)), before)
})

test_that("sidecar warnings stay visible directly and obey quiet current loads", {
  local_stamp_state()
  local_st_opts(meta_format = "both", warn_missing_pk_on_load = FALSE,
                verify_on_load = FALSE)
  td <- withr::local_tempdir()
  st_init(td)
  p <- fs::path(td, "item.rds")
  st_save(data.frame(value = 1L), p, verbose = FALSE)
  meta <- st_read_sidecar(p)
  meta$code_label <- "divergent"
  qs2::qs_save(meta, stamp:::.st_sidecar_path("item.rds", "qs2"))
  expect_warning(st_read_sidecar(p), "differs.*JSON.*QS2")
  expect_no_warning(x <- st_load(p, verbose = FALSE))
  expect_identical(x$value, 1L)
})

test_that("failed partition writers cannot produce a successful manifest", {
  local_stamp_state()
  local_st_opts()
  td <- withr::local_tempdir()
  st_init(td)
  st_register_format("audit_fail", readRDS, function(...) stop("writer failed"))
  expect_error(stamp:::st_save_part(
    data.frame(value = 1L), fs::path(td, "one"), list(k = "a"),
    format = "audit_fail", verbose = FALSE
  ), "Failed to save partition")
  warnings <- character()
  manifest <- withCallingHandlers(stamp:::st_write_parts(
    data.frame(k = "a", value = 1L), fs::path(td, "many"), "k",
    format = "audit_fail", .progress = FALSE, verbose = FALSE
  ), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_length(warnings, 2L)
  expect_match(warnings[[1]], "Failed to save partition")
  expect_equal(nrow(manifest), 0L)
  expect_length(manifest$path, 0L)
})
