# Real stores only: these helpers do not substitute storage or publication.
m2_state_store <- function(.local_envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = .local_envir)
  alias <- paste0("m2-state-", basename(root))
  local_st_opts(
    default_format = "rds", meta_format = "json",
    versioning = "content", retain_versions = Inf,
    .local_envir = .local_envir
  )
  st_init(root, alias = alias, verbose = FALSE)
  withr::defer(
    rlang::env_unbind(stamp:::.stamp_aliases, alias),
    envir = .local_envir
  )
  list(root = root, alias = alias)
}

m2_state_request <- function(store, file = "result.rds", parents = list()) {
  list(
    schema = 1L,
    path = as.character(fs::path(store$root, file)),
    root = !length(parents),
    parents = parents,
    required_components = c("calculation", "helper"),
    components = list(
      calculation = list(
        hash = "0123456789abcdef", algorithm = "siphash13", schema = "v1"
      ),
      helper = list(
        hash = "fedcba9876543210", algorithm = "siphash13", schema = "v1"
      )
    ),
    semantic_schema = NULL,
    semantic = list(),
    format = "rds"
  )
}

test_that("M2 adds only the two approved public execution interfaces", {
  expected <- c("st_add_pk", "st_alias_get", "st_alias_list", "st_builders",
    "st_catalog_query", "st_changed", "st_changed_reason", "st_children",
    "st_clear_builders", "st_filter", "st_formats", "st_get_pk", "st_hash_obj",
    "st_info", "st_init", "st_inspect_pk", "st_is_stale", "st_latest",
    "st_lineage", "st_load", "st_load_version", "st_opts", "st_opts_get",
    "st_opts_reset", "st_pk", "st_plan_rebuild", "st_prune_versions",
    "st_read_sidecar", "st_rebuild", "st_register_builder", "st_register_format",
    "st_restore", "st_save", "st_should_save", "st_switch", "st_versions",
    "st_with_pk", "st_execution_info", "st_record_outcome")
  expect_setequal(getNamespaceExports("stamp"), expected)
  expect_identical(names(formals(getExportedValue("stamp", "st_execution_info"))),
    c("path", "receipt_id", "alias"))
  expect_identical(names(formals(getExportedValue("stamp", "st_record_outcome"))),
    c("path", "outcome", "request", "failure", "alias"))
})

test_that("public failure facts round-trip through the data-free interface", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  record <- getExportedValue("stamp", "st_record_outcome")(
    request$path, "failed", request,
    failure = list(class = "external", message = "Fixture unavailable"),
    alias = store$alias)
  info <- getExportedValue("stamp", "st_execution_info")(
    request$path, receipt_id = record$id, alias = store$alias)
  expect_identical(info$state, "recorded")
  expect_identical(info$reason, "failed_external")
  expect_identical(info$outcome, record)
  expect_null(info$receipt)
  expect_true(is.na(info$version_id))
  expect_false(fs::file_exists(stamp:::.st_execution_path(
    request$path, store$alias)$storage_path))
})

m2_state_save <- function(store, request, x = list(value = 1L)) {
  st_save(
    x, request$path, request = request, parents = request$parents,
    alias = store$alias, verbose = FALSE
  )
}

m2_state_dir <- function(store, request) {
  rel <- as.character(fs::path_rel(request$path, store$root))
  stamp:::.st_file_storage_dir(rel, alias = store$alias)
}

m2_state_committed <- function(store, request) {
  path <- fs::path(m2_state_dir(store, request), "executions")
  if (!fs::dir_exists(path)) {
    return(character())
  }
  as.character(fs::dir_ls(path, recurse = TRUE, regexp = "/COMMITTED$"))
}

m2_state_bytes <- function(path) {
  readBin(path, what = "raw", n = file.info(path)$size)
}

m2_state_expect_no_pin <- function(info) {
  expect_true(is.null(info$version_id) ||
    (length(info$version_id) == 1L && is.na(info$version_id)))
}

test_that("proof metadata codec preserves types and shape without sanitizing", {
  proof <- list(
    integer = 1L, double = 1, logical = TRUE,
    absent = list(), null = NULL, missing_integer = NA_integer_,
    missing_character = NA_character_, empty = character(),
    named = c(one = "a"), scalar = "a", vector = c("a", "b")
  )
  text <- stamp:::.st_proof_encode(proof)
  expect_type(text, "character")
  expect_length(text, 1L)
  expect_match(text, "^[0-9a-f]+$")
  expect_identical(stamp:::.st_proof_decode(text), proof)
  expect_false(identical(
    stamp:::.st_proof_encode(1L), stamp:::.st_proof_encode(1)
  ))
  expect_error(stamp:::.st_proof_decode("not-hex"))
  expect_error(stamp:::.st_proof_decode("a"))
})

test_that("absent state and unknown explicit receipts are distinct", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(info$state, "absent")
  expect_true(all(c(
    "state", "reason", "receipt", "outcome", "version_id", "receipt_id",
    "outcome_id"
  ) %in% names(info)))
  m2_state_expect_no_pin(info)
  expect_error(stamp:::st_execution_info(
    request$path, receipt_id = "unknown", alias = store$alias
  ))
  expect_length(m2_state_committed(store, request), 0L)
})

test_that("canonical request identity ignores audit and review only", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  canonical <- stamp:::.st_request_normalize(request, alias = store$alias)
  reordered <- request
  reordered$path <- "result.rds"
  reordered$required_components <- rev(request$required_components)
  reordered$components <- rev(request$components)
  reordered$audit <- list(source = "different-source-sha")
  reordered$review <- list(outcome_id = "reviewed-failure")
  normalized <- stamp:::.st_request_normalize(reordered, alias = store$alias)
  expect_identical(stamp:::.st_request_id(normalized),
    stamp:::.st_request_id(canonical))
  normalized$components$helper$hash <- "1111111111111111"
  expect_false(identical(stamp:::.st_request_id(normalized),
    stamp:::.st_request_id(canonical)))
  incomplete <- request
  incomplete$components$helper$hash <- NULL
  error <- tryCatch(stamp:::.st_request_normalize(
    incomplete, alias = store$alias
  ), error = identity)
  expect_s3_class(error, "stamp_blocked_request")
  expect_identical(error$reason, "missing_requested_proof")
})

test_that("deferred templates can only publish internal blocked observations", {
  store <- m2_state_store()
  request <- m2_state_request(store, parents = list(list(
    path = as.character(fs::path(store$root, "parent.rds")), version_id = NULL
  )))
  expect_error(stamp:::.st_request_normalize(request, alias = store$alias))
  canonical <- stamp:::.st_request_normalize(
    request, alias = store$alias, allow_deferred = TRUE
  )
  expect_null(canonical$parents[[1L]]$version_id)
  stamp:::.st_execution_append(
    request$path, "blocked", request,
    failure = list(class = "unknown", message = "Selected parent pending"),
    alias = store$alias, allow_deferred = TRUE
  )
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(info$outcome$request_kind, "preview")
  expect_match(info$outcome$request_id, "^preview-")
  m2_state_expect_no_pin(info)
})

test_that("classified failures and blocked facts survive store reinitialization", {
  store <- m2_state_store()
  for (class in c("deterministic", "external", "unknown")) {
    request <- m2_state_request(store, paste0(class, ".rds"))
    failure <- list(class = class, message = "Exact caller failure facts")
    stamp:::st_record_outcome(
      request$path, "failed", request, failure, alias = store$alias
    )
    first <- stamp:::st_execution_info(request$path, alias = store$alias)
    expect_identical(first$outcome$outcome, paste0("failed_", class))
    expect_identical(first$outcome$failure, failure)
    expect_null(first$outcome$output)
    m2_state_expect_no_pin(first)
    stamp:::st_record_outcome(
      request$path, "blocked", request,
      list(class = "unknown", message = "Prerequisite unavailable"),
      alias = store$alias
    )
    st_init(store$root, alias = store$alias, verbose = FALSE)
    latest <- stamp:::st_execution_info(request$path, alias = store$alias)
    old <- stamp:::st_execution_info(
      request$path, receipt_id = first$outcome_id, alias = store$alias
    )
    expect_identical(latest$outcome$outcome, "blocked")
    expect_identical(latest$outcome$previous_id, first$outcome_id)
    expect_equal(latest$outcome$sequence, first$outcome$sequence + 1L)
    expect_identical(old$outcome, first$outcome)
    expect_length(m2_state_committed(store, request), 2L)
    expect_equal(nrow(st_versions(request$path, alias = store$alias)), 0L)
  }
})

test_that("public outcome facts cannot create success or guess failure class", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  for (outcome in c("success", "success_new", "success_unchanged")) {
    expect_error(stamp:::st_record_outcome(
      request$path, outcome, request, alias = store$alias
    ))
  }
  for (failure in list(
    NULL, list(class = "timeout", message = "external"),
    list(class = "unknown"),
    list(class = "external", message = "x", extra = TRUE)
  )) {
    expect_error(stamp:::st_record_outcome(
      request$path, "failed", request, failure, alias = store$alias
    ))
  }
  expect_error(stamp:::st_record_outcome(
    request$path, "blocked", request,
    list(class = "deterministic", message = "x"), alias = store$alias
  ))
  deferred <- request
  deferred$root <- FALSE
  deferred$parents <- list(list(path = "parent.rds", version_id = NULL))
  expect_error(stamp:::st_record_outcome(
    request$path, "blocked", deferred,
    list(class = "unknown", message = "pending"), alias = store$alias
  ))
  expect_length(m2_state_committed(store, request), 0L)
})

test_that("raw unchanged saves return a retained pin without execution proof", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  again <- m2_state_save(store, request)
  expect_true(again$skipped)
  expect_identical(again$version_id, saved$version_id)
  expect_equal(nrow(st_versions(request$path, alias = store$alias)), 1L)
  expect_identical(stamp:::st_execution_info(
    request$path, alias = store$alias
  )$state, "absent")
  expect_length(m2_state_committed(store, request), 0L)
})

test_that("validated success is durable, data-free and serially idempotent", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  first <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(first$receipt$outcome, "success_new")
  expect_identical(first$receipt$request_kind, "effective")
  expect_identical(first$version_id, saved$version_id)
  expect_identical(first$receipt$output$version_id, saved$version_id)
  expect_identical(first$receipt$output$format, "rds")
  expect_null(first$receipt$failure)
  markers <- m2_state_committed(store, request)
  expect_length(markers, 1L)
  receipt_path <- fs::path(fs::path_dir(markers), "receipt.json")
  receipt_bytes <- m2_state_bytes(receipt_path)
  handler <- rlang::env_get(stamp:::.st_formats_env, "rds")
  withr::defer(rlang::env_poke(stamp:::.st_formats_env, "rds", handler))
  no_read <- handler
  no_read$read <- function(...) stop("Artifact reader must not run")
  rlang::env_poke(stamp:::.st_formats_env, "rds", no_read)
  st_init(store$root, alias = store$alias, verbose = FALSE)
  expect_identical(stamp:::st_execution_info(
    request$path, receipt_id = first$receipt_id, alias = store$alias
  )$receipt, first$receipt)
  request$audit <- list(source = "unrelated-source-revision")
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  expect_identical(m2_state_committed(store, request), markers)
  expect_identical(m2_state_bytes(receipt_path), receipt_bytes)
  expect_equal(nrow(st_versions(request$path, alias = store$alias)), 1L)
})

test_that("success publisher rejects a claimed pin without validated storage", {
  for (damage in c("fake_pin", "wrong_path", "snapshot", "sidecar", "catalog")) {
    store <- m2_state_store()
    request <- m2_state_request(store)
    saved <- m2_state_save(store, request)
    vdir <- stamp:::.st_version_dir(
      "result.rds", saved$version_id, alias = store$alias
    )
    if (damage == "fake_pin") saved$version_id <- "not-a-version"
    if (damage == "wrong_path") {
      other <- m2_state_request(store, "other.rds")
      saved <- m2_state_save(store, other)
    }
    if (damage == "snapshot") fs::file_delete(fs::path(vdir, "artifact"))
    if (damage == "sidecar") fs::file_delete(fs::path(vdir, "sidecar.json"))
    if (damage == "catalog") {
      catalog <- stamp:::.st_catalog_read(alias = store$alias)
      catalog$versions <- catalog$versions[0L]
      stamp:::.st_catalog_write(catalog, alias = store$alias)
    }
    expect_error(stamp:::.st_execution_success(
      request$path, request, saved, alias = store$alias
    ))
    expect_length(m2_state_committed(store, request), 0L)
    m2_state_expect_no_pin(stamp:::st_execution_info(
      request$path, alias = store$alias
    ))
  }
})

test_that("pending publication is not authority and remains untouched", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  pending <- fs::path(m2_state_dir(store, request), "executions", "pending")
  fs::dir_create(pending)
  writeLines("{unfinished", fs::path(pending, "receipt.json"))
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(info$state, "absent")
  m2_state_expect_no_pin(info)
  expect_true(fs::file_exists(fs::path(pending, "receipt.json")))
})

test_that("committed corruption never falls back to an older success", {
  for (damage in c(
    "marker", "missing_marker", "receipt", "index", "snapshot", "sidecar",
    "current", "catalog"
  )) {
    store <- m2_state_store()
    request <- m2_state_request(store)
    saved <- m2_state_save(store, request)
    stamp:::.st_execution_success(
      request$path, request, saved, alias = store$alias
    )
    marker <- m2_state_committed(store, request)
    receipt <- fs::path(fs::path_dir(marker), "receipt.json")
    vdir <- stamp:::.st_version_dir(
      "result.rds", saved$version_id, alias = store$alias
    )
    if (damage == "marker") writeLines("wrong-checksum", marker)
    if (damage == "missing_marker") fs::file_delete(marker)
    if (damage == "receipt") writeLines("{}", receipt)
    if (damage == "index") {
      writeLines("{}", fs::path(
        m2_state_dir(store, request), "current-execution.json"
      ))
    }
    if (damage == "snapshot") fs::file_delete(fs::path(vdir, "artifact"))
    if (damage == "sidecar") writeLines("{}", fs::path(vdir, "sidecar.json"))
    if (damage == "current") {
      writeBin(charToRaw("corrupt"), stamp:::.st_artifact_path(
        "result.rds", alias = store$alias
      ))
    }
    if (damage == "catalog") {
      catalog <- stamp:::.st_catalog_read(alias = store$alias)
      catalog$versions <- catalog$versions[0L]
      stamp:::.st_catalog_write(catalog, alias = store$alias)
    }
    info <- stamp:::st_execution_info(request$path, alias = store$alias)
    expect_identical(info$state, "invalid", info = damage)
    expect_identical(info$reason, "invalid_state", info = damage)
    m2_state_expect_no_pin(info)
  }
})

test_that("only missing current bytes is distinguishable from corrupt proof", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  fs::file_delete(stamp:::.st_artifact_path("result.rds", alias = store$alias))
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(info$reason, "missing_output")
  m2_state_expect_no_pin(info)
  expect_length(m2_state_committed(store, request), 1L)
})

test_that("historical data recovery never repairs or certifies damaged proof", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(request$path, request, saved,
    alias = store$alias)
  m2_state_save(store, request, list(value = 2L))
  vdir <- stamp:::.st_version_dir("result.rds", saved$version_id, store$alias)
  writeLines("{", fs::path(vdir, "sidecar.json"))
  historical <- fs::dir_ls(vdir, type = "file")
  historical_bytes <- lapply(historical, m2_state_bytes)
  markers <- m2_state_committed(store, request)
  receipt_files <- c(markers, fs::path(fs::path_dir(markers), "receipt.json"),
    fs::path(m2_state_dir(store, request), "current-execution.json"))
  receipt_bytes <- lapply(receipt_files, m2_state_bytes)
  catalog_path <- stamp:::.st_catalog_path(store$alias)
  catalog_bytes <- m2_state_bytes(catalog_path)

  expect_identical(st_load_version(request$path, saved$version_id,
    alias = store$alias, verbose = FALSE), list(value = 1L))
  expect_identical(m2_state_bytes(catalog_path), catalog_bytes)
  expect_error(st_read_sidecar(request$path, alias = store$alias,
    version_id = saved$version_id))
  expect_identical(stamp:::st_execution_info(request$path,
    alias = store$alias)$state, "invalid")
  expect_error(st_is_stale(request$path, alias = store$alias,
    request = request), class = "stamp_blocked_request")

  expect_identical(st_restore(request$path, saved$version_id,
    alias = store$alias, verbose = FALSE), list(value = 1L))
  expect_identical(st_load(request$path, alias = store$alias,
    verbose = FALSE), list(value = 1L))
  expect_error(st_read_sidecar(request$path, alias = store$alias,
    version_id = saved$version_id))
  expect_identical(stamp:::st_execution_info(request$path,
    alias = store$alias)$state, "invalid")
  expect_error(st_is_stale(request$path, alias = store$alias,
    request = request), class = "stamp_blocked_request")
  expect_identical(fs::dir_ls(vdir, type = "file"), historical)
  expect_identical(lapply(historical, m2_state_bytes), historical_bytes)
  expect_identical(m2_state_committed(store, request), markers)
  expect_identical(lapply(receipt_files, m2_state_bytes), receipt_bytes)
})

test_that("either readable modern sidecar prevents historical data fallback", {
  for (damage in c("json_corrupt", "json_legacy", "qs_corrupt", "catalog")) {
    store <- m2_state_store()
    local_st_opts(meta_format = "both")
    request <- m2_state_request(store)
    saved <- m2_state_save(store, request)
    vdir <- stamp:::.st_version_dir("result.rds", saved$version_id, store$alias)
    if (damage == "json_corrupt") {
      writeLines("{", fs::path(vdir, "sidecar.json"))
    }
    if (damage == "json_legacy") {
      writeLines("{}", fs::path(vdir, "sidecar.json"))
    }
    if (damage == "qs_corrupt") {
      writeBin(charToRaw("corrupt"), fs::path(vdir, "sidecar.qs2"))
    }
    if (damage == "catalog") {
      catalog <- stamp:::.st_catalog_read(store$alias)
      catalog$versions <- catalog$versions[0L]
      stamp:::.st_catalog_write(catalog, store$alias)
    }
    files <- fs::dir_ls(vdir, type = "file")
    before <- lapply(files, m2_state_bytes)
    expect_error(st_load_version(request$path, saved$version_id,
      alias = store$alias, verbose = FALSE))
    expect_error(st_read_sidecar(request$path, alias = store$alias,
      version_id = saved$version_id))
    expect_identical(lapply(files, m2_state_bytes), before)
  }
})

test_that("modern historical key loading does not create catalog indexes", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  x <- data.table::data.table(id = 1:3, value = letters[1:3])
  data.table::setkey(x, id)
  saved <- m2_state_save(store, request, x)
  catalog_path <- stamp:::.st_catalog_path(store$alias)
  before <- m2_state_bytes(catalog_path)
  loaders <- audit_key_loaders()

  restored <- loaders$st_load_version(request$path, saved$version_id,
    alias = store$alias, verbose = FALSE)
  expect_identical(restored, x)
  expect_identical(data.table::key(restored), "id")
  expect_identical(loaders$st_versions(request$path,
    alias = store$alias)$version_id, saved$version_id)
  expect_identical(m2_state_bytes(catalog_path), before)
})

test_that("copied receipts cannot certify another artifact", {
  store <- m2_state_store()
  source <- m2_state_request(store, "source.rds")
  saved <- m2_state_save(store, source)
  stamp:::.st_execution_success(
    source$path, source, saved, alias = store$alias
  )
  target <- m2_state_request(store, "target.rds")
  m2_state_save(store, target)
  source_dir <- m2_state_dir(store, source)
  target_dir <- m2_state_dir(store, target)
  fs::dir_copy(fs::path(source_dir, "executions"),
    fs::path(target_dir, "executions"))
  fs::file_copy(fs::path(source_dir, "current-execution.json"),
    fs::path(target_dir, "current-execution.json"))
  info <- stamp:::st_execution_info(target$path, alias = store$alias)
  expect_identical(info$state, "invalid")
  expect_identical(info$reason, "invalid_state")
  m2_state_expect_no_pin(info)
})

test_that("success requires complete comparable saved request proof", {
  for (damage in c("legacy", "component", "format")) {
    store <- m2_state_store()
    request <- m2_state_request(store)
    saved <- if (damage == "legacy") {
      st_save(list(value = 1L), request$path,
        alias = store$alias, verbose = FALSE)
    } else {
      m2_state_save(store, request)
    }
    if (damage == "component") {
      request$components$helper$hash <- "1111111111111111"
    }
    if (damage == "format") request$format <- "qs2"
    expect_error(stamp:::.st_execution_success(
      request$path, request, saved, alias = store$alias
    ))
    expect_length(m2_state_committed(store, request), 0L)
  }
})

test_that("failed attempts remain readable without available parent snapshots", {
  store <- m2_state_store()
  request <- m2_state_request(store, parents = list(list(
    path = as.character(fs::path(store$root, "missing.rds")),
    version_id = "unavailable-pin"
  )))
  failure <- list(class = "external", message = "Input unavailable")
  stamp:::st_record_outcome(
    request$path, "failed", request, failure, alias = store$alias
  )
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_false(identical(info$state, "invalid"))
  expect_identical(info$outcome$outcome, "failed_external")
  expect_identical(info$outcome$failure, failure)
  m2_state_expect_no_pin(info)
})

test_that("a success loses its usable pin when exact parent proof is missing", {
  store <- m2_state_store()
  parent <- m2_state_request(store, "parent.rds")
  a1 <- m2_state_save(store, parent)
  request <- m2_state_request(store, parents = list(list(
    path = parent$path, version_id = a1$version_id
  )))
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  fs::file_delete(fs::path(stamp:::.st_version_dir(
    "parent.rds", a1$version_id, alias = store$alias
  ), "artifact"))
  st_init(store$root, alias = store$alias, verbose = FALSE)
  info <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(info$state, "invalid")
  expect_identical(info$reason, "invalid_state")
  m2_state_expect_no_pin(info)
})

test_that("later actual failure is not replaced by an older success", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  success <- stamp:::st_execution_info(request$path, alias = store$alias)
  stamp:::st_record_outcome(
    request$path, "failed", request,
    list(class = "unknown", message = "Actual failed execution"),
    alias = store$alias
  )
  latest <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(latest$outcome$outcome, "failed_unknown")
  m2_state_expect_no_pin(latest)
  expect_identical(stamp:::st_execution_info(
    request$path, success$receipt_id, alias = store$alias
  )$receipt, success$receipt)
})

test_that("parent-only retained success does not rewrite original provenance", {
  store <- m2_state_store()
  parent <- m2_state_request(store, "parent.rds")
  a1 <- m2_state_save(store, parent)
  request <- m2_state_request(store, parents = list(list(
    path = parent$path, version_id = a1$version_id
  )))
  b1 <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, b1, alias = store$alias
  )
  first <- stamp:::st_execution_info(request$path, alias = store$alias)
  vdir <- stamp:::.st_version_dir("result.rds", b1$version_id, store$alias)
  files <- fs::dir_ls(vdir, type = "file")
  original <- lapply(files, m2_state_bytes)
  a2 <- m2_state_save(store, parent, list(value = 2L))
  request$parents[[1L]]$version_id <- a2$version_id
  retained <- m2_state_save(store, request)
  expect_true(retained$skipped)
  expect_identical(retained$version_id, b1$version_id)
  stamp:::.st_execution_success(
    request$path, request, retained, alias = store$alias
  )
  latest <- stamp:::st_execution_info(request$path, alias = store$alias)
  expect_identical(latest$receipt$outcome, "success_unchanged")
  expect_identical(latest$version_id, b1$version_id)
  expect_identical(latest$receipt$request$parents[[1L]]$version_id, a2$version_id)
  expect_identical(lapply(files, m2_state_bytes), original)
  expect_identical(stamp:::st_execution_info(
    request$path, first$receipt_id, alias = store$alias
  )$receipt, first$receipt)
  expect_length(m2_state_committed(store, request), 2L)
})

test_that("cross-artifact receipt dependencies protect path-filtered pruning", {
  store <- m2_state_store()
  parent <- m2_state_request(store, "parent.rds")
  a1 <- m2_state_save(store, parent)
  child <- m2_state_request(store, parents = list(list(
    path = parent$path, version_id = a1$version_id
  )))
  b1 <- m2_state_save(store, child)
  stamp:::.st_execution_success(child$path, child, b1, alias = store$alias)
  m2_state_save(store, parent, list(value = 2L))
  before <- st_versions(parent$path, alias = store$alias)
  preview <- st_prune_versions(
    parent$path, policy = 1L, dry_run = TRUE, alias = store$alias
  )
  expect_true(all(c("protected", "reason") %in% names(preview)))
  row <- preview[preview$version_id == a1$version_id, ]
  expect_equal(nrow(row), 1L)
  expect_true(row$protected)
  expect_identical(row$reason, "execution_reference")
  expect_identical(st_versions(parent$path, alias = store$alias), before)
  expect_error(st_prune_versions(
    parent$path, policy = 1L, dry_run = FALSE, alias = store$alias
  ))
  expect_identical(st_versions(parent$path, alias = store$alias), before)
  expect_true(fs::file_exists(fs::path(stamp:::.st_version_dir(
    "parent.rds", a1$version_id, alias = store$alias
  ), "artifact")))
})

test_that("multi-path retention refuses mixed protected selection atomically", {
  store <- m2_state_store()
  parent <- m2_state_request(store, "parent.rds")
  a1 <- m2_state_save(store, parent)
  child <- m2_state_request(store, parents = list(list(
    path = parent$path, version_id = a1$version_id
  )))
  b1 <- m2_state_save(store, child)
  stamp:::.st_execution_success(child$path, child, b1, alias = store$alias)
  m2_state_save(store, parent, list(value = 2L))
  other <- m2_state_request(store, "other.rds")
  o1 <- m2_state_save(store, other)
  m2_state_save(store, other, list(value = 2L))

  catalog_path <- stamp:::.st_catalog_path(store$alias)
  catalog_before <- m2_state_bytes(catalog_path)
  snapshots <- fs::dir_ls(store$root, recurse = TRUE, type = "file",
    regexp = "/versions/")
  bytes_before <- lapply(snapshots, m2_state_bytes)
  selected <- c(other$path, parent$path)
  preview <- st_prune_versions(selected, policy = 1L, dry_run = TRUE,
    alias = store$alias)
  expect_setequal(preview$version_id, c(a1$version_id, o1$version_id))
  expect_true(preview$protected[preview$version_id == a1$version_id])
  expect_false(preview$protected[preview$version_id == o1$version_id])
  expect_error(st_prune_versions(selected, policy = 1L, dry_run = FALSE,
    alias = store$alias), "protected execution reference")
  expect_identical(m2_state_bytes(catalog_path), catalog_before)
  expect_identical(fs::dir_ls(store$root, recurse = TRUE, type = "file",
    regexp = "/versions/"), snapshots)
  expect_identical(lapply(snapshots, m2_state_bytes), bytes_before)
  expect_identical(stamp:::st_execution_info(child$path,
    alias = store$alias)$version_id, b1$version_id)
})

test_that("invalid committed proof refuses prune before unrelated deletion", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  other <- m2_state_request(store, "other.rds")
  m2_state_save(store, other)
  m2_state_save(store, other, list(value = 2L))
  before <- st_versions(other$path, alias = store$alias)
  fs::file_delete(fs::path(stamp:::.st_version_dir(
    "result.rds", saved$version_id, alias = store$alias
  ), "sidecar.json"))
  for (dry_run in c(TRUE, FALSE)) {
    expect_error(st_prune_versions(
      other$path, policy = 1L, dry_run = dry_run, alias = store$alias
    ))
  }
  expect_identical(st_versions(other$path, alias = store$alias), before)
})

test_that("retained output protects original parents even without old receipts", {
  store <- m2_state_store()
  parent <- m2_state_request(store, "parent.rds")
  a1 <- m2_state_save(store, parent)
  request <- m2_state_request(store, parents = list(list(
    path = parent$path, version_id = a1$version_id
  )))
  m2_state_save(store, request)
  a2 <- m2_state_save(store, parent, list(value = 2L))
  request$parents[[1L]]$version_id <- a2$version_id
  retained <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, retained, alias = store$alias
  )
  preview <- st_prune_versions(
    parent$path, policy = 1L, dry_run = TRUE, alias = store$alias
  )
  expect_true(preview$protected[preview$version_id == a1$version_id])
  expect_error(st_prune_versions(
    parent$path, policy = 1L, dry_run = FALSE, alias = store$alias
  ))
  expect_length(m2_state_committed(store, request), 1L)
})

test_that("automatic retention cannot delete an output pinned by a receipt", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  )
  st_opts(retain_versions = 1L)
  expect_error(m2_state_save(store, request, list(value = 2L)))
  expect_true(fs::file_exists(fs::path(stamp:::.st_version_dir(
    "result.rds", saved$version_id, alias = store$alias
  ), "artifact")))
  expect_length(m2_state_committed(store, request), 1L)
})

test_that("certified parents require persisted checksums before byte reuse", {
  store <- m2_state_store()
  local_st_opts(store_file_hash = FALSE)
  parent <- m2_state_request(store, "legacy-parent.rds")
  saved_parent <- st_save(list(value = 1L), parent$path,
    alias = store$alias, verbose = FALSE)
  parent_file <- fs::path(stamp:::.st_version_dir(
    "legacy-parent.rds", saved_parent$version_id, alias = store$alias
  ), "artifact")
  original <- m2_state_bytes(parent_file)
  changed <- original
  changed[length(changed)] <- as.raw(bitwXor(
    as.integer(changed[length(changed)]), 1L
  ))
  writeBin(changed, parent_file)
  expect_identical(length(m2_state_bytes(parent_file)), length(original))
  expect_no_error(stamp:::.st_execution_validate_pin(
    parent$path, saved_parent$version_id, alias = store$alias
  ))
  expect_error(stamp:::.st_execution_validate_pin(
    parent$path, saved_parent$version_id, alias = store$alias,
    require_checksum = TRUE
  ))
  request <- m2_state_request(store)
  saved <- m2_state_save(store, request)
  request$root <- FALSE
  request$parents <- list(list(
    path = parent$path, version_id = saved_parent$version_id
  ))
  expect_error(stamp:::.st_execution_success(
    request$path, request, saved, alias = store$alias
  ))
  expect_length(m2_state_committed(store, request), 0L)
  expect_identical(m2_state_bytes(parent_file), changed)
})

test_that("original retained ancestors also require persisted checksums", {
  store <- m2_state_store()
  local_st_opts(store_file_hash = FALSE)
  parent <- m2_state_request(store, "legacy-parent.rds")
  a1 <- st_save(list(value = 1L), parent$path,
    alias = store$alias, verbose = FALSE)
  st_opts(store_file_hash = TRUE)
  child <- m2_state_request(store)
  b1 <- st_save(list(value = 2L), child$path,
    parents = list(list(path = parent$path, version_id = a1$version_id)),
    alias = store$alias, verbose = FALSE)
  pin <- stamp:::.st_execution_validate_pin(
    child$path, b1$version_id, alias = store$alias
  )
  expect_error(stamp:::.st_execution_dependencies(pin, alias = store$alias))
})

test_that("abandoned exact next attempt names do not prevent publication", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  failure <- list(class = "external", message = "First attempt")
  first <- stamp:::st_record_outcome(
    request$path, "failed", request, failure, alias = store$alias
  )
  canonical <- stamp:::.st_request_normalize(request, alias = store$alias)
  next_id <- paste0("0000000002-", stamp:::.st_request_id(canonical))
  pending <- fs::path(m2_state_dir(store, request), "executions", next_id)
  fs::dir_create(pending)
  abandoned <- fs::path(pending, "receipt.json")
  writeLines("unfinished exact next attempt", abandoned)
  original <- m2_state_bytes(abandoned)
  second <- stamp:::st_record_outcome(
    request$path, "failed", request,
    list(class = "external", message = "Analyst-started second attempt"),
    alias = store$alias
  )
  expect_false(identical(second$id, next_id))
  expect_identical(second$sequence, 2L)
  expect_identical(second$previous_id, first$id)
  expect_identical(m2_state_bytes(abandoned), original)
  expect_false(fs::file_exists(fs::path(pending, "COMMITTED")))
  st_init(store$root, alias = store$alias, verbose = FALSE)
  expect_identical(stamp:::st_execution_info(
    request$path, second$id, alias = store$alias
  )$outcome, second)
  expect_identical(stamp:::st_execution_info(
    request$path, first$id, alias = store$alias
  )$outcome, first)
  expect_length(m2_state_committed(store, request), 2L)
})

test_that("proof encoding and request IDs ignore ALTREP representation", {
  compact <- seq_len(100L)
  ordinary <- integer(100L)
  ordinary[] <- compact
  expect_identical(compact, ordinary)
  expect_identical(stamp:::.st_proof_encode(compact),
    stamp:::.st_proof_encode(ordinary))
  store <- m2_state_store()
  request <- m2_state_request(store)
  request$semantic_schema <- list(values = list(
    type = "integer", shape = "vector", required = TRUE,
    nullable = FALSE, allow_na = TRUE
  ))
  request$semantic <- list(values = compact)
  first <- stamp:::.st_request_normalize(request, alias = store$alias)
  request$semantic$values <- ordinary
  second <- stamp:::.st_request_normalize(request, alias = store$alias)
  expect_identical(stamp:::.st_request_id(first), stamp:::.st_request_id(second))
  request$semantic$values <- 1L
  vector <- stamp:::.st_request_normalize(request, alias = store$alias)
  request$semantic_schema$values$shape <- "scalar"
  scalar <- stamp:::.st_request_normalize(request, alias = store$alias)
  expect_false(identical(stamp:::.st_request_id(vector),
    stamp:::.st_request_id(scalar)))
  distinct <- list(1L, 1, NA_integer_, NA_real_, NULL, integer(),
    c(value = 1L), list(1L))
  encoded <- vapply(distinct, stamp:::.st_proof_encode, character(1L))
  expect_equal(length(unique(encoded)), length(distinct))
  expect_identical(lapply(encoded, stamp:::.st_proof_decode), distinct)
})

test_that("checksum-valid receipt numbers reject coercible invalid JSON", {
  store <- m2_state_store()
  request <- m2_state_request(store)
  stamp:::st_record_outcome(
    request$path, "failed", request,
    list(class = "unknown", message = "Number validation"), alias = store$alias
  )
  marker <- m2_state_committed(store, request)
  receipt <- fs::path(fs::path_dir(marker), "receipt.json")
  original <- jsonlite::read_json(receipt, simplifyVector = FALSE)
  invalid <- list("1", TRUE, 1.5, 0L, -1L, .Machine$integer.max + 1,
    NA_real_, Inf, NULL, list(1L), c(1L, 1L))
  for (field in c("schema", "sequence")) {
    for (value in invalid) {
      wire <- original
      wire[field] <- list(value)
      jsonlite::write_json(wire, receipt,
        auto_unbox = TRUE, null = "null", na = "null", digits = NA)
      writeLines(stamp:::st_hash_file(receipt), marker)
      info <- stamp:::st_execution_info(request$path, alias = store$alias)
      expect_identical(info$state, "invalid")
      expect_identical(info$reason, "invalid_state")
      m2_state_expect_no_pin(info)
    }
  }
})

test_that("layered retained DAGs validate each ancestor once per operation", {
  store <- m2_state_store()
  local_st_opts(store_file_hash = TRUE)
  root <- m2_state_request(store, "dag-root.rds")
  saved <- st_save(list(value = 0L), root$path,
    alias = store$alias, verbose = FALSE)
  previous <- list(list(path = root$path, version_id = saved$version_id))
  for (level in seq_len(4L)) {
    layer <- lapply(seq_len(2L), function(branch) {
      request <- m2_state_request(store, paste0("dag-", level, "-", branch, ".rds"))
      saved <- st_save(list(value = level), request$path, parents = previous,
        alias = store$alias, verbose = FALSE)
      list(path = request$path, version_id = saved$version_id)
    })
    previous <- layer
  }
  top <- m2_state_request(store, "dag-top.rds")
  saved <- st_save(list(value = 5L), top$path, parents = previous,
    alias = store$alias, verbose = FALSE)
  pin <- stamp:::.st_execution_validate_pin(
    top$path, saved$version_id, alias = store$alias
  )
  original <- stamp:::.st_execution_validate_pin
  calls <- character()
  testthat::local_mocked_bindings(
    .st_execution_validate_pin = function(path, version_id, ...) {
      calls <<- c(calls, paste(path, version_id, sep = "\n"))
      original(path, version_id, ...)
    }, .package = "stamp"
  )
  references <- stamp:::.st_execution_dependencies(pin, alias = store$alias)
  expect_length(references, 10L)
  expect_length(calls, 9L)
  expect_false(anyDuplicated(calls) > 0L)
  calls <- character()
  expect_identical(stamp:::.st_execution_dependencies(
    pin, alias = store$alias
  ), references)
  expect_length(calls, 9L)
})

test_that("retained provenance cycles are rejected with memoized traversal", {
  store <- m2_state_store()
  local_st_opts(store_file_hash = TRUE)
  parent <- m2_state_request(store, "cycle-parent.rds")
  a1 <- st_save(list(value = 1L), parent$path,
    alias = store$alias, verbose = FALSE)
  child <- m2_state_request(store, "cycle-child.rds")
  b1 <- st_save(list(value = 2L), child$path,
    parents = list(list(path = parent$path, version_id = a1$version_id)),
    alias = store$alias, verbose = FALSE)
  directory <- stamp:::.st_version_dir(
    "cycle-parent.rds", a1$version_id, alias = store$alias
  )
  sidecar <- fs::path(directory, "sidecar.json")
  meta <- jsonlite::read_json(sidecar, simplifyVector = TRUE)
  meta$parents <- list(list(path = child$path, version_id = b1$version_id))
  jsonlite::write_json(meta, sidecar, auto_unbox = TRUE, digits = NA)
  stamp:::.st_version_write_parents(directory, meta$parents)
  pin <- stamp:::.st_execution_validate_pin(
    parent$path, a1$version_id, alias = store$alias
  )
  expect_error(stamp:::.st_execution_dependencies(
    pin, alias = store$alias
  ), "Cyclic")
})
