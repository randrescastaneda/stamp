test_that("reference copy defaults, reset, and validation are atomic", {
  local_stamp_state()
  st_opts_reset()
  expect_identical(st_opts("reference_copy_on_save", .get = TRUE), FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  expect_true(st_opts("reference_copy_on_save", .get = TRUE))
  st_opts_reset()
  expect_false(st_opts("reference_copy_on_save", .get = TRUE))
  before <- st_opts(.get = TRUE)
  for (flag in list(NULL, NA, logical(), c(TRUE, FALSE), 1L, "TRUE")) {
    expect_error(st_opts(default_format = "csv", reference_copy_on_save = flag),
                 "reference_copy_on_save")
    expect_identical(st_opts(.get = TRUE), before)
  }
})

test_that("native RDS save uses one owned copy and preserves legacy hash", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = FALSE)
  fixture <- function() {
    x <- new.env(parent = emptyenv())
    x$value <- 1:3
    attr(x, "z") <- "last"
    attr(x, "a") <- "first"
    x
  }
  legacy <- fixture()
  legacy_saved <- st_save(legacy, "legacy.rds", verbose = FALSE)
  expect_type(legacy_saved$version_id, "character")
  expect_true(attr(legacy, "stamp_sanitized"))
  x <- fixture()
  before <- serialize(x, NULL, version = 3)
  attrs_before <- attributes(x)
  local_st_opts(reference_copy_on_save = TRUE)
  copies <- 0L
  owned <- NULL
  original_copy <- stamp:::.st_reference_copy_for_save
  local_audit_binding(".st_reference_copy_for_save", function(x, fmt, handler) {
    copies <<- copies + 1L
    owned <<- original_copy(x, fmt, handler)
    owned
  })
  original_decision <- st_should_save
  local_audit_binding("st_should_save", function(path, x, code, alias) {
    expect_identical(x, owned)
    expect_false(identical(x, legacy))
    original_decision(path, x = x, code = code, alias = alias)
  })
  original_sanitize <- stamp:::st_sanitize_for_hash
  local_audit_binding("st_sanitize_for_hash", function(value) {
    if (is.environment(value)) expect_identical(value, owned)
    original_sanitize(value)
  })
  saved <- st_save(x, "pilot.rds", verbose = FALSE)
  expect_identical(copies, 1L)
  expect_false(identical(owned, x))
  expect_identical(saved$metadata$content_hash,
                   legacy_saved$metadata$content_hash)
  expect_identical(readRDS(stamp:::.st_artifact_path("pilot.rds"))$value, 1:3)
  expect_identical(attributes(x), attrs_before)
  expect_identical(serialize(x, NULL, version = 3), before)
})

test_that("copy preserves cycles, shared children, and ordinary parents", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  parent <- new.env(parent = emptyenv())
  parent$number <- 8L
  x <- new.env(parent = parent)
  child <- new.env(parent = parent)
  child$value <- 2L
  x$self <- x
  x$left <- child
  x$right <- child
  x$parent_alias <- parent
  attr(x, "note") <- "caller"
  before <- serialize(x, NULL, version = 3)
  owned <- stamp:::.st_reference_copy_for_save(
    x, "rds", rlang::env_get(stamp:::.st_formats_env, "rds"))
  expect_false(identical(owned, x))
  expect_identical(owned$self, owned)
  expect_identical(owned$left, owned$right)
  expect_false(identical(owned$left, child))
  expect_identical(owned$parent_alias, parent.env(owned))
  expect_identical(parent.env(owned$left), parent.env(owned))
  expect_false(identical(parent.env(owned), parent))
  saved <- st_save(x, "graph.rds", verbose = FALSE)
  expect_type(saved$version_id, "character")
  payload <- readRDS(stamp:::.st_artifact_path("graph.rds"))
  expect_identical(payload$self, payload)
  expect_identical(payload$left, payload$right)
  expect_identical(payload$parent_alias, parent.env(payload))
  expect_identical(serialize(x, NULL, version = 3), before)
  expect_identical(x$self, x)
  expect_identical(x$left, child)
  expect_identical(parent.env(x), parent)
})

test_that("unchanged copies skip and changed copies replace normally", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE, versioning = "content")
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  first <- st_save(x, "value.rds", verbose = FALSE)
  expect_type(first$version_id, "character")
  files <- list.files(root, recursive = TRUE, all.files = TRUE,
                      full.names = TRUE)
  before <- tools::md5sum(files)
  skipped <- st_save(x, "value.rds", verbose = FALSE)
  expect_true(skipped$skipped)
  expect_identical(tools::md5sum(files), before)
  expect_equal(nrow(st_versions("value.rds")), 1L)
  x$value <- 2L
  changed <- st_save(x, "value.rds", verbose = FALSE)
  expect_type(changed$version_id, "character")
  expect_false(identical(changed$version_id, first$version_id))
  expect_identical(readRDS(stamp:::.st_artifact_path("value.rds"))$value, 2L)
  expect_equal(nrow(st_versions("value.rds")), 2L)
  expect_null(attributes(x))
})

test_that("default off and direct hashing retain legacy mutation behavior", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_opts_reset()
  local_audit_binding(".st_reference_copy_for_save", function(...) {
    stop("copy must not run")
  })
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  expect_type(st_save(x, "legacy.rds", verbose = FALSE)$version_id, "character")
  expect_true(attr(x, "stamp_sanitized"))
  local_st_opts(reference_copy_on_save = TRUE)
  direct <- new.env(parent = emptyenv())
  direct$value <- 1L
  expect_type(st_hash_obj(direct), "character")
  expect_true(attr(direct, "stamp_sanitized"))
  candidate <- new.env(parent = emptyenv())
  candidate$value <- 2L
  expect_true(st_changed("legacy.rds", x = candidate)$changed)
  expect_true(attr(candidate, "stamp_sanitized"))
})

test_that("non-environment saves do not enter the pilot", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  local_audit_binding(".st_reference_copy_for_save", function(...) {
    stop("copy must not run")
  })
  values <- list(data.frame(value = 1:2), data.table::data.table(value = 1:2),
                 NULL, 1:2, list(value = 1L))
  for (i in seq_along(values)) {
    x <- values[[i]]
    before <- serialize(x, NULL, version = 3)
    path <- paste0("ordinary", i, ".rds")
    saved <- st_save(x, path, verbose = FALSE)
    expect_type(saved$version_id, "character")
    expect_identical(serialize(x, NULL, version = 3), before)
    expect_identical(st_load(path, verbose = FALSE), x)
  }
  expect_type(st_save(data.frame(value = 1L), "ordinary.csv", verbose = FALSE)$version_id,
              "character")
})

test_that("default-off classed environment failures keep the legacy fallback", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_opts_reset()
  local_audit_binding(".st_reference_copy_for_save", function(...) {
    stop("copy must not run")
  })
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  class(x) <- "legacy_classed"
  expect_warning(saved <- st_save(x, "legacy.rds"), "Returning fallback")
  expect_null(saved$metadata)
  expect_null(saved$version_id)
  expect_true(attr(x, "stamp_sanitized"))
  expect_true(file.exists(stamp:::.st_artifact_path("legacy.rds")))
})

test_that("special roots and binding values fail before sanitizing or writing", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  st_save(1L, "kept.rds", verbose = FALSE)
  files <- list.files(root, recursive = TRUE, all.files = TRUE,
                      full.names = TRUE)
  before <- tools::md5sum(files)
  local_audit_binding("st_sanitize_for_hash", function(...) {
    stop("sanitizer must not run")
  })
  local_audit_binding("st_hash_obj", function(...) stop("hash must not run"))
  specials <- list(globalenv(), baseenv(), emptyenv(), asNamespace("stamp"),
                    as.environment("package:base"))
  for (special in specials) {
    attrs_before <- attributes(special)
    expect_error(st_save(special, "kept.rds", verbose = FALSE,
                         metadata = stop("metadata must not run")),
                 class = "stamp_reference_copy_unsupported")
    expect_identical(attributes(special), attrs_before)
    x <- new.env(parent = emptyenv())
    x$special <- special
    expect_error(st_save(x, "new.rds", verbose = FALSE),
                 "special environments")
    expect_null(attributes(x))
  }
  expect_identical(list.files(root, recursive = TRUE, all.files = TRUE,
                              full.names = TRUE), files)
  expect_identical(tools::md5sum(files), before)
})

test_that("special parent boundaries are retained without traversal", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  for (parent in list(emptyenv(), globalenv(), baseenv(), asNamespace("stamp"),
                       as.environment("package:base"))) {
    x <- new.env(parent = parent)
    x$value <- 3L
    owned <- stamp:::.st_reference_copy_for_save(
      x, "rds", rlang::env_get(stamp:::.st_formats_env, "rds"))
    expect_false(identical(owned, x))
    expect_identical(parent.env(owned), parent)
    expect_null(attributes(x))
  }
})

test_that("promises and active bindings are declined without forcing", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  counter <- 0L
  lazy <- new.env(parent = emptyenv())
  delayedAssign("sentinel", { counter <<- counter + 1L; 1L },
                assign.env = lazy)
  active <- new.env(parent = emptyenv())
  makeActiveBinding("sentinel", function(value) {
    counter <<- counter + 1L
    1L
  }, active)
  for (x in list(lazy, active)) {
    expect_error(st_save(x, "unsafe.rds", verbose = FALSE),
                 "promise bindings|active bindings")
    expect_identical(counter, 0L)
    expect_null(attributes(x))
  }
  expect_true(rlang::env_binding_are_lazy(lazy, "sentinel"))
  expect_true(bindingIsActive("sentinel", active))
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("opaque bindings and classed environments are declined", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  connection <- rawConnection(raw(), "rb")
  withr::defer(close(connection))
  values <- list(function() 1L, list(value = 1L),
                 methods::new("classRepresentation"),
                 methods::new("externalptr"), connection, quote(value))
  for (value in values) {
    x <- new.env(parent = emptyenv())
    x$opaque <- value
    expect_error(st_save(x, "opaque.rds", verbose = FALSE),
                 class = "stamp_reference_copy_unsupported")
    expect_null(attributes(x))
    expect_identical(x$opaque, value)
  }
  classed <- new.env(parent = emptyenv())
  class(classed) <- "classed"
  r6 <- new.env(parent = emptyenv())
  class(r6) <- c("PilotFixture", "R6")
  nested <- new.env(parent = emptyenv())
  nested$child <- classed
  for (x in list(classed, r6, nested)) {
    attrs_before <- attributes(x)
    expect_error(st_save(x, "classed.rds", verbose = FALSE),
                 "classed environments")
    expect_identical(attributes(x), attrs_before)
  }
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("unsafe nested environments and ordinary parents are inspected", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  counter <- 0L
  lazy <- new.env(parent = emptyenv())
  delayedAssign("sentinel", { counter <<- counter + 1L; 1L },
                assign.env = lazy)
  active <- new.env(parent = emptyenv())
  makeActiveBinding("sentinel", function(value) {
    counter <<- counter + 1L
    1L
  }, active)
  classed <- new.env(parent = emptyenv())
  class(classed) <- "unsafe_parent"
  for (unsafe in list(lazy, active, classed)) {
    for (as_parent in c(FALSE, TRUE)) {
      x <- new.env(parent = if (as_parent) unsafe else emptyenv())
      if (!as_parent) x$child <- unsafe
      expect_error(st_save(x, "nested.rds", verbose = FALSE,
                           metadata = stop("metadata must not run")),
                   class = "stamp_reference_copy_unsupported")
      expect_identical(counter, 0L)
      expect_null(attributes(x))
    }
  }
  expect_true(rlang::env_binding_are_lazy(lazy, "sentinel"))
  expect_true(bindingIsActive("sentinel", active))
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("atomic attributes are accepted but reference attributes are not", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  x <- new.env(parent = emptyenv())
  x$value <- structure(1:2, label = "simple")
  x$nothing <- NULL
  x$logical <- c(TRUE, NA)
  x$double <- c(1.5, NA_real_)
  x$complex <- 1 + 2i
  x$raw <- as.raw(c(0, 255))
  x$matrix <- matrix(1:4, 2L)
  attr(x, "note") <- "simple"
  expect_type(st_save(x, "atomic.rds", verbose = FALSE)$version_id, "character")
  for (value in list(list(1L), new.env(parent = emptyenv()), function() 1L)) {
    attr(x, "unsafe") <- value
    before <- attributes(x)
    expect_error(st_save(x, "unsafe.rds", verbose = FALSE),
                 class = "stamp_reference_copy_unsupported")
    expect_identical(attributes(x), before)
  }
})

test_that("non-native formats decline environments without side effects", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  for (format in c("qs2", "csv", "fst", "json", "parquet")) {
    expect_error(st_save(x, paste0("unsafe.", format), format = format,
                         verbose = FALSE), "only the native RDS writer")
    expect_null(attributes(x))
  }
  calls <- 0L
  suppressMessages(st_register_format("rds", readRDS, function(x, path, ...) {
    calls <<- calls + 1L
    saveRDS(x, path)
  }))
  expect_error(st_save(x, "unsafe.rds", verbose = FALSE),
               "only the native RDS writer")
  expect_identical(calls, 0L)
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("normal validation precedes the copy boundary", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  local_audit_binding(".st_reference_copy_for_save", function(...) {
    stop("copy must not run")
  })
  x <- new.env(parent = emptyenv())
  expect_error(st_save(x, "value.rds", pk = "id", verbose = FALSE),
               "not a data.frame")
  expect_error(st_save(x, "value.rds", format = "unknown", verbose = FALSE),
               "Unknown format")
  expect_error(st_save(x, "../outside.rds", verbose = FALSE))
  expect_null(attributes(x))
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("graph node and depth limits fail before save side effects", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  deep <- new.env(parent = emptyenv())
  for (i in seq_len(66L)) deep <- new.env(parent = deep)
  wide <- new.env(parent = emptyenv())
  for (i in seq_len(10001L)) assign(paste0("v", i), i, envir = wide)
  for (x in list(deep, wide)) {
    expect_error(st_save(x, "limited.rds", verbose = FALSE),
                 "10000-node or 64-level limit")
    expect_null(attributes(x))
  }
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("serialization failures and retained root identity do not fall back", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  original <- stamp:::.st_reference_copy_for_save
  failing <- original
  environment(failing) <- list2env(list(serialize = function(...) {
    stop("injected serialization failure")
  }), parent = environment(original))
  retaining <- original
  environment(retaining) <- list2env(list(unserialize = function(...) x),
                                     parent = environment(original))
  for (copy in list(failing, retaining)) {
    local({
      local_audit_binding(".st_reference_copy_for_save", copy)
      expect_error(st_save(x, "failure.rds", verbose = FALSE),
                   class = "stamp_reference_copy_unsupported")
    })
    expect_null(attributes(x))
    expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
  }
})

test_that("ordinary locked environment ownership and locks are preserved", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  x <- new.env(parent = emptyenv())
  x$value <- 1L
  lockBinding("value", x)
  lockEnvironment(x)
  attrs_before <- attributes(x)
  saved <- st_save(x, "locked.rds", verbose = FALSE)
  expect_type(saved$version_id, "character")
  expect_true(environmentIsLocked(x))
  expect_true(bindingIsLocked("value", x))
  expect_identical(attributes(x), attrs_before)
  payload <- readRDS(stamp:::.st_artifact_path("locked.rds"))
  expect_false(identical(payload, x))
  expect_true(environmentIsLocked(payload))
  expect_true(bindingIsLocked("value", payload))
  expect_identical(payload$value, 1L)
})

test_that("namespace marker bindings are rejected without evaluation", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  counter <- 0L
  serializations <- 0L
  guarded <- stamp:::.st_reference_copy_for_save
  environment(guarded) <- list2env(list(serialize = function(...) {
    serializations <<- serializations + 1L
    stop("marker must not reach serialization")
  }), parent = environment(guarded))
  local_audit_binding(".st_reference_copy_for_save", guarded)
  for (kind in c("active", "lazy")) {
    for (position in c("root", "child", "parent")) {
      marked <- new.env(parent = emptyenv())
      if (kind == "active") {
        makeActiveBinding(".__NAMESPACE__.", function(value) {
          counter <<- counter + 1L
          new.env(parent = emptyenv())
        }, marked)
      } else {
        delayedAssign(".__NAMESPACE__.", {
          counter <<- counter + 1L
          new.env(parent = emptyenv())
        }, assign.env = marked)
      }
      x <- switch(position,
        root = marked,
        child = new.env(parent = emptyenv()),
        parent = new.env(parent = marked)
      )
      if (position == "child") x$child <- marked
      expect_error(st_save(x, "marker.rds", verbose = FALSE,
                           metadata = stop("metadata must not run")),
                   class = "stamp_reference_copy_unsupported")
      expect_identical(counter, 0L)
      expect_identical(serializations, 0L)
      expect_null(attributes(x))
      expect_null(attributes(marked))
      if (kind == "active") {
        expect_true(bindingIsActive(".__NAMESPACE__.", marked))
      } else {
        expect_true(rlang::env_binding_are_lazy(marked, ".__NAMESPACE__."))
      }
      expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
    }
  }
})

test_that("counterfeit namespace and package environments cannot be copied", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  namespace <- asNamespace("stats")
  package <- as.environment("package:base")
  namespace_attrs <- attributes(namespace)
  package_attrs <- attributes(package)
  marker <- get(".__NAMESPACE__.", envir = namespace, inherits = FALSE)
  fake_namespace <- new.env(parent = emptyenv())
  assign(".__NAMESPACE__.", marker, envir = fake_namespace)
  fake_package <- new.env(parent = emptyenv())
  attr(fake_package, "name") <- "package:base"
  serializations <- 0L
  original <- stamp:::.st_reference_copy_for_save
  guarded <- original
  environment(guarded) <- list2env(list(serialize = function(...) {
    serializations <<- serializations + 1L
    stop("counterfeit must not reach serialization")
  }), parent = environment(original))
  local({
    local_audit_binding(".st_reference_copy_for_save", guarded)
    for (fake in list(fake_namespace, fake_package)) {
      fake_attrs <- attributes(fake)
      for (position in c("root", "child", "parent")) {
        x <- switch(position,
          root = fake,
          child = new.env(parent = emptyenv()),
          parent = new.env(parent = fake)
        )
        if (position == "child") x$child <- fake
        expect_error(st_save(x, "spoof.rds", verbose = FALSE),
                     class = "stamp_reference_copy_unsupported")
        expect_identical(serializations, 0L)
        expect_identical(attributes(fake), fake_attrs)
        expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
      }
    }
  })
  # Even a serializer returning a distinct known system root must be rejected.
  for (system in list(namespace, package)) {
    local({
      returning_system <- original
      environment(returning_system) <- list2env(
        list(unserialize = function(...) system), parent = environment(original)
      )
      local_audit_binding(".st_reference_copy_for_save", returning_system)
      local_audit_binding("st_sanitize_for_hash", function(...) {
        stop("system environment must not reach sanitizer")
      })
      local_audit_binding("st_hash_obj", function(...) {
        stop("system environment must not reach hashing")
      })
      x <- new.env(parent = emptyenv())
      x$value <- 1L
      expect_error(st_save(x, "system.rds", verbose = FALSE),
                   "serialization did not detach")
      expect_null(attributes(x))
    })
  }
  expect_identical(attributes(namespace), namespace_attrs)
  expect_identical(attributes(package), package_attrs)
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("ordinary missing and empty environment names remain supported", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  name_values <- list(NA_character_, "", "ordinary")
  for (i in seq_along(name_values)) {
    x <- new.env(parent = emptyenv())
    x$value <- 1L
    attr(x, "name") <- name_values[[i]]
    attrs_before <- attributes(x)
    owned <- stamp:::.st_reference_copy_for_save(
      x, "rds", rlang::env_get(stamp:::.st_formats_env, "rds"))
    expect_false(identical(owned, x))
    expect_identical(attributes(owned), attrs_before)
    path <- paste0("ordinary-name-", i, ".rds")
    expect_type(st_save(x, path, verbose = FALSE)$version_id, "character")
    payload <- readRDS(stamp:::.st_artifact_path(path))
    expect_identical(attr(payload, "name", exact = TRUE), name_values[[i]])
    expect_identical(payload$value, 1L)
    expect_identical(attributes(x), attrs_before)
  }
})

test_that("opted-in data frame environments reject PK before decoration", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  x <- new.env(parent = emptyenv())
  x$id <- 1L
  class(x) <- "data.frame"
  attr(x, "note") <- "caller"
  attrs_before <- attributes(x)
  error <- tryCatch(st_save(
    x, "fake-frame.rds", pk = "id", domain = "pilot-domain", unique = FALSE,
    metadata = stop("metadata must not run"), verbose = FALSE
  ), error = identity)
  expect_s3_class(error, "rlang_error")
  expect_match(conditionMessage(error), "not a data.frame")
  expect_identical(attributes(x), attrs_before)
  expect_null(attr(x, "stamp_pk", exact = TRUE))
  expect_null(attr(x, "stamp_domain", exact = TRUE))
  expect_identical(get("id", envir = x, inherits = FALSE), 1L)
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("opted-in data frame environments do not inspect PK attributes", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  local_st_opts(reference_copy_on_save = TRUE)
  counter <- 0L
  pk <- new.env(parent = emptyenv())
  makeActiveBinding("keys", function(value) {
    counter <<- counter + 1L
    "id"
  }, pk)
  x <- new.env(parent = emptyenv())
  x$id <- 1L
  class(x) <- "data.frame"
  attr(x, "stamp_pk") <- pk
  attrs_before <- attributes(x)
  expect_error(st_save(x, "fake-frame.rds", verbose = FALSE,
                       metadata = stop("metadata must not run")),
               class = "stamp_reference_copy_unsupported")
  expect_identical(counter, 0L)
  expect_true(bindingIsActive("keys", pk))
  expect_identical(attributes(x), attrs_before)
  expect_identical(attr(x, "stamp_pk", exact = TRUE), pk)
  expect_identical(get("id", envir = x, inherits = FALSE), 1L)
  expect_length(list.files(root, recursive = TRUE, all.files = TRUE), 0L)
})

test_that("default-off data frame environments retain PK mutation and fallback", {
  local_stamp_state()
  root <- withr::local_tempdir()
  st_init(root, verbose = FALSE)
  st_opts_reset()
  local_audit_binding(".st_reference_copy_for_save", function(...) {
    stop("copy must not run")
  })
  for (verbose in c(FALSE, TRUE)) {
    x <- new.env(parent = emptyenv())
    x$id <- 1L
    class(x) <- "data.frame"
    path <- paste0("legacy-frame-", verbose, ".rds")
    if (verbose) {
      expect_warning(saved <- st_save(
        x, path, pk = "id", domain = "legacy-domain", unique = FALSE,
        verbose = TRUE
      ), "Returning fallback")
    } else {
      expect_no_warning(saved <- st_save(
        x, path, pk = "id", domain = "legacy-domain", unique = FALSE,
        verbose = FALSE
      ))
    }
    expect_type(saved, "list")
    expect_null(saved$metadata)
    expect_null(saved$version_id)
    expect_identical(attr(x, "stamp_pk", exact = TRUE), list(keys = "id"))
    expect_identical(attr(x, "stamp_domain", exact = TRUE), "legacy-domain")
    expect_true(attr(x, "stamp_sanitized", exact = TRUE))
    expect_true(file.exists(stamp:::.st_artifact_path(path)))
    payload <- readRDS(stamp:::.st_artifact_path(path))
    expect_true(is.environment(payload))
    expect_identical(get("id", envir = payload, inherits = FALSE), 1L)
  }
  plain <- new.env(parent = emptyenv())
  plain$id <- 1L
  expect_error(st_save(plain, "plain.rds", pk = "id", domain = "unchanged",
                       unique = FALSE, verbose = FALSE), "not a data.frame")
  expect_null(attributes(plain))
  expect_false(file.exists(stamp:::.st_artifact_path("plain.rds")))
})
