m2_metadata_store <- function(mode = "json", envir = parent.frame()) {
  local_st_opts(
    default_format = "rds", meta_format = mode, versioning = "content",
    retain_versions = Inf, code_hash = TRUE, store_file_hash = TRUE,
    force_on_code_change = TRUE,
    .local_envir = envir
  )
  root <- withr::local_tempdir(.local_envir = envir)
  alias <- basename(root)
  aliases <- stamp:::.stamp_aliases
  old <- as.list(aliases)
  withr::defer({
    rm(list = ls(aliases, all.names = TRUE), envir = aliases)
    list2env(old, envir = aliases)
  }, envir = envir)
  st_init(root, alias = alias, verbose = FALSE)
  return(list(root = root, alias = alias))
}

m2_metadata_field <- function(type = "integer", shape = "scalar",
                              required = TRUE, nullable = FALSE,
                              allow_na = FALSE) {
  return(list(
    type = type, shape = shape, required = required,
    nullable = nullable, allow_na = allow_na
  ))
}

m2_metadata_request <- function(path, schema = NULL, values = list()) {
  return(list(
    schema = 1L, path = path, root = TRUE, parents = list(),
    required_components = "calculation",
    components = list(calculation = list(
      hash = "aaaaaaaaaaaaaaaa", algorithm = "siphash13", schema = "test-v1"
    )),
    semantic_schema = schema, semantic = values, format = "rds"
  ))
}

m2_metadata_inventory <- function(root) {
  paths <- sort(as.character(fs::dir_ls(root, recurse = TRUE, type = "file")))
  return(stats::setNames(
    vapply(paths, stamp:::st_hash_file, character(1)),
    as.character(fs::path_rel(paths, start = root))
  ))
}

for (mode in c("json", "qs2", "both")) {
  local({
    meta_mode <- mode
    test_that(paste(meta_mode, "nested legacy descriptions are not proof"), {
      store <- m2_metadata_store(meta_mode)
      descriptions <- list(
        semantic = list(schema = 1L, definition = "description", values = "v"),
        execution = list(schema = 1L, request = "audit, not encoded proof")
      )
      saved <- st_save(
        1:3, "nested.rds", metadata = descriptions,
        alias = store$alias, verbose = FALSE
      )
      for (pin in list(NULL, saved$version_id)) {
        read <- st_read_sidecar("nested.rds", store$alias, version_id = pin)
        expect_identical(read$semantic$definition, "description")
        expect_identical(read$semantic$values, "v")
        expect_identical(read$execution$request, "audit, not encoded proof")
      }
      same <- st_save(1:3, "nested.rds", alias = store$alias, verbose = FALSE)
      expect_true(same$skipped)
      expect_identical(same$version_id, saved$version_id)
    })

    test_that(paste(meta_mode, "partial modern execution blocks raw saves"), {
      store <- m2_metadata_store(meta_mode)
      path <- "partial.rds"
      request <- m2_metadata_request(path)
      saved <- st_save(1:3, path, request = request,
                       alias = store$alias, verbose = FALSE)
      directory <- stamp:::.st_version_dir(path, saved$version_id, store$alias)
      extensions <- if (meta_mode == "both") c("json", "qs2") else meta_mode
      for (ext in extensions) {
        current <- stamp:::.st_sidecar_path(path, ext, store$alias)
        wire <- if (ext == "json") {
          jsonlite::read_json(current, simplifyVector = TRUE)
        } else qs2::qs_read(current)
        wire$execution <- list(schema = 1L)
        if (ext == "json") {
          jsonlite::write_json(wire, current, auto_unbox = TRUE, digits = NA)
        } else qs2::qs_save(wire, current)
        fs::file_copy(current, fs::path(directory, paste0("sidecar.", ext)),
                      overwrite = TRUE)
      }
      before <- m2_metadata_inventory(store$root)
      error <- tryCatch(st_should_save(
        path, x = 1:3, request = request, alias = store$alias
      ), error = identity)
      expect_s3_class(error, "stamp_blocked_request")
      expect_identical(error$reason, "invalid_state")
      expect_error(st_save(
        1:3, path, request = request, alias = store$alias, verbose = FALSE
      ), class = "stamp_blocked_request")
      expect_identical(m2_metadata_inventory(store$root), before)
      expect_false(fs::dir_exists(fs::path(
        stamp:::.st_file_storage_dir(path, store$alias), "executions"
      )))
    })
  })
}

test_that("legacy JSON-first access ignores corrupt unused QS2 sidecars", {
  store <- m2_metadata_store("both")
  saved <- st_save(1:3, "lazy.rds", metadata = list(note = "legacy"),
                   alias = store$alias, verbose = FALSE)
  directory <- stamp:::.st_version_dir("lazy.rds", saved$version_id, store$alias)
  for (path in c(
    stamp:::.st_sidecar_path("lazy.rds", "qs2", store$alias),
    fs::path(directory, "sidecar.qs2")
  )) {
    writeBin(charToRaw("not a QS2 stream"), path)
  }
  expect_identical(st_read_sidecar("lazy.rds", store$alias)$note, "legacy")
  expect_identical(st_read_sidecar(
    "lazy.rds", store$alias, version_id = saved$version_id
  )$note, "legacy")
})

for (mode in c("json", "qs2")) {
  local({
    next_mode <- mode
    test_that(paste("modern both to legacy", next_mode, "keeps history"), {
      store <- m2_metadata_store("both")
      first <- st_save(
        1L, "transition.rds", metadata = list(value = 1L),
        semantic_schema = list(value = m2_metadata_field()),
        alias = store$alias, verbose = FALSE
      )
      old_dir <- stamp:::.st_version_dir(
        "transition.rds", first$version_id, store$alias
      )
      before <- m2_metadata_inventory(old_dir)
      suppressMessages(st_opts(meta_format = next_mode))
      second <- st_save(
        2L, "transition.rds", metadata = list(note = "legacy replacement"),
        alias = store$alias, verbose = FALSE
      )
      expect_type(second$version_id, "character")
      expect_false(identical(second$version_id, first$version_id))
      other <- if (next_mode == "json") "qs2" else "json"
      expect_false(fs::file_exists(stamp:::.st_sidecar_path(
        "transition.rds", other, store$alias
      )))
      expect_identical(st_read_sidecar("transition.rds", store$alias)$note,
                       "legacy replacement")
      expect_identical(st_read_sidecar(
        "transition.rds", store$alias, version_id = first$version_id
      )$value, 1L)
      expect_identical(m2_metadata_inventory(old_dir), before)
    })
  })
}

test_that("historical loads use pinned real QS2 and RDS physical formats", {
  store <- m2_metadata_store()
  for (path in c("override.rds", "override.qs2")) {
    request <- m2_metadata_request(path)
    request$format <- "qs2"
    first <- st_save(1:3, path, request = request,
                     alias = store$alias, verbose = FALSE)
    request$format <- "rds"
    second <- st_save(1:3, path, request = request,
                      alias = store$alias, verbose = FALSE)
    suppressMessages(st_opts(default_format = "json"))
    expect_identical(st_load_version(
      path, first$version_id, alias = store$alias, verbose = FALSE
    ), 1:3)
    expect_identical(st_load_version(
      path, second$version_id, alias = store$alias, verbose = FALSE
    ), 1:3)
    expect_identical(st_read_sidecar(
      path, store$alias, version_id = first$version_id
    )$format, "qs2")
    expect_identical(st_read_sidecar(
      path, store$alias, version_id = second$version_id
    )$format, "rds")
  }
})

test_that("modern both-mode reads do not ignore corrupt QS2 proof", {
  store <- m2_metadata_store("both")
  saved <- st_save(
    1:3, "strict.rds", request = m2_metadata_request("strict.rds"),
    alias = store$alias, verbose = FALSE
  )
  directory <- stamp:::.st_version_dir(
    "strict.rds", saved$version_id, store$alias
  )
  for (path in c(
    stamp:::.st_sidecar_path("strict.rds", "qs2", store$alias),
    fs::path(directory, "sidecar.qs2")
  )) {
    writeBin(charToRaw("not a QS2 stream"), path)
  }
  expect_error(st_read_sidecar("strict.rds", store$alias))
  expect_error(st_read_sidecar(
    "strict.rds", store$alias, version_id = saved$version_id
  ))
})

test_that("historical format fallback is only for absent legacy format", {
  store <- m2_metadata_store()
  saved <- st_save(1:3, "fallback.rds", alias = store$alias, verbose = FALSE)
  directory <- stamp:::.st_version_dir(
    "fallback.rds", saved$version_id, store$alias
  )
  sidecar <- fs::path(directory, "sidecar.json")
  wire <- jsonlite::read_json(sidecar, simplifyVector = TRUE)
  wire$format <- NULL
  jsonlite::write_json(wire, sidecar, auto_unbox = TRUE, digits = NA)
  suppressMessages(st_opts(default_format = "json"))
  expect_identical(st_load_version(
    "fallback.rds", saved$version_id, alias = store$alias, verbose = FALSE
  ), 1:3)
  wire$format <- "unregistered-format"
  jsonlite::write_json(wire, sidecar, auto_unbox = TRUE, digits = NA)
  expect_error(st_load_version(
    "fallback.rds", saved$version_id, alias = store$alias, verbose = FALSE
  ), "Unknown format")
})

test_that("request saves cannot certify an unchecksummed legacy parent", {
  store <- m2_metadata_store()
  suppressMessages(st_opts(store_file_hash = FALSE))
  parent <- st_save(1:3, "unchecksummed.rds",
                    alias = store$alias, verbose = FALSE)
  expect_identical(st_read_sidecar(
    "unchecksummed.rds", store$alias, version_id = parent$version_id
  )$content_hash, st_hash_obj(1:3))
  request <- m2_metadata_request("child.rds")
  request$root <- FALSE
  request$parents <- list(list(
    path = "unchecksummed.rds", version_id = parent$version_id
  ))
  before <- m2_metadata_inventory(store$root)
  expect_error(st_save(
    1:3, "child.rds", request = request, alias = store$alias, verbose = FALSE
  ), class = "stamp_blocked_request")
  expect_identical(m2_metadata_inventory(store$root), before)
})

test_that("metadata API preserves positional formals and exact named inputs", {
  expect_identical(names(formals(st_save)), c(
    "x", "file", "format", "metadata", "code", "parents", "code_label",
    "pk", "domain", "unique", "verbose", "alias", "...", "request",
    "semantic_schema"
  ))
  expect_identical(names(formals(st_read_sidecar)),
                   c("rel_path", "alias", "version_id"))
  expect_null(formals(st_save)$request)
  expect_null(formals(st_save)$semantic_schema)
  expect_null(formals(st_read_sidecar)$version_id)
})

for (mode in c("json", "qs2", "both")) {
  local({
    meta_mode <- mode

    test_that(paste(meta_mode, "semantic changes create immutable versions"), {
      store <- m2_metadata_store(meta_mode)
      path <- "semantic.rds"
      schema <- list(rule = m2_metadata_field())
      first <- st_save(
        1:3, path, metadata = list(rule = 1L, note = "original"),
        semantic_schema = schema, alias = store$alias, verbose = FALSE
      )
      expect_type(first$version_id, "character")
      expect_length(first$version_id, 1L)
      old_dir <- stamp:::.st_version_dir(
        path, first$version_id, alias = store$alias
      )
      before <- m2_metadata_inventory(old_dir)
      second <- st_save(
        1:3, path, metadata = list(rule = 2L, note = "new"),
        semantic_schema = schema, alias = store$alias, verbose = FALSE
      )
      expect_false(identical(second$version_id, first$version_id))
      expect_equal(nrow(st_versions(path, alias = store$alias)), 2L)
      expect_identical(m2_metadata_inventory(old_dir), before)
      old <- st_read_sidecar(
        path, alias = store$alias, version_id = first$version_id
      )
      current <- st_read_sidecar(path, alias = store$alias)
      expect_identical(old$rule, 1L)
      expect_identical(old$note, "original")
      expect_identical(current$rule, 2L)
      expect_identical(current$note, "new")
      expect_identical(
        st_load_version(path, first$version_id,
                        alias = store$alias, verbose = FALSE), 1:3
      )
    })

    test_that(paste(meta_mode, "descriptive edits leave all sidecars intact"), {
      store <- m2_metadata_store(meta_mode)
      schema <- list(rule = m2_metadata_field())
      first <- st_save(
        1:3, "notes.rds", metadata = list(rule = 1L, note = "original"),
        semantic_schema = schema, alias = store$alias, verbose = FALSE
      )
      before <- m2_metadata_inventory(store$root)
      same <- st_save(
        1:3, "notes.rds", metadata = list(rule = 1L, note = "edited"),
        semantic_schema = schema, alias = store$alias, verbose = FALSE
      )
      expect_true(same$skipped)
      expect_identical(same$version_id, first$version_id)
      expect_identical(m2_metadata_inventory(store$root), before)
      expect_identical(st_read_sidecar("notes.rds", store$alias)$note,
                       "original")
    })

    test_that(paste(meta_mode, "typed semantic values survive pinned reads"), {
      store <- m2_metadata_store(meta_mode)
      values <- list(
        flag = TRUE, count = 1L, amount = 1, label = "x",
        ints = c(1L, 2L), singleton = 1L, empty = integer(),
        null = NULL, missing_int = NA_integer_, missing_double = NA_real_,
        missing_flag = NA, missing_text = NA_character_
      )
      schema <- list(
        flag = m2_metadata_field("logical"),
        count = m2_metadata_field(), amount = m2_metadata_field("double"),
        label = m2_metadata_field("character"),
        ints = m2_metadata_field(shape = "vector"),
        singleton = m2_metadata_field(shape = "vector"),
        empty = m2_metadata_field(shape = "vector"),
        null = m2_metadata_field(nullable = TRUE),
        missing_int = m2_metadata_field(allow_na = TRUE),
        missing_double = m2_metadata_field("double", allow_na = TRUE),
        missing_flag = m2_metadata_field("logical", allow_na = TRUE),
        missing_text = m2_metadata_field("character", allow_na = TRUE)
      )
      saved <- st_save(
        1:3, "typed.rds", metadata = values, semantic_schema = schema,
        alias = store$alias, verbose = FALSE
      )
      for (pin in list(NULL, saved$version_id)) {
        read <- st_read_sidecar(
          "typed.rds", alias = store$alias, version_id = pin
        )
        expect_true(all(names(values) %in% names(read)))
        for (field in names(values)) {
          expect_identical(read[[field]], values[[field]], info = field)
        }
      }
    })

    test_that(paste(meta_mode, "absence NULL NA empty and schema differ"), {
      store <- m2_metadata_store(meta_mode)
      schema <- list(value = m2_metadata_field(
        shape = "vector", required = FALSE, nullable = TRUE, allow_na = TRUE
      ))
      cases <- list(list(), list(value = NULL), list(value = NA_integer_),
                    list(value = integer()), list(value = 1L))
      ids <- character()
      for (values in cases) {
        saved <- st_save(
          1:3, "distinct.rds", metadata = values, semantic_schema = schema,
          alias = store$alias, verbose = FALSE
        )
        ids <- c(ids, saved$version_id)
        read <- st_read_sidecar(
          "distinct.rds", alias = store$alias, version_id = saved$version_id
        )
        expect_identical("value" %in% names(read), "value" %in% names(values))
        expect_identical(read$value, values$value)
      }
      scalar <- schema
      scalar$value$shape <- "scalar"
      scalar_save <- st_save(
        1:3, "distinct.rds", metadata = list(value = 1L),
        semantic_schema = scalar, alias = store$alias, verbose = FALSE
      )
      double <- scalar
      double$value$type <- "double"
      double_save <- st_save(
        1:3, "distinct.rds", metadata = list(value = 1),
        semantic_schema = double, alias = store$alias, verbose = FALSE
      )
      ids <- c(ids, scalar_save$version_id, double_save$version_id)
      expect_length(ids, 7L)
      expect_length(unique(ids), 7L)
      expect_equal(nrow(st_versions("distinct.rds", store$alias)), 7L)
    })

    test_that(paste(meta_mode, "invalid schemas and values reject before writes"), {
      store <- m2_metadata_store(meta_mode)
      field <- m2_metadata_field()
      bad_fields <- list(
        field[-1L], c(field, list(extra = TRUE)),
        c(field, list(type = "integer")),
        modifyList(field, list(type = "numeric")),
        modifyList(field, list(shape = "array")),
        modifyList(field, list(required = NA)),
        modifyList(field, list(nullable = 1L)),
        modifyList(field, list(allow_na = c(TRUE, FALSE)))
      )
      cases <- lapply(bad_fields, function(x) {
        list(schema = list(value = x), values = list(value = 1L))
      })
      cases <- c(cases, list(
        list(schema = "not a schema", values = list(value = 1L)),
        list(schema = list(value = NULL), values = list(value = 1L)),
        list(schema = stats::setNames(list(field), ""),
             values = list(value = 1L)),
        list(schema = list(field), values = list(value = 1L)),
        list(schema = list(value = field, value = field),
             values = list(value = 1L)),
        list(schema = stats::setNames(list(field), NA_character_),
             values = list(value = 1L)),
        list(schema = list(value = field), values = list()),
        list(schema = list(value = field), values = list(value = NULL)),
        list(schema = list(value = field), values = list(value = NA_integer_)),
        list(schema = list(value = field), values = list(value = integer())),
        list(schema = list(value = field), values = list(value = c(1L, 2L))),
        list(schema = list(value = field), values = list(value = 1)),
        list(schema = list(value = field), values = list(value = factor("x"))),
        list(schema = list(value = field), values = list(value = Sys.Date())),
        list(schema = list(value = field), values = list(value = list(1L))),
        list(schema = list(value = m2_metadata_field("double")),
             values = list(value = NaN)),
        list(schema = list(value = m2_metadata_field("double")),
             values = list(value = Inf)),
        list(schema = list(value = m2_metadata_field("double")),
             values = list(value = 1L)),
        list(schema = list(value = field), values = "not a metadata list"),
        list(schema = list(value = field), values = list(1L)),
        list(schema = list(value = field),
             values = stats::setNames(list(1L), "")),
        list(schema = list(value = field),
             values = stats::setNames(list(1L), NA_character_)),
        list(schema = list(value = field),
             values = list(value = 1L, value = 1L)),
        list(schema = list(value = field),
             values = list(value = 1L, note = "a", note = "b"))
      ))
      before <- m2_metadata_inventory(store$root)
      for (case in cases) {
        expect_error(st_save(
          1:3, "invalid.rds", metadata = case$values,
          semantic_schema = case$schema, alias = store$alias, verbose = FALSE
        ))
        expect_identical(m2_metadata_inventory(store$root), before)
      }
    })

    test_that(paste(meta_mode, "modern metadata and schema reserve owned keys"), {
      store <- m2_metadata_store(meta_mode)
      reserved <- c(
        "path", "format", "created_at", "size_bytes", "content_hash",
        "code_hash", "file_hash", "code_label", "parents", "attrs", "pk",
        "domain", "version_id", "receipt_id", "outcome_id", "request_id",
        "request", "semantic_schema", "semantic", "execution"
      )
      before <- m2_metadata_inventory(store$root)
      for (key in reserved) {
        expect_error(st_save(
          1:3, "reserved.rds", metadata = stats::setNames(list(1L), key),
          semantic_schema = stats::setNames(list(m2_metadata_field()), key),
          alias = store$alias, verbose = FALSE
        ))
        expect_error(st_save(
          1:3, "reserved.rds", metadata = stats::setNames(list(1L), key),
          semantic_schema = list(), alias = store$alias, verbose = FALSE
        ))
        expect_identical(m2_metadata_inventory(store$root), before)
      }
    })

    test_that(paste(meta_mode, "missing historical proof never reads latest"), {
      store <- m2_metadata_store(meta_mode)
      first <- st_save(
        1L, "missing.rds", metadata = list(note = "old"),
        alias = store$alias, verbose = FALSE
      )
      st_save(2L, "missing.rds", metadata = list(note = "latest"),
              alias = store$alias, verbose = FALSE)
      old_dir <- stamp:::.st_version_dir(
        "missing.rds", first$version_id, alias = store$alias
      )
      ext <- if (meta_mode == "qs2") "qs2" else "json"
      fs::file_delete(fs::path(old_dir, paste0("sidecar.", ext)))
      expect_identical(st_read_sidecar("missing.rds", store$alias)$note,
                       "latest")
      expect_error(st_read_sidecar(
        "missing.rds", alias = store$alias, version_id = first$version_id
      ))
      expect_error(st_read_sidecar(
        "missing.rds", alias = store$alias, version_id = "unknown-exact-id"
      ))
      fs::dir_delete(old_dir)
      expect_error(st_read_sidecar(
        "missing.rds", alias = store$alias, version_id = first$version_id
      ))
    })
  })
}

test_that("both-mode typed disagreement is invalid, not JSON preference", {
  store <- m2_metadata_store("both")
  schema <- list(value = m2_metadata_field())
  first <- st_save(
    1L, "conflict.rds", metadata = list(value = 1L),
    semantic_schema = schema, alias = store$alias, verbose = FALSE
  )
  second <- st_save(
    1L, "conflict.rds", metadata = list(value = 2L),
    semantic_schema = schema, alias = store$alias, verbose = FALSE
  )
  first_dir <- stamp:::.st_version_dir(
    "conflict.rds", first$version_id, alias = store$alias
  )
  second_dir <- stamp:::.st_version_dir(
    "conflict.rds", second$version_id, alias = store$alias
  )
  fs::file_copy(fs::path(first_dir, "sidecar.qs2"),
                fs::path(second_dir, "sidecar.qs2"), overwrite = TRUE)
  fs::file_copy(
    fs::path(first_dir, "sidecar.qs2"),
    stamp:::.st_sidecar_path("conflict.rds", "qs2", alias = store$alias),
    overwrite = TRUE
  )
  expect_error(st_read_sidecar("conflict.rds", alias = store$alias))
  expect_error(st_read_sidecar(
    "conflict.rds", alias = store$alias, version_id = second$version_id
  ))
})

test_that("sidecar reads never invoke the artifact format reader", {
  store <- m2_metadata_store()
  formats <- stamp:::.st_formats_env
  old <- as.list(formats)
  withr::defer({
    rm(list = ls(formats, all.names = TRUE), envir = formats)
    list2env(old, envir = formats)
  })
  calls <- 0L
  suppressMessages(st_register_format(
    "m2_metadata_spy",
    read = function(path, ...) {
      calls <<- calls + 1L
      stop("Artifact reader must not run")
    },
    write = function(x, path, ...) saveRDS(x, path)
  ))
  saved <- st_save(
    1:3, "spy.rds", format = "m2_metadata_spy",
    metadata = list(value = 1L),
    semantic_schema = list(value = m2_metadata_field()),
    alias = store$alias, verbose = FALSE
  )
  expect_identical(st_read_sidecar("spy.rds", store$alias)$value, 1L)
  expect_identical(st_read_sidecar(
    "spy.rds", store$alias, version_id = saved$version_id
  )$value, 1L)
  expect_identical(calls, 0L)
})

test_that("unchanged legacy save returns the validated retained version", {
  store <- m2_metadata_store()
  first <- st_save(1:3, "same.rds", alias = store$alias, verbose = FALSE)
  same <- st_save(1:3, "same.rds", alias = store$alias, verbose = FALSE)
  expect_true(same$skipped)
  expect_identical(same$version_id, first$version_id)
  expect_identical(st_load_version(
    "same.rds", same$version_id, alias = store$alias, verbose = FALSE
  ), 1:3)
  expect_equal(nrow(st_versions("same.rds", store$alias)), 1L)
})

test_that("same-clock semantic versions never overwrite retained snapshots", {
  store <- m2_metadata_store()
  local_mocked_bindings(
    .st_now_utc = function() "2026-10-15T12:00:00.000000Z",
    .package = "stamp"
  )
  schema <- list(value = m2_metadata_field())
  ids <- character()
  for (value in seq_len(12L)) {
    saved <- st_save(
      1:3, "collision.rds", metadata = list(value = value),
      semantic_schema = schema, alias = store$alias, verbose = FALSE
    )
    ids <- c(ids, saved$version_id)
  }
  expect_length(unique(ids), 12L)
  expect_identical(st_latest("collision.rds", store$alias), ids[[12L]])
  for (value in seq_len(12L)) {
    expect_identical(st_read_sidecar(
      "collision.rds", alias = store$alias, version_id = ids[[value]]
    )$value, value)
  }
})

test_that("legacy descriptive owned names are not reinterpreted as envelopes", {
  store <- m2_metadata_store()
  first <- st_save(
    1:3, "legacy.rds", metadata = list(
      semantic = "legacy description", execution = "legacy audit"
    ), alias = store$alias, verbose = FALSE
  )
  read <- st_read_sidecar("legacy.rds", alias = store$alias)
  expect_identical(read$semantic, "legacy description")
  expect_identical(read$execution, "legacy audit")
  same <- st_save(1:3, "legacy.rds", alias = store$alias, verbose = FALSE)
  expect_true(same$skipped)
  expect_identical(same$version_id, first$version_id)
})

for (mode in c("json", "qs2", "both")) {
  local({
    meta_mode <- mode
    test_that(paste(meta_mode, "request semantics agree with metadata"), {
      store <- m2_metadata_store(meta_mode)
      schema <- list(value = m2_metadata_field())
      request <- m2_metadata_request("request.rds", schema, list(value = 1L))
      before <- m2_metadata_inventory(store$root)
      for (values in list(list(value = 2L), list(value = 1), list())) {
        expect_error(st_save(
          1:3, "request.rds", metadata = values, request = request,
          alias = store$alias, verbose = FALSE
        ))
        expect_identical(m2_metadata_inventory(store$root), before)
      }
      for (values in list(list(value = 1L, extra = 1L),
                          list(value = 1L, value = 1L), list(1L),
                          stats::setNames(list(1L), ""),
                          stats::setNames(list(1L), NA_character_))) {
        invalid <- request
        invalid$semantic <- values
        expect_error(st_save(
          1:3, "request.rds", metadata = list(value = 1L), request = invalid,
          alias = store$alias, verbose = FALSE
        ))
        expect_identical(m2_metadata_inventory(store$root), before)
      }
      legacy_schema_request <- m2_metadata_request("request.rds")
      for (values in list(list(note = "a", note = "b"),
                          list(path = "reserved"))) {
        expect_error(st_save(
          1:3, "request.rds", metadata = values,
          request = legacy_schema_request, alias = store$alias,
          verbose = FALSE
        ))
        expect_identical(m2_metadata_inventory(store$root), before)
      }
      first <- st_save(
        1:3, "request.rds", metadata = list(value = 1L), request = request,
        alias = store$alias, verbose = FALSE
      )
      decision <- st_should_save(
        "request.rds", x = 1:3, request = request, metadata = list(value = 1L),
        alias = store$alias
      )
      expect_false(decision$save)
      expect_identical(decision$decision, "skip")
      expect_identical(decision$latest_version_id, first$version_id)
      changed <- request
      changed$semantic$value <- 2L
      decision <- st_should_save(
        "request.rds", x = 1:3, request = changed, metadata = list(value = 2L),
        alias = store$alias
      )
      expect_true(decision$save)
      expect_identical(decision$decision, "run")
      expect_identical(decision$reason, "semantic_changed")
    })
  })
}
