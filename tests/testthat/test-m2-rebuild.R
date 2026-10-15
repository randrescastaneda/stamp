# Independent of test-m2-state.R, which is loaded later in the suite.
m2_rb_store <- function(.local_envir = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = .local_envir)
  alias <- paste0("m2-rebuild-", basename(root))
  registries <- list(stamp:::.stamp_aliases, stamp:::.st_builders_env,
    stamp:::.stamp_state)
  old <- lapply(registries, as.list)
  withr::defer({
    for (i in seq_along(registries)) {
      env <- registries[[i]]
      rlang::env_unbind(env, rlang::env_names(env))
      if (length(old[[i]])) list2env(old[[i]], envir = env)
    }
  }, envir = .local_envir)
  local_st_opts(default_format = "rds", meta_format = "json",
    versioning = "content", retain_versions = Inf,
    .local_envir = .local_envir)
  st_init(root, alias = alias, verbose = FALSE)
  list(root = root, alias = alias)
}

# Lower-case fixture names keep trace keys identical on every platform.
m2_rb_request <- function(store, file = "a.rds", parents = list()) {
  component <- list(hash = "0123456789abcdef",
    algorithm = "siphash13", schema = "v1")
  list(schema = 1L, path = as.character(fs::path(store$root, file)),
    root = !length(parents), parents = parents,
    required_components = c("calculation", "helper", "constant", "rule"),
    components = list(calculation = component, helper = component,
      constant = component, rule = component),
    semantic_schema = NULL, semantic = list(), format = "rds")
}

m2_rb_parent <- function(request, version_id = NULL) {
  list(path = request$path, version_id = version_id)
}

m2_rb_chain <- function(store) {
  a <- m2_rb_request(store)
  b <- m2_rb_request(store, "b.rds", list(m2_rb_parent(a)))
  c <- m2_rb_request(store, "c.rds", list(m2_rb_parent(b)))
  list(a, b, c)
}

m2_rb_plan <- function(requests, targets = requests[[1L]]$path,
                       include_targets = TRUE, depth = Inf) {
  st_plan_rebuild(targets, depth = depth, include_targets = include_targets,
    requests = requests)
}

m2_rb_trace <- function() {
  trace <- new.env(parent = emptyenv())
  trace$calls <- character()
  trace$parents <- list()
  trace$payloads <- list()
  trace$metadata <- list()
  trace$failures <- list()
  trace
}

m2_rb_builder <- function(trace) {
  force(trace)
  function(path, parents) {
    name <- basename(stamp:::.st_normalize_path(path))
    trace$calls <- c(trace$calls, name)
    trace$parents[[name]] <- parents
    failure <- trace$failures[[name]]
    if (!is.null(failure)) {
      rlang::abort("Actual fixture failure", class = failure)
    }
    x <- trace$payloads[[name]]
    if (is.null(x)) x <- list(value = 1L)
    metadata <- trace$metadata[[name]]
    if (is.null(metadata)) metadata <- list()
    list(x = x, metadata = metadata)
  }
}

# Establish a real saved execution fact for decision-only tests.
m2_rb_seed <- function(store, request, x = list(value = 1L)) {
  saved <- st_save(x, request$path, request = request,
    metadata = request$semantic, alias = store$alias, verbose = FALSE)
  stamp:::.st_execution_success(request$path, request, saved,
    alias = store$alias)
}

m2_rb_records <- function(store, request) {
  stamp:::.st_execution_records(request$path, alias = store$alias)
}

m2_rb_row <- function(rows, file) {
  labels <- basename(stamp:::.st_normalize_path(rows$path))
  label <- basename(stamp:::.st_normalize_path(file))
  rows[labels == label, , drop = FALSE]
}

m2_rb_expect_decision <- function(plan, decision, reason) {
  expect_equal(nrow(plan), 1L)
  expect_identical(plan$decision, decision)
  expect_identical(plan$reason, reason)
}

m2_rb_expect_block <- function(result, reason) {
  expect_equal(nrow(result), 1L)
  expect_identical(result$status, "blocked")
  expect_identical(result$reason, reason)
  expect_true(is.na(result$version_id))
}

# Compare every file name and byte, including catalog, snapshots and receipts.
m2_rb_tree <- function(root) {
  paths <- sort(as.character(fs::dir_ls(root, recurse = TRUE,
    type = "file", all = TRUE)))
  bytes <- lapply(paths, function(path) {
    readBin(path, "raw", n = file.info(path)$size)
  })
  names(bytes) <- as.character(fs::path_rel(paths, root))
  bytes
}

m2_rb_snapshot <- function(store, request, version_id) {
  rel <- as.character(fs::path_rel(request$path, store$root))
  stamp:::.st_version_dir(rel, version_id, alias = store$alias)
}

m2_rb_pin_chain <- function(store, requests) {
  for (i in seq_along(requests)) {
    requests[[i]]$parents <- lapply(requests[[i]]$parents, function(parent) {
      parent$version_id <- st_latest(parent$path, alias = store$alias)
      parent
    })
  }
  requests
}

test_that("request-aware formals append without changing legacy shapes", {
  expect_identical(names(formals(st_plan_rebuild)),
    c("targets", "depth", "include_targets", "mode", "requests"))
  expect_null(formals(st_plan_rebuild)$requests)
  expect_identical(names(formals(st_rebuild)),
    c("plan", "rebuild_fun", "dry_run"))
  expect_identical(names(formals(st_is_stale)), c("path", "alias", "request"))
  expect_null(formals(st_is_stale)$request)
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  expect_identical(st_is_stale(request$path, store$alias), FALSE)
  expect_named(st_should_save(request$path, alias = store$alias),
    c("save", "reason"))
  legacy <- st_plan_rebuild(request$path)
  expect_named(legacy, c("level", "path", "reason", "latest_version_before"))
})

test_that("canonical reordered requests and audit edits reuse exact success", {
  store <- m2_rb_store()
  p <- m2_rb_request(store, "p.rds")
  q <- m2_rb_request(store, "q.rds")
  ps <- m2_rb_seed(store, p)
  qs <- m2_rb_seed(store, q)
  request <- m2_rb_request(store, parents = list(
    m2_rb_parent(q, qs$output$version_id),
    m2_rb_parent(p, ps$output$version_id)))
  saved <- m2_rb_seed(store, request)
  reordered <- request
  reordered$parents <- rev(reordered$parents)
  reordered$components <- rev(reordered$components)
  reordered$required_components <- rev(reordered$required_components)
  reordered$audit <- list(source = "new-sha", timestamp = "later")
  before <- m2_rb_tree(store$root)
  plan <- m2_rb_plan(list(reordered))
  m2_rb_expect_decision(plan, "skip", "current")
  expect_identical(plan$request_id, saved$request_id)
  expect_identical(plan$receipt_id, saved$id)
  trace <- m2_rb_trace()
  out <- st_rebuild(plan, m2_rb_builder(trace))
  expect_identical(out$status, "skipped")
  expect_identical(out$version_id, saved$output$version_id)
  expect_length(trace$calls, 0L)
  expect_identical(m2_rb_tree(store$root), before)
})

test_that("each declared calculation helper constant and rule selects work", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  m2_rb_seed(store, request)
  for (id in request$required_components) {
    changed <- request
    changed$components[[id]]$hash <- "1111111111111111"
    m2_rb_expect_decision(m2_rb_plan(list(changed)), "run", "request_changed")
  }
})

test_that("missing requested hashes fail closed before builders and writes", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  m2_rb_seed(store, request)
  for (id in c("calculation", "helper")) {
    for (hash in list(NULL, NA_character_, "")) {
      bad <- request
      bad$components[[id]]["hash"] <- list(hash)
      before <- m2_rb_tree(store$root)
      plan <- m2_rb_plan(list(bad))
      m2_rb_expect_decision(plan, "blocked", "missing_requested_proof")
      expect_identical(m2_rb_tree(store$root), before)
      trace <- m2_rb_trace()
      out <- st_rebuild(plan, m2_rb_builder(trace))
      m2_rb_expect_block(out, "missing_requested_proof")
      expect_length(trace$calls, 0L)
      expect_error(st_is_stale(bad$path, alias = store$alias, request = bad),
        class = "stamp_blocked_request")
    }
  }
})

test_that("incomparable saved algorithms and schemas never mean changed", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  m2_rb_seed(store, request)
  for (field in c("algorithm", "schema")) {
    bad <- request
    if (field == "algorithm") {
      bad$components$helper$algorithm <- "sha256"
      bad$components$helper$hash <- paste(rep("1", 64L), collapse = "")
    } else {
      bad$components$helper$schema <- "v2"
    }
    before <- m2_rb_tree(store$root)
    plan <- m2_rb_plan(list(bad))
    m2_rb_expect_decision(plan, "blocked", "incomparable_proof")
    expect_identical(m2_rb_tree(store$root), before)
    trace <- m2_rb_trace()
    m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)),
      "incomparable_proof")
    expect_length(trace$calls, 0L)
  }
})

test_that("structural normalization defers availability but not root proof", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  request$root <- FALSE
  m2_rb_expect_decision(m2_rb_plan(list(request)), "blocked", "invalid_request")
  chain <- m2_rb_chain(store)
  normalized <- stamp:::.st_request_normalize(chain[[2L]], store$alias,
    allow_deferred = TRUE)
  expect_null(normalized$parents[[1L]]$version_id)
  pinned <- chain[[2L]]
  pinned$parents[[1L]]$version_id <- "not-yet-available"
  expect_no_error(stamp:::.st_request_normalize(pinned, store$alias))
  m2_rb_expect_decision(m2_rb_plan(list(pinned)), "blocked", "missing_parent")
  bad <- chain[[2L]]
  bad$root <- TRUE
  m2_rb_expect_decision(m2_rb_plan(list(bad)), "blocked", "invalid_request")
})

test_that("empty-store explicit chain resolves parents before each invocation", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  before <- m2_rb_tree(store$root)
  plan <- m2_rb_plan(requests)
  expect_identical(basename(plan$path), c("a.rds", "b.rds", "c.rds"))
  expect_identical(plan$decision, rep("run", 3L))
  expect_identical(plan$reason, c("missing_output", rep("pending_parent", 2L)))
  expect_true(all(is.na(plan$request_id[2:3])))
  expect_identical(m2_rb_tree(store$root), before)
  trace <- m2_rb_trace()
  out <- st_rebuild(plan, m2_rb_builder(trace))
  expect_identical(trace$calls, c("a.rds", "b.rds", "c.rds"))
  expect_identical(out$status, rep("built", 3L))
  expect_true(all(c("level", "path", "reason", "status", "version_id",
    "msg", "request_id", "receipt_id", "outcome_id") %in% names(out)))
  for (i in 2:3) {
    record <- m2_rb_records(store, requests[[i]])[[1L]]
    expect_identical(record$request_kind, "effective")
    expect_identical(record$request$parents[[1L]]$version_id,
      out$version_id[[i - 1L]])
    label <- basename(stamp:::.st_normalize_path(requests[[i]]$path))
    expect_identical(trace$parents[[label]], record$request$parents)
    expect_false(startsWith(record$request_id, "preview-"))
  }
})

test_that("diamond and overlapping targets use lexical topological one visit", {
  store <- m2_rb_store()
  chain <- m2_rb_chain(store)
  d <- m2_rb_request(store, "d.rds", list(m2_rb_parent(chain[[1L]])))
  chain[[3L]]$parents <- list(m2_rb_parent(d), m2_rb_parent(chain[[2L]]))
  requests <- list(chain[[3L]], d, chain[[2L]], chain[[1L]])
  plan <- m2_rb_plan(requests,
    targets = c(chain[[1L]]$path, chain[[2L]]$path, chain[[1L]]$path))
  trace <- m2_rb_trace()
  out <- st_rebuild(plan, m2_rb_builder(trace))
  expect_identical(trace$calls, c("a.rds", "b.rds", "d.rds", "c.rds"))
  expect_equal(nrow(out), 4L)
  expect_identical(out$status, rep("built", 4L))
  expect_equal(anyDuplicated(out$path), 0L)
})

test_that("cycles reject before builder invocation or any durable write", {
  store <- m2_rb_store()
  for (self in c(TRUE, FALSE)) {
    requests <- m2_rb_chain(store)
    requests[[1L]]$root <- FALSE
    requests[[1L]]$parents <- list(m2_rb_parent(
      if (self) requests[[1L]] else requests[[3L]]))
    before <- m2_rb_tree(store$root)
    trace <- m2_rb_trace()
    expect_error(st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace)))
    expect_length(trace$calls, 0L)
    expect_identical(m2_rb_tree(store$root), before)
  }
})

test_that("duplicate normalized recipe identity rejects without writes", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  duplicate <- request
  duplicate$path <- as.character(fs::path(store$root, ".", "a.rds"))
  before <- m2_rb_tree(store$root)
  expect_error(m2_rb_plan(list(request, duplicate)))
  expect_identical(m2_rb_tree(store$root), before)
})

test_that("depth and include_targets bound current explicit graph scope", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  trace <- m2_rb_trace()
  st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  requests <- m2_rb_pin_chain(store, requests)
  one <- m2_rb_plan(requests, depth = 1L, include_targets = FALSE)
  expect_identical(basename(one$path), "b.rds")
  expect_equal(one$level, 1L)
  two <- m2_rb_plan(requests, depth = 2L, include_targets = FALSE)
  expect_identical(basename(two$path), c("b.rds", "c.rds"))
  all <- m2_rb_plan(requests, depth = 2L)
  expect_identical(basename(all$path), c("a.rds", "b.rds", "c.rds"))
  expect_equal(all$level, 0:2)
  expect_identical(all$decision, rep("skip", 3L))
})

test_that("missing external or unselected parent never acquires a recipe", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  before <- m2_rb_tree(store$root)
  plan <- m2_rb_plan(list(requests[[2L]]))
  m2_rb_expect_decision(plan, "blocked", "missing_parent")
  expect_identical(m2_rb_tree(store$root), before)
  trace <- m2_rb_trace()
  m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)), "missing_parent")
  expect_length(trace$calls, 0L)
  # An explicit but unselected root cannot supply a deferred input either.
  plan <- m2_rb_plan(requests, targets = requests[[2L]]$path, depth = 1L)
  expect_identical(m2_rb_row(plan, "b.rds")$decision, "blocked")
  expect_identical(m2_rb_row(plan, "b.rds")$reason, "missing_parent")
})

test_that("preview cannot silently bind an externally advanced parent", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  first <- m2_rb_seed(store, parent)
  child <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(parent, first$output$version_id)))
  plan <- m2_rb_plan(list(child))
  m2_rb_seed(store, parent, list(value = 2L))
  trace <- m2_rb_trace()
  m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)), "inputs_changed")
  expect_length(trace$calls, 0L)
  expect_true(is.na(st_latest(child$path, alias = store$alias)))
})

test_that("unchanged external latest does not replace an explicit historical pin", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  first <- m2_rb_seed(store, parent)
  m2_rb_seed(store, parent, list(value = 2L))
  child <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(parent, first$output$version_id)))
  plan <- m2_rb_plan(list(child))
  m2_rb_expect_decision(plan, "run", "missing_output")
  trace <- m2_rb_trace()
  out <- st_rebuild(plan, m2_rb_builder(trace))
  expect_identical(out$status, "built")
  expect_identical(trace$parents[["b.rds"]][[1L]]$version_id,
    first$output$version_id)
  expect_identical(m2_rb_records(store, child)[[1L]]$request$parents[[1L]],
    stamp:::.st_request_normalize(child, store$alias)$parents[[1L]])
})

test_that("failed prerequisite blocks deferred descendants not independent work", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  independent <- m2_rb_request(store, "z.rds")
  requests <- c(requests, list(independent))
  trace <- m2_rb_trace()
  trace$failures[["a.rds"]] <- "stamp_deterministic_failure"
  out <- st_rebuild(m2_rb_plan(requests,
    targets = c(requests[[1L]]$path, independent$path)), m2_rb_builder(trace))
  expect_identical(trace$calls, c("a.rds", "z.rds"))
  expect_identical(m2_rb_row(out, "a.rds")$status, "failed")
  for (file in c("b.rds", "c.rds")) {
    row <- m2_rb_row(out, file)
    m2_rb_expect_block(row, "failed_parent")
    request <- requests[[match(file, vapply(requests,
      function(x) basename(x$path), character(1L)))]]
    record <- m2_rb_records(store, request)[[1L]]
    expect_identical(record$outcome, "blocked")
    expect_null(record$output)
    expect_identical(record$request_kind, "preview")
  }
  expect_identical(m2_rb_row(out, "z.rds")$status, "built")
})

test_that("deterministic recovery requires both change and governing review", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  trace <- m2_rb_trace()
  trace$failures[["a.rds"]] <- "stamp_deterministic_failure"
  first <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(first$status, "failed")
  failure_id <- first$outcome_id
  expect_identical(m2_rb_records(store, request)[[1L]]$outcome,
    "failed_deterministic")
  trace$failures <- list()
  trace$calls <- character()
  changed <- request
  changed$components$rule$hash <- "1111111111111111"
  reviewed <- request
  reviewed$review <- list(outcome_id = failure_id)
  for (case in list(
    list(request = request, reason = "deterministic_failure"),
    list(request = changed, reason = "review_required"),
    list(request = reviewed, reason = "review_change_required")
  )) {
    plan <- m2_rb_plan(list(case$request))
    m2_rb_expect_decision(plan, "blocked", case$reason)
    m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)), case$reason)
    st_init(store$root, alias = store$alias, verbose = FALSE)
    records <- m2_rb_records(store, request)
    expect_identical(records[[1L]]$id, failure_id)
    expect_identical(records[[length(records)]]$outcome, "blocked")
  }
  expect_length(trace$calls, 0L)
  changed$review <- list(outcome_id = failure_id)
  out <- st_rebuild(m2_rb_plan(list(changed)), m2_rb_builder(trace))
  expect_identical(out$status, "built")
  expect_identical(trace$calls, "a.rds")
  again <- st_rebuild(m2_rb_plan(list(changed)), m2_rb_builder(trace))
  expect_identical(again$status, "skipped")
  expect_identical(trace$calls, "a.rds")
})

test_that("source audit alone is neither retry change nor deterministic review", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  fact <- stamp:::st_record_outcome(request$path, "failed", request,
    list(class = "deterministic", message = "Declared failure"), store$alias)
  request$audit <- list(source = "unrelated-new-source-sha")
  m2_rb_expect_decision(m2_rb_plan(list(request)), "blocked",
    "deterministic_failure")
  request$review <- list(outcome_id = fact$id)
  plan <- m2_rb_plan(list(request))
  m2_rb_expect_decision(plan, "blocked", "review_change_required")
  trace <- m2_rb_trace()
  m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)),
    "review_change_required")
  expect_length(trace$calls, 0L)
})

test_that("external actual failure is attempted once per analyst call only", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  trace <- m2_rb_trace()
  trace$failures[["a.rds"]] <- "stamp_external_failure"
  first <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(first$status, "failed")
  expect_identical(trace$calls, "a.rds")
  m2_rb_expect_decision(m2_rb_plan(list(request)), "run", "external_retry")
  second <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(second$status, "failed")
  expect_identical(trace$calls, rep("a.rds", 2L))
  expect_length(m2_rb_records(store, request), 2L)
  trace$failures <- list()
  third <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(third$status, "built")
  expect_identical(trace$calls, rep("a.rds", 3L))
  expect_identical(st_rebuild(m2_rb_plan(list(request)),
    m2_rb_builder(trace))$status, "skipped")
  expect_length(trace$calls, 3L)
})

test_that("blocked missing-parent observation preserves external retry on reread", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  saved <- m2_rb_seed(store, parent)
  request <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(parent, saved$output$version_id)))
  fact <- stamp:::st_record_outcome(request$path, "failed", request,
    list(class = "external", message = "Temporary failure"), store$alias)
  pin <- stamp:::.st_execution_validate_pin(parent$path,
    saved$output$version_id, store$alias, require_checksum = TRUE)
  bytes <- readBin(pin$norm$storage_path, "raw",
    n = file.info(pin$norm$storage_path)$size)
  fs::file_delete(pin$norm$storage_path)
  trace <- m2_rb_trace()
  m2_rb_expect_block(st_rebuild(m2_rb_plan(list(request)),
    m2_rb_builder(trace)), "missing_parent")
  expect_length(trace$calls, 0L)
  writeBin(bytes, pin$norm$storage_path)
  st_init(store$root, alias = store$alias, verbose = FALSE)
  records <- m2_rb_records(store, request)
  expect_identical(records[[1L]]$id, fact$id)
  expect_identical(records[[2L]]$outcome, "blocked")
  m2_rb_expect_decision(m2_rb_plan(list(request)), "run", "external_retry")
  out <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(out$status, "built")
  expect_identical(trace$calls, "b.rds")
})

test_that("unknown actual failure blocks despite older success and changes", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  m2_rb_seed(store, request)
  changed <- request
  changed$components$helper$hash <- "1111111111111111"
  trace <- m2_rb_trace()
  trace$failures[["a.rds"]] <- "unclassified_fixture_error"
  out <- st_rebuild(m2_rb_plan(list(changed)), m2_rb_builder(trace))
  expect_identical(out$status, "failed")
  records <- m2_rb_records(store, request)
  expect_identical(records[[length(records)]]$outcome, "failed_unknown")
  changed$components$rule$hash <- "2222222222222222"
  changed$review <- list(outcome_id = out$outcome_id)
  trace$calls <- character()
  trace$failures <- list()
  m2_rb_expect_decision(m2_rb_plan(list(changed)), "blocked", "unknown_failure")
  m2_rb_expect_block(st_rebuild(m2_rb_plan(list(changed)),
    m2_rb_builder(trace)), "unknown_failure")
  expect_length(trace$calls, 0L)
})

test_that("complete request recovers legacy absence once not damaged modern proof", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  st_save(list(value = 1L), request$path, alias = store$alias, verbose = FALSE)
  m2_rb_expect_decision(m2_rb_plan(list(request)), "run", "missing_saved_proof")
  trace <- m2_rb_trace()
  out <- st_rebuild(m2_rb_plan(list(request)), m2_rb_builder(trace))
  expect_identical(out$status, "built")
  expect_identical(trace$calls, "a.rds")
  before <- m2_rb_tree(store$root)
  expect_identical(st_rebuild(m2_rb_plan(list(request)),
    m2_rb_builder(trace))$status, "skipped")
  expect_identical(trace$calls, "a.rds")
  expect_identical(m2_rb_tree(store$root), before)
  norm <- stamp:::.st_execution_path(request$path, store$alias)
  receipt <- fs::path(norm$storage_dir, "executions", out$receipt_id,
    "receipt.json")
  writeLines("corrupt committed receipt", receipt)
  m2_rb_expect_decision(m2_rb_plan(list(request)), "blocked", "invalid_state")
  m2_rb_expect_block(st_rebuild(m2_rb_plan(list(request)),
    m2_rb_builder(trace)), "invalid_state")
  expect_identical(trace$calls, "a.rds")
})

test_that("identified modern missing or unknown proof never permits recovery", {
  for (damage in c("missing", "unknown")) {
    store <- m2_rb_store()
    request <- m2_rb_request(store)
    st_save(list(value = 1L), request$path, request = request,
      alias = store$alias, verbose = FALSE)
    norm <- stamp:::.st_execution_path(request$path, store$alias)
    sidecar <- stamp:::.st_sidecar_path(norm$rel_path, "json", store$alias)
    meta <- jsonlite::read_json(sidecar, simplifyVector = FALSE)
    if (damage == "missing") meta$execution <- NULL else
      meta$execution$schema <- 99L
    jsonlite::write_json(meta, sidecar, auto_unbox = TRUE, null = "null")
    trace <- m2_rb_trace()
    m2_rb_expect_decision(m2_rb_plan(list(request)), "blocked", "invalid_state")
    m2_rb_expect_block(st_rebuild(m2_rb_plan(list(request)),
      m2_rb_builder(trace)), "invalid_state")
    expect_length(trace$calls, 0L)
  }
})

test_that("planning and dry run write nothing and raw no-op save proves no build", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  st_save(list(value = 1L), request$path, request = request,
    alias = store$alias, verbose = FALSE)
  noop <- st_save(list(value = 1L), request$path, request = request,
    alias = store$alias, verbose = FALSE)
  expect_true(noop$skipped)
  expect_length(m2_rb_records(store, request), 0L)
  before <- m2_rb_tree(store$root)
  trace <- m2_rb_trace()
  plan <- m2_rb_plan(list(request))
  expect_identical(plan$decision, "run")
  expect_true(st_is_stale(request$path, store$alias, request = request))
  out <- st_rebuild(plan, m2_rb_builder(trace), dry_run = TRUE)
  expect_identical(out$status, "dry_run")
  expect_true(is.na(out$version_id))
  expect_length(trace$calls, 0L)
  expect_identical(m2_rb_tree(store$root), before)
  expect_identical(st_rebuild(plan, m2_rb_builder(trace))$status, "unchanged")
  expect_identical(trace$calls, "a.rds")
  expect_length(m2_rb_records(store, request), 1L)
  expect_false(st_is_stale(request$path, store$alias, request = request))
})

test_that("V8 actual A2 build retains B1 with new receipt and never invokes C", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  trace <- m2_rb_trace()
  builder <- m2_rb_builder(trace)
  for (request in requests) st_register_builder(request$path, builder)
  initial <- st_rebuild(m2_rb_plan(requests))
  expect_identical(initial$status, rep("built", 3L))
  requests <- m2_rb_pin_chain(store, requests)
  a1 <- initial$version_id[[1L]]
  b1 <- initial$version_id[[2L]]
  c1 <- initial$version_id[[3L]]
  bdir <- m2_rb_snapshot(store, requests[[2L]], b1)
  original <- m2_rb_tree(bdir)
  old_sidecar <- st_read_sidecar(requests[[2L]]$path,
    alias = store$alias, version_id = b1)
  old_b_receipt <- m2_rb_records(store, requests[[2L]])[[1L]]
  requests[[1L]]$components$calculation$hash <- "1111111111111111"
  trace$payloads[["a.rds"]] <- list(value = 2L)
  trace$calls <- character()
  out <- st_rebuild(m2_rb_plan(requests))
  expect_identical(trace$calls, c("a.rds", "b.rds"))
  expect_identical(out$status, c("built", "unchanged", "skipped"))
  expect_false(identical(out$version_id[[1L]], a1))
  expect_identical(out$version_id[2:3], c(b1, c1))
  b_records <- m2_rb_records(store, requests[[2L]])
  expect_length(b_records, 2L)
  expect_identical(b_records[[1L]], old_b_receipt)
  expect_identical(b_records[[2L]]$outcome, "success_unchanged")
  expect_identical(b_records[[2L]]$output$version_id, b1)
  expect_identical(b_records[[2L]]$request$parents[[1L]]$version_id,
    out$version_id[[1L]])
  expect_identical(
    stamp:::.st_parents_normalize(old_sidecar$parents)[[1L]]$version_id, a1)
  expect_identical(m2_rb_tree(bdir), original)
  expect_identical(st_read_sidecar(requests[[2L]]$path,
    alias = store$alias, version_id = b1), old_sidecar)
  expect_equal(nrow(st_versions(requests[[2L]]$path, store$alias)), 1L)
  expect_length(m2_rb_records(store, requests[[3L]]), 1L)
  requests <- m2_rb_pin_chain(store, requests)
  before <- m2_rb_tree(store$root)
  trace$calls <- character()
  for (i in 1:2) {
    st_init(store$root, alias = store$alias, verbose = FALSE)
    again <- st_rebuild(m2_rb_plan(requests))
    expect_identical(again$status, rep("skipped", 3L))
    expect_identical(again$version_id, out$version_id)
    expect_length(trace$calls, 0L)
    expect_identical(m2_rb_tree(store$root), before)
  }

  # A genuine fresh process, using this run's installed library, not pkgload.
  scratch <- withr::local_tempdir()
  input <- fs::path(scratch, "requests.rds")
  script <- fs::path(scratch, "convergence.R")
  output <- fs::path(scratch, "result.rds")
  saveRDS(list(store = store, requests = requests), input)
  literal <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = "\n")
  writeLines(c(
    paste0(".libPaths(", literal(.libPaths()), ")"),
    "library(stamp)",
    paste0("fixture <- readRDS(", literal(as.character(input)), ")"),
    "st_opts(default_format = 'rds', meta_format = 'json',",
    "  versioning = 'content', retain_versions = Inf)",
    "st_init(fixture$store$root, alias = fixture$store$alias, verbose = FALSE)",
    "calls <- 0L",
    "builder <- function(path, parents) {",
    "  calls <<- calls + 1L; stop('Satisfied request invoked a builder')",
    "}",
    "plan <- st_plan_rebuild(fixture$requests[[1L]]$path,",
    "  include_targets = TRUE, requests = fixture$requests)",
    "result <- st_rebuild(plan, builder)",
    "stopifnot(calls == 0L, nrow(result) == 3L,",
    "  all(result$status == 'skipped'))",
    paste0("saveRDS(list(result = result, calls = calls), ",
      literal(as.character(output)), ")")
  ), script)
  process <- system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(as.character(script))), stdout = TRUE, stderr = TRUE)
  status <- attr(process, "status")
  if (is.null(status)) status <- 0L
  expect_identical(status, 0L, info = paste(process, collapse = "\n"))
  expect_true(file.exists(output))
  restarted <- readRDS(output)
  expect_identical(restarted$calls, 0L)
  expect_identical(restarted$result$version_id, out$version_id)
  expect_identical(m2_rb_tree(store$root), before)
})

test_that("changed B component with equal payload creates version and rechecks C", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  trace <- m2_rb_trace()
  initial <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  requests <- m2_rb_pin_chain(store, requests)
  bdir <- m2_rb_snapshot(store, requests[[2L]], initial$version_id[[2L]])
  original <- m2_rb_tree(bdir)
  requests[[2L]]$components$helper$hash <- "1111111111111111"
  trace$calls <- character()
  out <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  expect_identical(trace$calls, c("b.rds", "c.rds"))
  expect_identical(m2_rb_row(out, "b.rds")$status, "built")
  expect_false(identical(out$version_id[[2L]], initial$version_id[[2L]]))
  expect_identical(trace$parents[["c.rds"]][[1L]]$version_id,
    out$version_id[[2L]])
  expect_identical(m2_rb_tree(bdir), original)
})

test_that("changed B semantic proof with equal payload creates a new version", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  requests[[2L]]$semantic_schema <- list(unit = list(type = "character",
    shape = "scalar", required = TRUE, nullable = FALSE, allow_na = FALSE))
  requests[[2L]]$semantic <- list(unit = "old")
  trace <- m2_rb_trace()
  trace$metadata[["b.rds"]] <- list(unit = "old")
  initial <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  requests <- m2_rb_pin_chain(store, requests)
  bdir <- m2_rb_snapshot(store, requests[[2L]], initial$version_id[[2L]])
  original <- m2_rb_tree(bdir)
  requests[[2L]]$semantic$unit <- "new"
  trace$metadata[["b.rds"]] <- list(unit = "new")
  trace$calls <- character()
  out <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  expect_identical(trace$calls, c("b.rds", "c.rds"))
  expect_identical(m2_rb_row(out, "b.rds")$status, "built")
  expect_false(identical(out$version_id[[2L]], initial$version_id[[2L]]))
  expect_identical(m2_rb_tree(bdir), original)
})

test_that("effective and original ancestor byte proof is checked before builders", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  trace <- m2_rb_trace()
  initial <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  requests <- m2_rb_pin_chain(store, requests)
  requests[[1L]]$components$calculation$hash <- "1111111111111111"
  trace$payloads[["a.rds"]] <- list(value = 2L)
  second <- st_rebuild(m2_rb_plan(requests), m2_rb_builder(trace))
  expect_identical(second$version_id[[2L]], initial$version_id[[2L]])
  requests <- m2_rb_pin_chain(store, requests)
  child <- requests[[3L]]
  child$components$helper$hash <- "2222222222222222"
  plan <- m2_rb_plan(list(child))
  old_a <- fs::path(m2_rb_snapshot(store, requests[[1L]],
    initial$version_id[[1L]]), "artifact")
  bytes <- readBin(old_a, "raw", n = file.info(old_a)$size)
  bytes[[length(bytes)]] <- as.raw(bitwXor(as.integer(bytes[[length(bytes)]]), 1L))
  writeBin(bytes, old_a)
  trace$calls <- character()
  m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)), "invalid_state")
  expect_length(trace$calls, 0L)
})

test_that("only absent current bytes permit recovery not missing retained proof", {
  for (damage in c("current", "snapshot", "sidecar", "current_corrupt")) {
    store <- m2_rb_store()
    request <- m2_rb_request(store)
    saved <- m2_rb_seed(store, request)
    pin <- stamp:::.st_execution_validate_pin(request$path,
      saved$output$version_id, store$alias, require_checksum = TRUE)
    snapshot <- m2_rb_snapshot(store, request, saved$output$version_id)
    if (damage == "current") fs::file_delete(pin$norm$storage_path)
    if (damage == "snapshot") fs::file_delete(fs::path(snapshot, "artifact"))
    if (damage == "sidecar") fs::file_delete(fs::path(snapshot, "sidecar.json"))
    if (damage == "current_corrupt") {
      writeBin(as.raw(c(1L, 2L, 3L)), pin$norm$storage_path)
    }
    trace <- m2_rb_trace()
    plan <- m2_rb_plan(list(request))
    if (damage == "current") {
      m2_rb_expect_decision(plan, "run", "missing_output")
      out <- st_rebuild(plan, m2_rb_builder(trace))
      expect_identical(out$status, "built")
      expect_identical(trace$calls, "a.rds")
      expect_false(is.na(out$version_id))
    } else {
      m2_rb_expect_decision(plan, "blocked", "invalid_state")
      m2_rb_expect_block(st_rebuild(plan, m2_rb_builder(trace)), "invalid_state")
      expect_length(trace$calls, 0L)
    }
  }
})

test_that("missing current bytes do not override governing deterministic failure", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  saved <- m2_rb_seed(store, request)
  stamp:::st_record_outcome(request$path, "failed", request,
    list(class = "deterministic", message = "Actual failure after success"),
    store$alias)
  pin <- stamp:::.st_execution_validate_pin(request$path,
    saved$output$version_id, store$alias, require_checksum = TRUE)
  fs::file_delete(pin$norm$storage_path)
  trace <- m2_rb_trace()
  m2_rb_expect_decision(m2_rb_plan(list(request)), "blocked",
    "deterministic_failure")
  m2_rb_expect_block(st_rebuild(m2_rb_plan(list(request)),
    m2_rb_builder(trace)), "deterministic_failure")
  expect_length(trace$calls, 0L)
})

test_that("current explicit edges replace obsolete catalog reverse edges", {
  store <- m2_rb_store()
  a <- m2_rb_request(store)
  d <- m2_rb_request(store, "d.rds")
  av <- m2_rb_seed(store, a)
  dv <- m2_rb_seed(store, d)
  b <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(a, av$output$version_id)))
  m2_rb_seed(store, b)
  # Current recipe replaces A -> B with D -> B; history still records A.
  b$parents <- list(m2_rb_parent(d, dv$output$version_id))
  plan <- m2_rb_plan(list(a, b, d), targets = a$path,
    include_targets = FALSE)
  expect_equal(nrow(plan), 0L)
  selected <- m2_rb_plan(list(a, b, d), targets = d$path,
    include_targets = FALSE)
  expect_identical(basename(selected$path), "b.rds")
  m2_rb_expect_decision(selected, "run", "request_changed")
})

test_that("dry run of deferred graph neither invokes builders nor writes state", {
  store <- m2_rb_store()
  requests <- m2_rb_chain(store)
  before <- m2_rb_tree(store$root)
  trace <- m2_rb_trace()
  plan <- m2_rb_plan(requests)
  expect_true(all(c("request", "decision", "request_id", "receipt_id",
    "level", "path", "reason", "latest_version_before") %in% names(plan)))
  out <- st_rebuild(plan, m2_rb_builder(trace), dry_run = TRUE)
  expect_identical(out$status, rep("dry_run", 3L))
  expect_true(all(is.na(out$version_id)))
  expect_length(trace$calls, 0L)
  expect_identical(m2_rb_tree(store$root), before)
})

test_that("selected skipped A2 preserves matching child's explicit A1 pin", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  a1 <- m2_rb_seed(store, parent)
  child <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(parent, a1$output$version_id)))
  b1 <- m2_rb_seed(store, child)
  a2 <- m2_rb_seed(store, parent, list(value = 2L))
  before <- m2_rb_tree(store$root)
  trace <- m2_rb_trace()
  out <- st_rebuild(m2_rb_plan(list(parent, child)), m2_rb_builder(trace))
  expect_identical(out$status, rep("skipped", 2L))
  expect_identical(out$version_id, c(a2$output$version_id, b1$output$version_id))
  expect_length(trace$calls, 0L)
  expect_identical(m2_rb_tree(store$root), before)
  expect_identical(m2_rb_records(store, child)[[1L]]$request$parents[[1L]],
    stamp:::.st_request_normalize(child, store$alias)$parents[[1L]])
})

test_that("child builder retains explicit A1 when selected A2 skips", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  a1 <- m2_rb_seed(store, parent)
  m2_rb_seed(store, parent, list(value = 2L))
  child <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(parent, a1$output$version_id)))
  trace <- m2_rb_trace()
  out <- st_rebuild(m2_rb_plan(list(parent, child)), m2_rb_builder(trace))
  expect_identical(out$status, c("skipped", "built"))
  expect_identical(trace$calls, "b.rds")
  expect_identical(trace$parents[["b.rds"]][[1L]]$version_id,
    a1$output$version_id)
  expect_identical(m2_rb_records(store, child)[[1L]]$request$parents,
    stamp:::.st_request_normalize(child, store$alias)$parents)
})

test_that("deferred child may use validated selected skipped output", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  a2 <- m2_rb_seed(store, parent, list(value = 2L))
  child <- m2_rb_request(store, "b.rds", list(m2_rb_parent(parent)))
  trace <- m2_rb_trace()
  out <- st_rebuild(m2_rb_plan(list(parent, child)), m2_rb_builder(trace))
  expect_identical(out$status, c("skipped", "built"))
  expect_identical(trace$calls, "b.rds")
  expect_identical(trace$parents[["b.rds"]][[1L]]$version_id,
    a2$output$version_id)
})

test_that("preserving historical pin still checks selected parent's latest", {
  store <- m2_rb_store()
  parent <- m2_rb_request(store)
  a1 <- m2_rb_seed(store, parent)
  m2_rb_seed(store, parent, list(value = 2L))
  independent <- m2_rb_request(store, "b.rds")
  child <- m2_rb_request(store, "c.rds",
    list(m2_rb_parent(parent, a1$output$version_id)))
  trace <- m2_rb_trace()
  builder <- function(path, parents) {
    trace$calls <- c(trace$calls, basename(path))
    if (basename(path) == "b.rds") {
      m2_rb_seed(store, parent, list(value = 3L))
    }
    list(x = list(value = 1L))
  }
  out <- st_rebuild(m2_rb_plan(list(parent, independent, child),
    targets = c(parent$path, independent$path)), builder)
  expect_identical(trace$calls, "b.rds")
  expect_identical(m2_rb_row(out, "a.rds")$status, "skipped")
  m2_rb_expect_block(m2_rb_row(out, "c.rds"), "inputs_changed")
})

test_that("missing builder configuration is recoverable after registration", {
  store <- m2_rb_store()
  st_clear_builders()
  request <- m2_rb_request(store)
  out <- st_rebuild(m2_rb_plan(list(request)))
  m2_rb_expect_block(out, "invalid_request")
  records <- m2_rb_records(store, request)
  expect_length(records, 1L)
  expect_identical(records[[1L]]$outcome, "blocked")
  expect_null(records[[1L]]$output)
  expect_false(any(vapply(records, function(x) x$outcome == "failed_unknown",
    logical(1L))))
  trace <- m2_rb_trace()
  st_register_builder(request$path, m2_rb_builder(trace))
  fixed <- st_rebuild(m2_rb_plan(list(request)))
  expect_identical(fixed$status, "built")
  expect_identical(trace$calls, "a.rds")
  expect_identical(m2_rb_records(store, request)[[2L]]$outcome, "success_new")
})

test_that("invalid explicit rebuild function rejects without durable failure", {
  store <- m2_rb_store()
  request <- m2_rb_request(store)
  plan <- m2_rb_plan(list(request))
  before <- m2_rb_tree(store$root)
  error <- tryCatch(st_rebuild(plan, rebuild_fun = "not a function"),
    error = identity)
  expect_s3_class(error, "stamp_blocked_request")
  expect_identical(error$reason, "invalid_request")
  expect_identical(m2_rb_tree(store$root), before)
  expect_length(m2_rb_records(store, request), 0L)
  trace <- m2_rb_trace()
  expect_identical(st_rebuild(plan, m2_rb_builder(trace))$status, "built")
  expect_identical(trace$calls, "a.rds")
})

test_that("included target boundary requires every normalized explicit recipe", {
  store <- m2_rb_store()
  a <- m2_rb_request(store)
  b <- m2_rb_request(store, "b.rds")
  unrelated <- m2_rb_request(store, "z.rds")
  for (case in list(
    list(targets = a$path, requests = list()),
    list(targets = a$path, requests = list(unrelated)),
    list(targets = c(a$path, b$path), requests = list(a))
  )) {
    before <- m2_rb_tree(store$root)
    trace <- m2_rb_trace()
    error <- tryCatch(st_rebuild(st_plan_rebuild(case$targets,
      include_targets = TRUE, requests = case$requests), m2_rb_builder(trace)),
      error = identity)
    expect_s3_class(error, "stamp_blocked_request")
    expect_identical(error$reason, "invalid_request")
    expect_length(trace$calls, 0L)
    expect_identical(m2_rb_tree(store$root), before)
  }
  target <- a$path
  a$path <- as.character(fs::path(store$root, ".", "a.rds"))
  m2_rb_expect_decision(m2_rb_plan(list(a), targets = target),
    "run", "missing_output")
})

test_that("relative registered builder resolves against alias root not cwd", {
  store <- m2_rb_store()
  store$alias <- "default"
  st_init(store$root, alias = store$alias, verbose = FALSE)
  cwd <- withr::local_tempdir()
  withr::local_dir(cwd)
  st_clear_builders()
  request <- m2_rb_request(store)
  trace <- m2_rb_trace()
  st_register_builder("a.rds", m2_rb_builder(trace))
  public <- st_builders()
  expect_named(public, c("path", "name"))
  expect_identical(public$path, stamp:::.st_norm_path("a.rds"))
  out <- st_rebuild(m2_rb_plan(list(request)))
  expect_identical(out$status, "built")
  expect_identical(trace$calls, "a.rds")
  expect_false(file.exists(fs::path(cwd, "a.rds")))
  expect_false(is.na(st_latest(request$path, alias = store$alias)))
})

test_that("invoked builders need exactly one exact x field to publish success", {
  for (value in list(
    list(x_backup = list(value = 1L)),
    list(x = list(value = 1L), x = list(value = 2L))
  )) {
    store <- m2_rb_store()
    request <- m2_rb_request(store)
    calls <- 0L
    builder <- function(path, parents) {
      calls <<- calls + 1L
      value
    }
    out <- st_rebuild(m2_rb_plan(list(request)), builder)
    expect_identical(calls, 1L)
    expect_identical(out$status, "failed")
    expect_true(is.na(out$version_id))
    expect_true(is.na(out$receipt_id))
    records <- m2_rb_records(store, request)
    expect_length(records, 1L)
    expect_identical(records[[1L]]$outcome, "failed_unknown")
    expect_null(records[[1L]]$output)
    expect_true(is.na(st_latest(request$path, alias = store$alias)))
  }
})

test_that("request-aware modes retain the same selected run skip and block rows", {
  store <- m2_rb_store()
  a <- m2_rb_request(store)
  saved <- m2_rb_seed(store, a)
  b <- m2_rb_request(store, "b.rds",
    list(m2_rb_parent(a, saved$output$version_id)))
  b$components$helper$hash <- NULL
  c <- m2_rb_request(store, "c.rds")
  before <- m2_rb_tree(store$root)
  propagate <- st_plan_rebuild(c(a$path, c$path), include_targets = TRUE,
    requests = list(a, b, c), mode = "propagate")
  strict <- st_plan_rebuild(c(a$path, c$path), include_targets = TRUE,
    requests = list(a, b, c), mode = "strict")
  expect_identical(strict, propagate)
  expect_identical(propagate$decision, c("skip", "blocked", "run"))
  expect_identical(basename(propagate$path), c("a.rds", "b.rds", "c.rds"))
  expect_identical(m2_rb_tree(store$root), before)
})
