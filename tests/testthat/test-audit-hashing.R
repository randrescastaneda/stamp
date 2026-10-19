test_that("NULL and empty objects have deterministic distinct object hashes", {
  expect_null(stamp:::st_sanitize_for_hash(NULL))
  expect_identical(st_hash_obj(NULL),
    secretbase::siphash13(serialize(NULL, NULL, version = 3)))
  objects <- list(NULL, integer(), numeric(), character(), list(), data.frame())
  hashes <- vapply(objects, st_hash_obj, character(1))
  expect_length(unique(hashes), length(objects))
  expect_identical(hashes, vapply(objects, st_hash_obj, character(1)))
  expect_true(all(grepl("^[0-9a-f]{16}$", hashes)))
})

test_that("sanitizer output matches an independently constructed stored frame", {
  original <- data.frame(id = 1:2, label = c("a", "b"),
    row.names = c("west", "east"))
  attr(original, "domain") <- "audit"
  attr(original, "pk") <- "id"
  expected <- structure(list(id = 1:2, label = c("a", "b")),
    names = c("id", "label"), row.names = 1:2,
    class = "data.frame", domain = "audit", pk = "id",
    st_original_format = "data.frame",
    st_original_rownames = c("west", "east"), stamp_sanitized = TRUE)
  sanitized <- stamp:::st_sanitize_for_hash(original)
  expect_equal(sanitized, expected)
  expect_identical(st_hash_obj(original),
    secretbase::siphash13(serialize(expected, NULL, version = 3)))
  expect_identical(rownames(original), c("west", "east"))
  expect_null(attr(original, "stamp_sanitized"))
  expect_identical(stamp:::st_sanitize_for_hash(sanitized), sanitized)
})

test_that("reader restores a hand-built stored fixture without its writer", {
  stored <- structure(list(
    id = 1:2,
    category = factor(c("b", "a"), levels = c("a", "b", "unused")),
    date = as.Date(c("2026-01-01", "2026-01-02")),
    items = list(1:2, NULL)),
    row.names = c(NA_integer_, -2L), class = "data.frame",
    st_original_format = "data.frame",
    st_original_rownames = c("north", "south"), stamp_sanitized = TRUE,
    domain = list(unit = "household"), pk = "id")
  before <- stored
  restored <- stamp:::.st_restore_sanitized_object(stored)
  expect_identical(restored$id, 1:2)
  expect_identical(restored$category,
    factor(c("b", "a"), levels = c("a", "b", "unused")))
  expect_identical(restored$date,
    as.Date(c("2026-01-01", "2026-01-02")))
  expect_identical(restored$items, list(1:2, NULL))
  expect_identical(rownames(restored), c("north", "south"))
  expect_identical(class(restored), "data.frame")
  expect_identical(attr(restored, "domain"), list(unit = "household"))
  expect_identical(attr(restored, "pk"), "id")
  expect_null(attr(restored, "stamp_sanitized"))
  expect_null(attr(restored, "st_original_format"))
  expect_null(attr(restored, "st_original_rownames"))
  expect_identical(stored, before)
})

test_that("normalization preserves values and classes with exact attr order", {
  x <- structure(list(id = 1:2), zeta = 9L, alpha = "domain",
    class = c("audit_frame", "data.frame"), row.names = c("a", "b"))
  before <- x
  normalized <- stamp:::st_normalize_attrs(x)
  expect_identical(names(attributes(normalized)),
    c("names", "row.names", "class", "alpha", "zeta"))
  expect_identical(normalized$id, 1:2)
  expect_identical(class(normalized), c("audit_frame", "data.frame"))
  expect_identical(rownames(normalized), c("a", "b"))
  expect_identical(attr(normalized, "alpha"), "domain")
  expect_identical(x, before)
  expect_identical(stamp:::st_normalize_attrs(normalized), normalized)
  expect_error(stamp:::st_normalize_attrs(data.table::data.table(id = 1)),
    "require sanitation")
  expect_false(stamp:::.st_is_dt(x))
  expect_true(stamp:::.st_is_dt(data.table::data.table(id = 1)))
})

test_that("normalizer handles lists atomic classes and its explicit S4 fallback", {
  x <- structure(list(a = 1L, b = NULL), zeta = 2L, alpha = 1L,
    class = "audit_list")
  expected <- structure(list(a = 1L, b = NULL), class = "audit_list",
    alpha = 1L, zeta = 2L)
  expect_identical(stamp:::st_normalize_attrs(x), expected)
  expect_identical(st_hash_obj(x), st_hash_obj(expected))
  f <- factor(c("b", "a"), levels = c("b", "a"), ordered = TRUE)
  expect_identical(stamp:::st_normalize_attrs(f), f)
  s4 <- methods::new("classRepresentation")
  expect_warning(normalized <- stamp:::st_normalize_attrs(s4),
    "S4 objects cannot be normalized")
  expect_identical(normalized, s4)
})

test_that("object hash retains row column type and metadata distinctions", {
  x <- data.frame(id = 1:2,
    category = factor(c("a", "b"), levels = c("a", "b")),
    date = as.Date(c("2026-01-01", "2026-01-02")))
  x$items <- list(1:2, NULL)
  attr(x, "pk") <- "id"
  attr(x, "domain") <- "household"
  before <- x
  variants <- list(x[2:1, ], x[c(2, 1, 3, 4)])
  y <- x
  y$category <- factor(c("a", "b"), levels = c("b", "a"))
  variants[[3]] <- y
  y <- x
  y$date <- as.numeric(y$date)
  variants[[4]] <- y
  y <- x
  y$items <- list(1:2, integer())
  variants[[5]] <- y
  y <- x
  attr(y, "pk") <- "category"
  variants[[6]] <- y
  y <- x
  attr(y, "domain") <- "person"
  variants[[7]] <- y
  y <- x
  rownames(y) <- c("west", "east")
  variants[[8]] <- y
  y <- x
  y$id <- as.numeric(y$id)
  variants[[9]] <- y
  h <- st_hash_obj(x)
  expect_true(all(vapply(variants, st_hash_obj, character(1)) != h))
  expect_identical(x, before)
})

test_that("default rowname encodings are equivalent but custom names persist", {
  x <- data.frame(id = 1:2)
  y <- x
  attr(y, "row.names") <- c("1", "2")
  expect_false(stamp:::.st_has_custom_rownames(y))
  expect_identical(st_hash_obj(x), st_hash_obj(y))
  expect_false(stamp:::.st_has_custom_rownames(list()))
  expect_false(stamp:::.st_has_custom_rownames(data.frame(id = integer())))
  rownames(y) <- c("2", "1")
  expect_true(stamp:::.st_has_custom_rownames(y))
  expect_false(identical(st_hash_obj(x), st_hash_obj(y)))
})

test_that("DT internals and keys are excluded but original DT format remains", {
  dt <- data.table::data.table(id = 1:2, value = c("a", "b"))
  keyed <- data.table::copy(dt)
  data.table::setkey(keyed, id)
  before <- data.table::copy(keyed)
  expect_identical(st_hash_obj(dt), st_hash_obj(keyed))
  expect_false(identical(st_hash_obj(dt), st_hash_obj(as.data.frame(dt))))
  sanitized <- stamp:::st_sanitize_for_hash(keyed)
  expect_identical(class(sanitized), "data.frame")
  expect_null(attr(sanitized, ".internal.selfref"))
  expect_null(attr(sanitized, "sorted"))
  expect_identical(attr(sanitized, "st_original_format"),
    c("data.table", "data.frame"))
  expect_identical(keyed, before)
})

test_that("restoration does not mutate a caller's partially sanitized DT", {
  stored <- data.table::data.table(id = 1:3, value = letters[1:3])
  data.table::setkey(stored, id)
  data.table::setattr(stored, "stamp_sanitized", TRUE)
  data.table::setattr(stored, "domain", "audit")
  before <- data.table::copy(stored)
  restored <- stamp:::.st_restore_sanitized_object(stored)
  expect_identical(stored, before)
  expect_identical(restored$id, 1:3)
  expect_identical(restored$value, letters[1:3])
  expect_identical(data.table::key(restored), "id")
  expect_identical(attr(restored, "domain"), "audit")
  expect_null(attr(restored, "stamp_sanitized"))
})

test_that("atomic classes and list attrs survive sanitation and restoration", {
  objects <- list(
    factor(c("b", NA), levels = c("a", "b"), ordered = TRUE),
    as.Date(c("2026-01-01", NA)),
    as.POSIXct("2026-01-01", tz = "UTC"),
    structure(list(a = 1L, b = NULL), domain = "audit", class = "audit_list")
  )
  for (x in objects) {
    before <- x
    expect_identical(stamp:::.st_restore_sanitized_object(
      stamp:::st_sanitize_for_hash(x)), before)
    expect_identical(x, before)
  }
  expect_null(stamp:::.st_restore_sanitized_object(NULL))
})

test_that("code hashing matches independent text normalization and distinctions", {
  expect_identical(stamp:::st_hash_code("x\t <-  1\r\ny <- 2\r"),
    secretbase::siphash13("x <- 1\ny <- 2\n"))
  expect_identical(stamp:::st_hash_code(c("x <- 1", "y <- 2")),
    stamp:::st_hash_code("x <- 1\ny <- 2"))
  expect_identical(stamp:::st_hash_code(quote(x + 1)),
    secretbase::siphash13("x + 1"))
  expect_identical(stamp:::st_hash_code(expression(x + 1)),
    secretbase::siphash13("expression(x + 1)"))
  expect_false(identical(stamp:::st_hash_code(function(x = 1) x + 1),
    stamp:::st_hash_code(function(x = 2) x + 1)))
  expect_false(identical(stamp:::st_hash_code(function(x) x + 1),
    stamp:::st_hash_code(function(x) x + 2)))
  # Deliberate persisted tradeoff: whitespace inside strings is collapsed too.
  expect_identical(stamp:::st_hash_code('"a  b"'),
    stamp:::st_hash_code('"a b"'))
  expect_identical(stamp:::st_hash_code(NULL), secretbase::siphash13(""))
  expect_identical(stamp:::st_hash_code(character()),
    secretbase::siphash13(""))
})

test_that("file hashing uses bytes and not the object or code representation", {
  path <- withr::local_tempfile()
  bytes <- as.raw(c(0, 1, 13, 10, 255))
  writeBin(bytes, path)
  expect_identical(stamp:::st_hash_file(path), secretbase::siphash13(bytes))
  expect_false(identical(stamp:::st_hash_file(path), st_hash_obj(bytes)))
  writeBin(raw(), path)
  expect_identical(stamp:::st_hash_file(path), secretbase::siphash13(raw()))
  expect_error(stamp:::st_hash_file(paste0(path, "-absent")))
})

test_that("change detection reports independent content code and file reasons", {
  local_stamp_state()
  local_st_opts(code_hash = TRUE, store_file_hash = TRUE,
    meta_format = "json", default_format = "rds")
  root <- withr::local_tempdir()
  st_init(root)
  norm <- stamp:::.st_normalize_user_path("fixture.rds", must_exist = FALSE)
  missing <- st_changed("fixture.rds", 1L)
  expect_identical(missing, list(changed = TRUE, reason = "missing_artifact",
    details = list(missing_artifact = TRUE)))
  fs::dir_create(fs::path_dir(norm$storage_path))
  bytes <- as.raw(c(1, 2, 3))
  writeBin(bytes, norm$storage_path)
  expect_identical(st_changed("fixture.rds", 1L),
    list(changed = TRUE, reason = "missing_meta",
      details = list(missing_meta = TRUE)))
  sidecar <- stamp:::.st_sidecar_path("fixture.rds", "json")
  fs::dir_create(fs::path_dir(sidecar))
  # This fixture is not written by st_save or .st_write_sidecar.
  content_hash <- secretbase::siphash13(serialize(structure(1L,
    st_original_format = "integer", stamp_sanitized = TRUE),
    NULL, version = 3))
  jsonlite::write_json(list(content_hash = content_hash,
    code_hash = secretbase::siphash13("x <- 1"),
    file_hash = secretbase::siphash13(bytes)), sidecar, auto_unbox = TRUE)
  same <- st_changed("fixture.rds", 1L, "x <- 1")
  expect_identical(same, list(changed = FALSE, reason = "no_change",
    details = list(content_changed = FALSE, code_changed = FALSE,
      file_changed = FALSE)))
  changed <- st_changed("fixture.rds", 2L, "x <- 2")
  expect_identical(changed$reason, "content+code")
  expect_identical(changed$details, list(content_changed = TRUE,
    code_changed = TRUE, file_changed = FALSE))
  expect_true(st_changed("fixture.rds", 2L, mode = "content")$changed)
  expect_true(st_changed("fixture.rds", code = "x <- 2", mode = "code")$changed)
  writeBin(as.raw(4), norm$storage_path)
  expect_identical(st_changed("fixture.rds", 2L, "x <- 2")$reason,
    "content+code+file")
  file_only <- st_changed("fixture.rds", 1L, "x <- 1", mode = "file")
  expect_true(file_only$changed)
  expect_identical(file_only$reason, "file")
  # Reason lists observed differences, even when mode selects another component.
  ignored <- st_changed("fixture.rds", 2L, "x <- 1", mode = "code")
  expect_false(ignored$changed)
  expect_identical(ignored$reason, "content+file")
  for (mask in 0:7) {
    flags <- as.logical(intToBits(mask)[1:3])
    writeBin(if (flags[3]) as.raw(4) else bytes, norm$storage_path)
    result <- st_changed("fixture.rds", if (flags[1]) 2L else 1L,
      if (flags[2]) "x <- 2" else "x <- 1")
    parts <- c("content", "code", "file")[flags]
    expect_identical(result$changed, any(flags))
    expect_identical(result$reason,
      if (length(parts)) paste(parts, collapse = "+") else "no_change")
    expect_identical(result$details, setNames(as.list(flags),
      c("content_changed", "code_changed", "file_changed")))
  }
  jsonlite::write_json(list(), sidecar, auto_unbox = TRUE)
  expect_identical(st_changed("fixture.rds", 1L, "x <- 1")$details,
    list(content_changed = TRUE, code_changed = TRUE, file_changed = NA))
  st_opts(code_hash = FALSE, store_file_hash = FALSE)
  expect_identical(st_changed("fixture.rds")$details,
    list(content_changed = NA, code_changed = NA, file_changed = NA))
  expect_error(st_changed("fixture.rds", mode = "invalid"))
  writeLines("{broken", sidecar)
  expect_identical(st_changed("fixture.rds")$reason, "missing_meta")
})
