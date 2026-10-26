# Typed proof metadata is deliberately separate from sanitized result hashing.
.st_proof_encode <- function(x) {
  # Version 2 materializes ALTREP without discarding types, names or shape.
  paste(sprintf("%02x", as.integer(serialize(x, NULL, version = 2L))),
    collapse = "")
}

.st_proof_decode <- function(text) {
  if (!is.character(text) || length(text) != 1L || is.na(text) ||
      !nzchar(text) || nchar(text) %% 2L ||
      !grepl("^[0-9a-f]+$", text)) {
    rlang::abort("Invalid typed proof encoding.")
  }
  starts <- seq.int(1L, nchar(text), by = 2L)
  unserialize(as.raw(strtoi(substring(text, starts, starts + 1L), 16L)))
}

.st_proof_string <- function(x) {
  is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
}

.st_proof_names <- function(x, empty = TRUE) {
  is.list(x) && !is.object(x) &&
    ((empty && !length(x)) ||
      (!is.null(names(x)) && !anyNA(names(x)) &&
        all(nzchar(names(x))) && !anyDuplicated(names(x))))
}

.st_request_abort <- function(reason, message) {
  rlang::abort(message, class = "stamp_blocked_request",
    decision = "blocked", reason = reason)
}

# Existing path helpers allow some cross-alias diagnostic queries. Modern
# proof identity is stricter: it must stay inside the selected alias root.
.st_execution_path <- function(path, alias = NULL) {
  norm <- tryCatch(.st_normalize_user_path(path, alias = alias,
    must_exist = FALSE, auto_switch = FALSE, verbose = FALSE),
    error = function(e) .st_request_abort("invalid_request", conditionMessage(e)))
  root <- .st_normalize_path(fs::path_norm(.st_root_dir(norm$alias)))
  absolute <- .st_normalize_path(fs::path_norm(norm$logical_path))
  rel <- as.character(fs::path_rel(absolute, start = root))
  if (rel == "." || rel == ".." || startsWith(rel, "../") ||
      fs::is_absolute_path(rel)) {
    .st_request_abort("invalid_request", "Artifact path escapes alias root.")
  }
  norm$logical_path <- absolute
  norm$rel_path <- rel
  norm$storage_dir <- .st_file_storage_dir(rel, alias = norm$alias)
  norm$storage_path <- .st_artifact_path(rel, alias = norm$alias)
  norm$artifact <- list(root = root, path = rel)
  return(norm)
}

.st_request_normalize <- function(request, alias = NULL,
                                  allow_deferred = FALSE) {
  required <- c("schema", "path", "root", "parents", "required_components",
    "components", "semantic_schema", "semantic", "format")
  if (!.st_proof_names(request, empty = FALSE) ||
      !all(required %in% names(request)) ||
      any(!names(request) %in% c(required, "audit", "review")) ||
      !identical(request$schema, 1L)) {
    .st_request_abort("invalid_request", "Invalid request fields or schema.")
  }
  norm <- .st_execution_path(request$path, alias)
  if (!is.logical(request$root) || length(request$root) != 1L ||
      is.na(request$root) || !is.list(request$parents) ||
      is.object(request$parents) || !is.null(names(request$parents)) ||
      !identical(request$root, !length(request$parents))) {
    .st_request_abort("invalid_request", "Invalid root or parent declaration.")
  }
  parents <- lapply(request$parents, function(parent) {
    if (!.st_proof_names(parent, empty = FALSE) ||
        !setequal(names(parent), c("path", "version_id")) ||
        (!.st_proof_string(parent$version_id) &&
          !(allow_deferred && is.null(parent$version_id)))) {
      .st_request_abort("invalid_request", "Invalid parent pin.")
    }
    pnorm <- .st_execution_path(parent$path, norm$alias)
    list(path = pnorm$logical_path, version_id = parent$version_id)
  })
  identities <- vapply(parents, `[[`, character(1L), "path")
  if (anyDuplicated(identities) || norm$logical_path %in% identities) {
    .st_request_abort("invalid_request", "Duplicate or self parent identity.")
  }
  parents <- parents[order(identities, method = "radix")]
  ids <- request$required_components
  components <- request$components
  if (!is.character(ids) || !length(ids) || anyNA(ids) ||
      any(!nzchar(ids)) || anyDuplicated(ids) ||
      !"calculation" %in% ids ||
      !.st_proof_names(components, empty = FALSE) ||
      !setequal(names(components), ids)) {
    .st_request_abort("missing_requested_proof", "Incomplete component proof.")
  }
  ids <- sort(unname(ids), method = "radix")
  components <- lapply(components[ids], function(component) {
    if (is.list(component) && !"hash" %in% names(component)) {
      .st_request_abort("missing_requested_proof", "Missing component digest.")
    }
    if (!.st_proof_names(component, empty = FALSE) ||
        !setequal(names(component), c("hash", "algorithm", "schema"))) {
      .st_request_abort("invalid_request", "Invalid component descriptor.")
    }
    if (!.st_proof_string(component$hash)) {
      .st_request_abort("missing_requested_proof", "Missing component digest.")
    }
    algorithm <- component$algorithm
    if (!.st_proof_string(algorithm) ||
        !algorithm %in% c("siphash13", "sha256") ||
        !.st_proof_string(component$schema) ||
        !grepl("^[0-9a-f]+$", component$hash) ||
        nchar(component$hash) != if (algorithm == "siphash13") 16L else 64L) {
      .st_request_abort("invalid_request", "Invalid component digest contract.")
    }
    component[c("hash", "algorithm", "schema")]
  })
  if (!.st_proof_string(request$format) ||
      !rlang::env_has(.st_formats_env, request$format)) {
    .st_request_abort("invalid_request", "Unknown physical request format.")
  }
  if (!.st_proof_names(request$semantic) ||
      any(!names(request$semantic) %in% names(request$semantic_schema))) {
    .st_request_abort("invalid_request", "Invalid request semantic fields.")
  }
  semantic <- tryCatch(
    .st_semantic_validate(request$semantic_schema, request$semantic),
    error = function(e) .st_request_abort("invalid_request", conditionMessage(e))
  )
  out <- list(schema = 1L, path = norm$logical_path, root = request$root,
    parents = parents, required_components = ids, components = components,
    semantic_schema = semantic$schema, semantic = semantic$values,
    format = request$format)
  if ("audit" %in% names(request)) {
    if (!.st_proof_names(request$audit) ||
        !all(vapply(request$audit, .st_proof_string, logical(1L)))) {
      .st_request_abort("invalid_request", "Invalid request audit fields.")
    }
    out$audit <- request$audit[sort(names(request$audit), method = "radix")]
  }
  if ("review" %in% names(request)) {
    if (!.st_proof_names(request$review, empty = FALSE) ||
        !identical(names(request$review), "outcome_id") ||
        !.st_proof_string(request$review$outcome_id)) {
      .st_request_abort("invalid_request", "Invalid failure review reference.")
    }
    out$review <- request$review
  }
  return(out)
}

.st_request_core <- function(request) {
  request[!names(request) %in% c("audit", "review")]
}

.st_request_id <- function(request) {
  secretbase::siphash13(serialize(.st_request_core(request), NULL, version = 2L))
}

.st_execution_failure <- function(failure, blocked = FALSE) {
  if (!.st_proof_names(failure, empty = FALSE) ||
      !setequal(names(failure), c("class", "message")) ||
      !.st_proof_string(failure$class) ||
      !failure$class %in% c("deterministic", "external", "unknown") ||
      !is.character(failure$message) || length(failure$message) != 1L ||
      is.na(failure$message) || (blocked && failure$class != "unknown")) {
    rlang::abort("Failure facts require an exact class and scalar message.")
  }
  failure[c("class", "message")]
}

# Selection is read-only. Its validation context never escapes this call.
.st_execution_decide <- function(request, alias = NULL, pending = character()) {
  out <- list(decision = "blocked", reason = "invalid_request",
    request = request, request_id = NA_character_, receipt_id = NA_character_,
    outcome_id = NA_character_, version_id = NA_character_,
    latest_version_before = NA_character_, msg = "")
  canonical <- FALSE
  result <- tryCatch({
    if (is.null(alias)) {
      alias <- .st_normalize_user_path(request$path,
        must_exist = FALSE, verbose = FALSE)$alias
    }
    request <- .st_request_normalize(request, alias, allow_deferred = TRUE)
    canonical <- TRUE
    out$request <- request
    norm <- .st_execution_path(request$path, alias)
    context <- .st_execution_context()
    deferred <- any(vapply(request$parents,
      function(parent) is.null(parent$version_id), logical(1L)))
    if (!deferred) out$request_id <- .st_request_id(request)
    out$latest_version_before <- st_latest(request$path, alias)
    for (parent in request$parents) {
      if (is.null(parent$version_id)) {
        if (!parent$path %in% pending) {
          .st_request_abort("missing_parent", "Missing unselected parent pin.")
        }
        next
      }
      pnorm <- .st_execution_path(parent$path, alias)
      if (!fs::file_exists(pnorm$storage_path) ||
          is.na(st_latest(parent$path, alias = alias))) {
        .st_request_abort("missing_parent", "Parent output is unavailable.")
      }
      pin <- .st_execution_validate_pin(parent$path, parent$version_id,
        alias, require_checksum = TRUE, .context = context)
      .st_execution_dependencies(pin, alias, context)
      facts <- .st_execution_records(parent$path, alias, .context = context)
      actual <- Filter(function(x) x$outcome != "blocked", facts)
      if (length(actual) &&
          startsWith(actual[[length(actual)]]$outcome, "failed_")) {
        .st_request_abort("failed_parent", "Parent has a governing failure.")
      }
      current <- .st_execution_validate_pin(parent$path,
        st_latest(parent$path, alias), alias, require_checksum = TRUE,
        .context = context)
      if (!.st_execution_current(current)) {
        .st_request_abort("invalid_state", "Current parent proof is invalid.")
      }
    }
    records <- .st_execution_records(request$path, alias, .context = context)
    if (!deferred) {
      for (record in records) {
        if (identical(record$request_id, out$request_id) &&
            !identical(.st_request_core(record$request),
              .st_request_core(request))) {
          rlang::abort("Request digest collision.")
        }
      }
    }
    actual <- Filter(function(x) x$outcome != "blocked", records)
    last <- if (length(actual)) actual[[length(actual)]] else NULL
    if (!is.null(last)) out$outcome_id <- last$id
    latest <- out$latest_version_before
    present <- fs::file_exists(norm$storage_path)
    original <- NULL
    if (!is.na(latest)) {
      pin <- .st_execution_validate_pin(request$path, latest, alias,
        .context = context)
      # Only the current artifact bytes may be absent for recovery.
      for (ext in names(pin$sidecars)) {
        file <- .st_sidecar_path(norm$rel_path, ext, alias)
        if (!fs::file_exists(file) ||
            !identical(st_hash_file(file), unname(pin$sidecars[[ext]]))) {
          .st_request_abort("invalid_state", "Current sidecar proof is invalid.")
        }
      }
      if (present && !.st_execution_current(pin)) {
        .st_request_abort("invalid_state", "Current output proof is invalid.")
      }
      if (.st_sidecar_is_modern(pin$metadata)) {
        if (isTRUE(pin$metadata$attrs$stamp$execution)) {
          original <- .st_request_normalize(
            .st_proof_decode(pin$metadata$execution$request), alias)
          .st_execution_check_success(list(request = original,
            output = pin$output), alias, context)
        } else {
          .st_execution_dependencies(pin, alias, context)
        }
      }
    } else if (present) {
      .st_request_abort("invalid_state", "Output has no retained catalog proof.")
    }
    # Unlike component digests, unlike algorithms/schemas cannot be compared.
    saved <- if (!is.null(original)) original else
      if (!is.null(last)) last$request else NULL
    if (!is.null(saved)) {
      for (id in intersect(names(saved$components), names(request$components))) {
        before <- saved$components[[id]]
        after <- request$components[[id]]
        if (!identical(before$algorithm, after$algorithm) ||
            !identical(before$schema, after$schema)) {
          .st_request_abort("incomparable_proof", "Component contracts differ.")
        }
      }
    }
    if (!is.null(last) && last$outcome == "failed_unknown") {
      .st_request_abort("unknown_failure", "Unclassified execution failure.")
    }
    if (deferred) {
      out$decision <- "run"
      out$reason <- "pending_parent"
      return(out)
    }
    if (!is.null(last) && last$outcome == "failed_deterministic") {
      # Review is not a force flag. Only actual input/component edits qualify.
      fields <- c("root", "parents", "required_components", "components")
      changed <- !identical(request[fields], last$request[fields])
      reviewed <- identical(request$review$outcome_id, last$id)
      if (!changed) {
        .st_request_abort(if (reviewed) "review_change_required" else
          "deterministic_failure", "Deterministic failure requires a change.")
      }
      if (!reviewed) {
        .st_request_abort("review_required", "Governing failure review required.")
      }
    }
    out$decision <- "run"
    if (!is.null(last) && last$outcome == "failed_external") {
      out$reason <- "external_retry"
    } else if (!present) {
      out$reason <- "missing_output"
    } else if (!is.null(last) && last$outcome == "failed_deterministic") {
      out$reason <- "request_changed"
    } else if (is.null(last) || !startsWith(last$outcome, "success_")) {
      out$reason <- "missing_saved_proof"
    } else if (identical(last$request_id, out$request_id)) {
      if (identical(last$output$version_id, latest)) {
        out$decision <- "skip"
        out$reason <- "current"
        out$receipt_id <- last$id
        out$version_id <- latest
      } else {
        out$reason <- "missing_saved_proof"
      }
    } else {
      out$reason <- "request_changed"
    }
    out
  }, error = identity)
  if (inherits(result, "error")) {
    out$decision <- "blocked"
    out$reason <- if (inherits(result, "stamp_blocked_request")) {
      result$reason
    } else if (!canonical) "invalid_request" else "invalid_state"
    out$msg <- conditionMessage(result)
    return(out)
  }
  return(result)
}

# Validate retained bytes and pinned metadata without invoking an artifact reader.
# This also accepts legacy parent snapshots; success publication additionally
# requires modern request proof on its own output.
.st_execution_validate_pin <- function(path, version_id, alias = NULL,
                                       require_checksum = FALSE,
                                       .context = NULL) {
  norm <- .st_execution_path(path, alias)
  if (!.st_proof_string(version_id)) rlang::abort("Missing snapshot pin.")
  key <- paste(norm$logical_path, version_id, sep = "\n")
  if (require_checksum && !is.null(.context) &&
      exists(key, envir = .context$pins, inherits = FALSE)) {
    return(.context$pins[[key]])
  }
  catalog <- .st_catalog_read(alias = norm$alias)
  aid <- .st_artifact_id(norm$logical_path)
  requested_id <- version_id
  art <- catalog$artifacts[catalog$artifacts$artifact_id == aid]
  row <- catalog$versions[catalog$versions$artifact_id == aid &
    catalog$versions$version_id == requested_id]
  if (nrow(art) != 1L || nrow(row) != 1L ||
      !identical(as.character(art$path[[1L]]), norm$logical_path)) {
    rlang::abort("Snapshot catalog binding is missing or contradictory.")
  }
  vdir <- .st_version_dir(norm$rel_path, version_id, norm$alias)
  bytes <- fs::path(vdir, "artifact")
  if (!fs::file_exists(bytes)) rlang::abort("Retained snapshot is missing.")
  mode <- as.character(row$sidecar_format[[1L]])
  extensions <- switch(mode, json = "json", qs2 = "qs2",
    both = c("json", "qs2"), character())
  sidecars <- fs::path(vdir, paste0("sidecar.", extensions))
  if (!length(extensions) || !all(fs::file_exists(sidecars))) {
    rlang::abort("Required pinned sidecar is missing.")
  }
  meta <- st_read_sidecar(norm$rel_path, alias = norm$alias,
    version_id = version_id)
  if (!is.list(meta) || !identical(meta$path, norm$logical_path) ||
      !.st_proof_string(meta$format) ||
      !rlang::env_has(.st_formats_env, meta$format) ||
      (identical(as.character(art$latest_version_id[[1L]]), version_id) &&
        !identical(meta$format, as.character(art$format[[1L]]))) ||
      !.st_proof_string(meta$content_hash) ||
      !identical(meta$content_hash, as.character(row$content_hash[[1L]])) ||
      !identical(as.numeric(meta$size_bytes), as.numeric(file.info(bytes)$size)) ||
      !identical(as.numeric(row$size_bytes[[1L]]), as.numeric(meta$size_bytes))) {
    rlang::abort("Pinned metadata and catalog disagree.")
  }
  if (require_checksum && !.st_proof_string(meta$file_hash)) {
    rlang::abort("Certified snapshot requires a persisted byte checksum.")
  }
  checksum <- st_hash_file(bytes)
  if (.st_proof_string(meta$file_hash) &&
      !identical(meta$file_hash, checksum)) {
    rlang::abort("Snapshot bytes disagree with the saved checksum.")
  }
  parents <- .st_parents_normalize(meta$parents)
  pfile <- fs::path(vdir, "parents.json")
  saved_parents <- if (fs::file_exists(pfile)) {
    .st_parents_normalize(jsonlite::read_json(pfile, simplifyVector = FALSE))
  } else list()
  if ((length(parents) && !fs::file_exists(pfile)) ||
      !identical(.st_proof_encode(saved_parents), .st_proof_encode(parents))) {
    rlang::abort("Original snapshot parent proof is unavailable or changed.")
  }
  typed_semantic <- .st_sidecar_is_modern(meta) &&
    isTRUE(meta$attrs$stamp$semantic)
  semantic <- .st_semantic_validate(
    if (!typed_semantic) NULL else
      .st_proof_decode(meta$semantic$definition),
    if (!typed_semantic) list() else
      .st_proof_decode(meta$semantic$values)
  )
  sidecar_hashes <- vapply(sidecars, st_hash_file, character(1L))
  names(sidecar_hashes) <- extensions
  output <- list(version_id = version_id, format = meta$format,
    content_hash = meta$content_hash, content_algorithm = "siphash13",
    byte_checksum = checksum, byte_algorithm = "siphash13",
    semantic_schema = semantic$schema, semantic = semantic$values,
    metadata_checksum = secretbase::siphash13(serialize(
      sidecar_hashes,
      NULL, version = 2L)), metadata_algorithm = "siphash13")
  pin <- list(norm = norm, metadata = meta, output = output,
    sidecars = sidecar_hashes)
  if (require_checksum && !is.null(.context)) .context$pins[[key]] <- pin
  return(pin)
}

.st_execution_current <- function(pin) {
  norm <- pin$norm
  if (!fs::file_exists(norm$storage_path) ||
      !identical(st_hash_file(norm$storage_path), pin$output$byte_checksum)) {
    return(FALSE)
  }
  for (ext in names(pin$sidecars)) {
    file <- .st_sidecar_path(norm$rel_path, ext, alias = norm$alias)
    if (!fs::file_exists(file) ||
        !identical(st_hash_file(file), unname(pin$sidecars[[ext]]))) {
      return(FALSE)
    }
  }
  return(TRUE)
}

# A retained output also depends on its original immutable snapshot parents,
# which can differ from the effective parents in a newer execution receipt.
.st_execution_context <- function() {
  list(active = new.env(parent = emptyenv()),
    completed = new.env(parent = emptyenv()),
    pins = new.env(parent = emptyenv()))
}

.st_execution_dependencies <- function(pin, alias = NULL, .context = NULL) {
  if (is.null(.context)) .context <- .st_execution_context()
  key <- paste(pin$norm$logical_path, pin$output$version_id, sep = "\n")
  if (exists(key, envir = .context$active, inherits = FALSE)) {
    rlang::abort("Cyclic retained snapshot provenance.")
  }
  if (exists(key, envir = .context$completed, inherits = FALSE)) {
    return(.context$completed[[key]])
  }
  if (!.st_proof_string(pin$metadata$file_hash) ||
      !identical(pin$metadata$file_hash, pin$output$byte_checksum)) {
    rlang::abort("Certified snapshot requires a persisted byte checksum.")
  }
  .context$active[[key]] <- TRUE
  .context$pins[[key]] <- pin
  on.exit(rm(list = key, envir = .context$active), add = TRUE)
  references <- key
  for (parent in .st_parents_normalize(pin$metadata$parents)) {
    norm <- .st_execution_path(parent$path, alias)
    parent_key <- paste(norm$logical_path, parent$version_id, sep = "\n")
    if (exists(parent_key, envir = .context$active, inherits = FALSE)) {
      rlang::abort("Cyclic retained snapshot provenance.")
    }
    if (exists(parent_key, envir = .context$completed, inherits = FALSE)) {
      dependencies <- .context$completed[[parent_key]]
    } else {
      dependency <- .st_execution_validate_pin(parent$path, parent$version_id,
        alias, require_checksum = TRUE, .context = .context)
      dependencies <- .st_execution_dependencies(dependency, alias, .context)
    }
    references <- c(references, dependencies)
  }
  references <- unique(references)
  .context$completed[[key]] <- references
  return(references)
}

.st_execution_record_wire <- function(record, decode = FALSE) {
  if (decode) {
    for (field in c("schema", "sequence")) {
      value <- record[[field]]
      if (!is.numeric(value) || is.object(value) || length(value) != 1L ||
          is.na(value) || !is.finite(value) || value < 1 ||
          value > .Machine$integer.max || value != floor(value)) {
        rlang::abort("Receipt schema and sequence require exact integer numbers.")
      }
    }
    record$schema <- as.integer(record$schema)
    record$sequence <- as.integer(record$sequence)
    record$request <- .st_proof_decode(record$request)
    if (!is.null(record$output)) {
      record$output["semantic_schema"] <-
        list(.st_proof_decode(record$output$semantic_schema))
      record$output$semantic <- .st_proof_decode(record$output$semantic)
    }
  } else {
    record$request <- .st_proof_encode(record$request)
    if (!is.null(record$output)) {
      record$output$semantic_schema <-
        .st_proof_encode(record$output$semantic_schema)
      record$output$semantic <- .st_proof_encode(record$output$semantic)
    }
  }
  return(record)
}

.st_execution_check_success <- function(record, alias = NULL, .context = NULL) {
  if (is.null(.context)) .context <- .st_execution_context()
  pin <- .st_execution_validate_pin(record$request$path,
    record$output$version_id, alias, require_checksum = TRUE, .context = .context)
  if (!identical(pin$output, record$output)) {
    rlang::abort("Committed output proof disagrees with retained storage.")
  }
  .st_execution_dependencies(pin, alias, .context)
  stored <- pin$metadata$execution
  if (!.st_sidecar_is_modern(pin$metadata) ||
      !isTRUE(pin$metadata$attrs$stamp$execution) ||
      !is.list(stored) || !identical(stored$schema, 1L)) {
    rlang::abort("Committed success has no saved modern request proof.")
  }
  original <- .st_request_normalize(.st_proof_decode(stored$request), alias)
  original <- .st_request_core(original)
  effective <- .st_request_core(record$request)
  original$parents <- NULL
  effective$parents <- NULL
  original$root <- NULL
  effective$root <- NULL
  if (!identical(original, effective) ||
      !identical(record$request$format, pin$output$format) ||
      !identical(record$request$semantic_schema, pin$output$semantic_schema) ||
      !identical(record$request$semantic, pin$output$semantic)) {
    rlang::abort("Committed request and output proof contradict each other.")
  }
  for (parent in record$request$parents) {
    dependency <- .st_execution_validate_pin(parent$path, parent$version_id,
      alias, require_checksum = TRUE, .context = .context)
    .st_execution_dependencies(dependency, alias, .context)
  }
  return(pin)
}

# A missing index is recoverable from the complete serial chain. An existing
# index that disagrees is not repaired, and uncommitted directories are ignored.
.st_execution_records <- function(path, alias = NULL, validate = TRUE,
                                  .context = NULL) {
  if (is.null(.context)) .context <- .st_execution_context()
  norm <- .st_execution_path(path, alias)
  base <- fs::path(norm$storage_dir, "executions")
  markers <- if (fs::dir_exists(base)) {
    fs::dir_ls(base, recurse = TRUE, type = "file", regexp = "/COMMITTED$")
  } else character()
  records <- lapply(markers, function(marker) {
    file <- fs::path(fs::path_dir(marker), "receipt.json")
    if (!fs::file_exists(file) ||
        !identical(readLines(marker, warn = FALSE), st_hash_file(file))) {
      rlang::abort("Committed receipt checksum is invalid.")
    }
    record <- .st_execution_record_wire(
      jsonlite::read_json(file, simplifyVector = FALSE), decode = TRUE)
    fields <- c("schema", "id", "sequence", "previous_id", "artifact",
      "request_id", "request_kind", "request", "outcome", "output",
      "failure", "created_at", "audit")
    if (!.st_proof_names(record, empty = FALSE) ||
        !setequal(names(record), fields) || !identical(record$schema, 1L) ||
        !.st_proof_string(record$id) ||
        !identical(record$id, as.character(fs::path_file(fs::path_dir(marker)))) ||
        !identical(record$artifact, norm$artifact) ||
        length(record$sequence) != 1L || is.na(record$sequence) ||
        record$sequence < 1L || !.st_proof_string(record$created_at) ||
        !record$request_kind %in% c("effective", "preview") ||
        !record$outcome %in% c("success_new", "success_unchanged",
          "failed_deterministic", "failed_external", "failed_unknown", "blocked")) {
      rlang::abort("Invalid committed receipt envelope.")
    }
    canonical <- .st_request_normalize(record$request, norm$alias,
      allow_deferred = record$request_kind == "preview")
    digest <- .st_request_id(canonical)
    if (record$request_kind == "preview") digest <- paste0("preview-", digest)
    base_id <- paste0(sprintf("%010d", record$sequence), "-", digest)
    suffix <- substring(record$id, nchar(base_id) + 2L)
    valid_id <- identical(record$id, base_id) ||
      (startsWith(record$id, paste0(base_id, "-")) &&
        grepl("^[1-9][0-9]*$", suffix))
    if (!identical(canonical, record$request) ||
        !identical(canonical$path, norm$logical_path) ||
        !identical(record$audit, canonical$audit %||% NULL) ||
        !identical(record$request_id, digest) ||
        !valid_id ||
        (record$request_kind == "preview" && record$outcome != "blocked")) {
      rlang::abort("Committed request binding is invalid.")
    }
    success <- startsWith(record$outcome, "success_")
    if (success) {
      if (is.null(record$output) || !is.null(record$failure)) {
        rlang::abort("Success is missing output proof.")
      }
      if (validate) .st_execution_check_success(record, norm$alias, .context)
    } else {
      failure <- .st_execution_failure(record$failure,
        blocked = record$outcome == "blocked")
      if (!is.null(record$output) ||
          (record$outcome != "blocked" &&
            record$outcome != paste0("failed_", failure$class))) {
        rlang::abort("Failure outcome contradicts its facts.")
      }
    }
    return(record)
  })
  if (length(records)) {
    records <- records[order(vapply(records, `[[`, integer(1L), "sequence"))]
    previous <- NULL
    seen <- list()
    for (i in seq_along(records)) {
      if (!identical(records[[i]]$sequence, as.integer(i)) ||
          !identical(records[[i]]$previous_id, previous)) {
        rlang::abort("Committed receipt chain is incomplete or contradictory.")
      }
      digest <- records[[i]]$request_id
      core <- .st_request_core(records[[i]]$request)
      if (!is.null(seen[[digest]]) && !identical(seen[[digest]], core)) {
        rlang::abort("Committed request digest collision.")
      }
      seen[[digest]] <- core
      previous <- records[[i]]$id
    }
  }
  index <- fs::path(norm$storage_dir, "current-execution.json")
  if (fs::file_exists(index)) {
    pointer <- jsonlite::read_json(index, simplifyVector = TRUE)
    if (!length(records) || !identical(pointer$schema, 1L) ||
        !identical(pointer$id, records[[length(records)]]$id)) {
      rlang::abort("Current execution index contradicts committed receipts.")
    }
  }
  return(records)
}

.st_execution_append <- function(path, outcome, request, output = NULL,
                                 failure = NULL, alias = NULL,
                                 allow_deferred = FALSE) {
  norm <- .st_execution_path(path, alias)
  request <- .st_request_normalize(request, norm$alias, allow_deferred)
  if (!.st_proof_string(outcome) || !outcome %in% c("success_new",
      "success_unchanged", "failed_deterministic", "failed_external",
      "failed_unknown", "blocked")) {
    rlang::abort("Unknown execution outcome.")
  }
  if (startsWith(outcome, "success_")) {
    if (!is.list(output) || !is.null(failure)) {
      rlang::abort("Success requires validated output proof and no failure.")
    }
  } else {
    failure <- .st_execution_failure(failure, blocked = outcome == "blocked")
    if (!is.null(output) || (outcome != "blocked" &&
        outcome != paste0("failed_", failure$class))) {
      rlang::abort("Execution outcome contradicts failure facts.")
    }
  }
  if (!identical(request$path, norm$logical_path)) {
    rlang::abort("Outcome artifact and request path disagree.")
  }
  records <- .st_execution_records(path, norm$alias)
  sequence <- as.integer(length(records) + 1L)
  preview <- any(vapply(request$parents,
    function(p) is.null(p$version_id), logical(1L)))
  if (preview && outcome != "blocked") {
    rlang::abort("Only blocked observations may contain deferred parents.")
  }
  digest <- .st_request_id(request)
  if (preview) digest <- paste0("preview-", digest)
  id <- paste0(sprintf("%010d", sequence), "-", digest)
  dir <- fs::path(norm$storage_dir, "executions", id)
  base_id <- id
  suffix <- 0L
  while (fs::dir_exists(dir) || fs::file_exists(dir)) {
    suffix <- suffix + 1L
    id <- paste0(base_id, "-", suffix)
    dir <- fs::path(norm$storage_dir, "executions", id)
  }
  # Equal digest with unequal complete proof is an integrity failure.
  for (old in records) {
    if (identical(old$request_id, digest) &&
        !identical(.st_request_core(old$request), .st_request_core(request))) {
      rlang::abort("Request digest collision.")
    }
  }
  record <- list(schema = 1L, id = id, sequence = sequence,
    previous_id = if (length(records)) records[[length(records)]]$id else NULL,
    artifact = norm$artifact, request_id = digest,
    request_kind = if (preview) "preview" else "effective",
    request = request, outcome = outcome, output = output, failure = failure,
    created_at = .st_now_utc(), audit = request$audit %||% NULL)
  fs::dir_create(dir)
  receipt <- fs::path(dir, "receipt.json")
  jsonlite::write_json(.st_execution_record_wire(record), receipt,
    auto_unbox = TRUE, null = "null", digits = NA, pretty = TRUE)
  # The marker is last. Unknown pending files are intentionally not removed.
  writeLines(st_hash_file(receipt), fs::path(dir, "COMMITTED"), useBytes = TRUE)
  index <- fs::path(norm$storage_dir, "current-execution.json")
  temporary <- fs::file_temp(tmp_dir = norm$storage_dir)
  jsonlite::write_json(list(schema = 1L, id = id), temporary, auto_unbox = TRUE)
  if (fs::file_exists(index)) fs::file_delete(index)
  fs::file_move(temporary, index)
  return(record)
}

#' Inspect durable execution proof without loading artifact data
#'
#' Validates committed receipt bytes, retained snapshots and pinned metadata.
#' Byte checksum streaming does not invoke the artifact format reader.
#' In a valid store, an explicit unknown receipt ID errors; an explicit ID never
#' falls back to the latest record. This function inspects proof, not a new
#' requested calculation. Use [st_plan_rebuild()] for requested currentness.
#' @param path Artifact logical path.
#' @param receipt_id Exact receipt or outcome ID; NULL selects the latest record.
#' @param alias Optional stamp alias.
#' @return A list with `state`, `reason`, `receipt`, `outcome`, `version_id`,
#'   `receipt_id` and `outcome_id`. States are `absent` (no committed record),
#'   `invalid` (contradictory proof/current storage), `recorded` (an outcome or
#'   historical success without a currently usable pin), and `success`.
#'   `receipt` contains a decoded success envelope; `outcome` contains the
#'   selected decoded envelope, including failures/blocks. Unavailable records
#'   are NULL; unavailable IDs and unusable version pins are `NA_character_`.
#'   An older success remains inspectable by ID, but its version is returned as
#'   usable only when the current materialization also matches its retained pin.
#' @seealso [st_read_sidecar()], [st_record_outcome()], [st_rebuild()]
#' @examples
#' local({
#'   root <- tempfile("stamp-info-")
#'   stores <- list(stamp:::.stamp_aliases, stamp:::.stamp_opts)
#'   old <- lapply(stores, as.list, all.names = TRUE)
#'   on.exit({
#'     for (i in seq_along(stores)) {
#'       rm(list = ls(stores[[i]], all.names = TRUE), envir = stores[[i]])
#'       list2env(old[[i]], envir = stores[[i]])
#'     }
#'     unlink(root, recursive = TRUE)
#'   }, add = TRUE)
#'   st_opts_reset()
#'   alias <- basename(root)
#'   st_init(root, alias = alias, verbose = FALSE)
#'   st_execution_info("result.rds", alias = alias)$state # "absent"
#'   saved <- st_save(1:3, "result.rds", format = "rds",
#'                    alias = alias, verbose = FALSE)
#'   st_read_sidecar("result.rds", alias, saved$version_id)$format
#'   # Saving data alone does not certify that a requested builder executed.
#'   st_execution_info("result.rds", alias = alias)$state # still "absent"
#' })
#' @export
st_execution_info <- function(path, receipt_id = NULL, alias = NULL) {
  if (!is.null(receipt_id) && !.st_proof_string(receipt_id)) {
    rlang::abort("receipt_id must be a nonempty character scalar.")
  }
  empty <- list(state = "absent", reason = "missing_saved_proof",
    receipt = NULL, outcome = NULL, version_id = NA_character_,
    receipt_id = NA_character_, outcome_id = NA_character_)
  result <- tryCatch(.st_execution_records(path, alias), error = identity)
  if (inherits(result, "error")) {
    empty$state <- "invalid"
    empty$reason <- "invalid_state"
    return(empty)
  }
  if (!is.null(receipt_id)) {
    matches <- which(vapply(result, function(x) identical(x$id, receipt_id),
      logical(1L)))
    if (length(matches) != 1L) rlang::abort("Unknown exact execution receipt ID.")
    record <- result[[matches]]
  } else {
    if (!length(result)) return(empty)
    record <- result[[length(result)]]
  }
  empty$state <- "recorded"
  empty$outcome <- record
  empty$outcome_id <- record$id
  if (!startsWith(record$outcome, "success_")) {
    empty$reason <- record$outcome
    return(empty)
  }
  empty$receipt <- record
  empty$receipt_id <- record$id
  norm <- .st_execution_path(path, alias)
  if (!fs::file_exists(norm$storage_path)) {
    empty$reason <- "missing_output"
    return(empty)
  }
  pin <- .st_execution_validate_pin(path, record$output$version_id, norm$alias)
  if (!.st_execution_current(pin)) {
    # Historical proof is readable but is not a currently usable output pin.
    empty$state <- if (is.null(receipt_id)) "invalid" else "recorded"
    empty$reason <- if (is.null(receipt_id)) "invalid_state" else "missing_output"
    return(empty)
  }
  empty$state <- "success"
  empty$reason <- "current"
  empty$version_id <- record$output$version_id
  return(empty)
}

#' Record externally classified failed or blocked execution facts
#'
#' This interface cannot publish success. Failure messages are preserved and
#' never used to guess classification. A blocked observation does not supersede
#' the preceding actual execution for failure/review precedence.
#' @param path Artifact logical path.
#' @param outcome Either "failed" or "blocked".
#' @param request Complete effective request as documented in
#'   [st_plan_rebuild()], with exact parent pins, never deferred NULL pins.
#'   Failed/blocked facts may describe unavailable inputs; they do not certify
#'   successful output availability.
#' @param failure Required list with exactly `class` and `message`. Class is
#'   `"deterministic"`, `"external"` or `"unknown"`; blocked observations require
#'   `"unknown"`. Message is a nonmissing scalar character string.
#' @param alias Optional stamp alias.
#' @return Invisibly, the decoded immutable outcome envelope, including its
#'   `id`, canonical `request`, classified `outcome` and `failure`. Its `output`
#'   is NULL; recording an outcome cannot manufacture a usable version pin.
#' @seealso [st_execution_info()], [st_rebuild()]
#' @examples
#' local({
#'   root <- tempfile("stamp-outcome-")
#'   aliases <- stamp:::.stamp_aliases
#'   old <- as.list(aliases, all.names = TRUE)
#'   on.exit({
#'     rm(list = ls(aliases, all.names = TRUE), envir = aliases)
#'     list2env(old, envir = aliases)
#'     unlink(root, recursive = TRUE)
#'   }, add = TRUE)
#'   alias <- basename(root)
#'   st_init(root, alias = alias, verbose = FALSE)
#'   calculate <- function() 1L + 1L
#'   # Caller contract: hash the actual formals/body, not a source-file label.
#'   component <- list(
#'     hash = st_hash_obj(list(formals = formals(calculate),
#'                             body = body(calculate))),
#'     algorithm = "siphash13", schema = "r-formals-body-v1"
#'   )
#'   request <- list(
#'     schema = 1L, path = "result.rds", root = TRUE, parents = list(),
#'     required_components = "calculation",
#'     components = list(calculation = component),
#'     semantic_schema = NULL, semantic = list(), format = "rds"
#'   )
#'   fact <- st_record_outcome("result.rds", "failed", request,
#'     failure = list(class = "external", message = "Example input unavailable"),
#'     alias = alias)
#'   st_execution_info("result.rds", fact$id, alias)$outcome$outcome
#' })
#' @export
st_record_outcome <- function(path, outcome, request, failure = NULL,
                              alias = NULL) {
  if (!.st_proof_string(outcome) || !outcome %in% c("failed", "blocked")) {
    rlang::abort("Only failed or blocked facts may be recorded publicly.")
  }
  failure <- .st_execution_failure(failure, blocked = outcome == "blocked")
  status <- if (outcome == "failed") paste0("failed_", failure$class) else outcome
  invisible(.st_execution_append(path, status, request,
    failure = failure, alias = alias))
}

# Only rebuild calls this publisher after actual builder execution. A raw
# no-op save alone never calls it and is never execution evidence.
.st_execution_success <- function(path, request, saved, alias = NULL) {
  norm <- .st_execution_path(path, alias)
  request <- .st_request_normalize(request, norm$alias)
  if (!identical(request$path, norm$logical_path) || !is.list(saved) ||
      !.st_proof_string(saved$version_id) ||
      !identical(as.character(saved$path), norm$logical_path)) {
    rlang::abort("Saved output does not bind this artifact request.")
  }
  context <- .st_execution_context()
  pin <- .st_execution_validate_pin(path, saved$version_id, norm$alias,
    require_checksum = TRUE, .context = context)
  stored <- pin$metadata$execution
  if (!.st_sidecar_is_modern(pin$metadata) ||
      !isTRUE(pin$metadata$attrs$stamp$execution) ||
      !is.list(stored) || !identical(stored$schema, 1L)) {
    rlang::abort("Saved output has no modern execution request proof.")
  }
  original <- .st_request_normalize(.st_proof_decode(stored$request), norm$alias)
  compare <- function(x) {
    x <- .st_request_core(x)
    x$parents <- NULL
    x$root <- NULL
    x
  }
  if (!identical(compare(original), compare(request)) ||
      !identical(pin$output$format, request$format) ||
      !identical(pin$output$semantic_schema, request$semantic_schema) ||
      !identical(pin$output$semantic, request$semantic) ||
      !.st_execution_current(pin)) {
    rlang::abort("Saved output proof does not satisfy the effective request.")
  }
  for (parent in request$parents) {
    dependency <- .st_execution_validate_pin(parent$path, parent$version_id,
      norm$alias, require_checksum = TRUE, .context = context)
    .st_execution_dependencies(dependency, norm$alias, context)
  }
  .st_execution_dependencies(pin, norm$alias, context)
  records <- .st_execution_records(path, norm$alias, .context = context)
  actual <- Filter(function(x) x$outcome != "blocked", records)
  if (length(actual)) {
    last <- actual[[length(actual)]]
    if (startsWith(last$outcome, "success_") &&
        identical(last$request_id, .st_request_id(request))) {
      if (!identical(.st_request_core(last$request), .st_request_core(request))) {
        rlang::abort("Request digest collision.")
      }
      if (identical(last$output, pin$output)) return(invisible(last))
    }
  }
  outcome <- if (isTRUE(saved$skipped)) "success_unchanged" else "success_new"
  invisible(.st_execution_append(path, outcome, request,
    output = pin$output, alias = norm$alias))
}

# Retention validates every committed chain before applying any path filter.
.st_execution_protected <- function(alias = NULL) {
  context <- .st_execution_context()
  root <- .st_root_dir(alias)
  files <- fs::dir_ls(root, recurse = TRUE, type = "file", all = TRUE,
    regexp = "/(COMMITTED|current-execution\\.json)$")
  bases <- unique(vapply(files, function(file) {
    if (fs::path_file(file) == "COMMITTED") {
      fs::path_dir(fs::path_dir(fs::path_dir(file)))
    } else fs::path_dir(file)
  }, character(1L)))
  references <- character()
  for (base in bases) {
    rel <- as.character(fs::path_rel(base, root))
    # Storage directories have the same alias-relative logical artifact path.
    path <- as.character(fs::path(root, rel))
    records <- .st_execution_records(path, alias, .context = context)
    norm <- .st_execution_path(path, alias)
    if (fs::file_exists(norm$storage_path)) {
      latest <- .st_execution_validate_pin(path, st_latest(path, alias), alias)
      if (!.st_execution_current(latest)) {
        rlang::abort("Current artifact bytes contradict retained storage.")
      }
    }
    for (record in records) {
      pins <- record$request$parents
      if (!is.null(record$output)) {
        pins <- c(pins, list(list(path = record$request$path,
          version_id = record$output$version_id)))
      }
      for (pin in pins) {
        if (!is.null(pin$version_id)) {
          references <- c(references, paste(pin$path, pin$version_id, sep = "\n"))
          if (startsWith(record$outcome, "success_")) {
            dependency <- .st_execution_validate_pin(pin$path, pin$version_id,
              alias, require_checksum = TRUE, .context = context)
            references <- c(references,
              .st_execution_dependencies(dependency, alias, context))
          }
        }
      }
    }
  }
  unique(references)
}
