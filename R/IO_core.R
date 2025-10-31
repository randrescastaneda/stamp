#' stamp: Milestone 2 — I/O + hashing (qs2-first), cli+fs only
#' Depends: cli, fs, jsonlite, secretbase (and optionally qs2, qs, fst, data.table)
#' Exports: st_init, st_path, st_register_format, st_formats, st_save, st_load

# ---- st_init -----------------------------------------------------------------

#' Initialize stamp project structure
#' @param root project root (default ".")
#' @param state_dir directory name for internal state (default ".stamp")
#' @return (invisibly) the absolute state dir
#' @export
st_init <- function(root = ".", state_dir = ".stamp") {
  root_abs <- fs::path_abs(root)
  st_state_set(root_dir = root_abs, state_dir = state_dir)

  sd <- fs::path(root_abs, state_dir)
  .st_dir_create(sd)
  .st_dir_create(fs::path(sd, "temp"))
  .st_dir_create(fs::path(sd, "logs"))

  cli::cli_inform(c(
    "v" = "stamp initialized",
    " " = paste0("root: ", root_abs),
    " " = paste0("state: ", fs::path_abs(sd))
  ))
  invisible(fs::path_abs(sd))
}


# ---- st_path (S3-ish lightweight) -------------------------------------------

#' Declare a path (with optional format & partition hint)
#' @param path file or directory path
#' @param format optional explicit format ("qs2","rds","csv","fst","json")
#' @param partition_key optional partition key (not used in M2)
#' @return list with class 'st_path'
#' @export
st_path <- function(path, format = NULL, partition_key = NULL) {
  stopifnot(is.character(path), length(path) == 1L)

  structure(
    list(
      path = path,
      format = format %||% .st_guess_format(path),
      partition_key = partition_key
    ),
    class = "st_path"
  )
}

#' @export
print.st_path <- function(x, ...) {
  cli::cli_inform("<{.field st_path}> {.field {x$path}} [format={.field {x$format}}]")
  invisible(x)
}

# ---- format inference --------------------------------------------------------

.st_guess_format <- function(path) {
  ext <- tolower(fs::path_ext(path))
  if (!nzchar(ext)) return(NULL)
  if (rlang::env_has(.st_formats_env, ext)) return(ext)
  if (rlang::env_has(.st_extmap_env, ext)) return(rlang::env_get(.st_extmap_env, ext))
  NULL
}

# ---- Load and Save -----------------------------------------------------------

#' Save an R object to disk with metadata & versioning (atomic move)
#' @param x object to save
#' @param file destination path (character or st_path)
#' @param format optional format override ("qs2" | "rds" | "csv" | "fst" | "json")
#' @param metadata named list of extra metadata (merged into sidecar)
#' @param code Optional function/expression/character whose hash is stored as `code_hash`.
#' @param parents Optional list of parent descriptors:
#'   list(list(path = "<path>", version_id = "<id>"), ...).
#'   You can obtain version ids with `st_latest(parent_path)`.
#' @param code_label Optional short label/description of the producing code (for humans).
#' @param ... forwarded to format writer
#' @return invisibly, a list with path, metadata, and version_id
#' @export
st_save <- function(x, file, format = NULL, metadata = list(), code = NULL,
                    parents = NULL, code_label = NULL, ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)

  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}}. See {.fn st_formats} or {.fn st_register_format}.")
  }

  # Should we write at all?
  dec <- st_should_save(sp$path, x = x, code = code)
  if (!dec$save) {
    cli::cli_inform(c("v" = "Skip save (reason: {.field {dec$reason}}) for {.field {sp$path}}"))
    return(invisible(list(path = sp$path, skipped = TRUE, reason = dec$reason)))
  }

  # Hashes
  versioning      <- st_opts("versioning", .get = TRUE)
  do_code_hash    <- isTRUE(st_opts("code_hash", .get = TRUE)) && !is.null(code)
  do_file_hash    <- isTRUE(st_opts("store_file_hash", .get = TRUE))

  content_hash <- st_hash_obj(x)
  code_hash    <- if (do_code_hash) st_hash_code(code) else NA_character_

  # Ensure parent dir
  .st_dir_create(fs::path_dir(sp$path))

  # Write temp -> move
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(sp$path), pattern = fs::path_file(sp$path))
  h$write(x, tmp, ...)
  if (fs::file_exists(sp$path)) fs::file_delete(sp$path)
  fs::file_move(tmp, sp$path)

  # Optional file hash (post-write)
  file_hash <- if (do_file_hash) st_hash_file(sp$path) else NA_character_

  # Sidecar metadata (augment with provenance hints)
  meta <- c(
    list(
      path         = as.character(sp$path),
      format       = fmt,
      created_at   = .st_now_utc(),
      size_bytes   = unname(fs::file_info(sp$path)$size),
      content_hash = content_hash,
      code_hash    = code_hash,
      file_hash    = file_hash,
      code_label   = code_label %||% NA_character_,
      parents      = parents %||% list(),   # for quick inspection
      attrs        = list()                 # reserved for internal use
    ),
    metadata
  )
  .st_write_sidecar(sp$path, meta)

  # Record catalog version + snapshot (includes copying sidecars)
  vid <- .st_catalog_record_version(
    artifact_path  = sp$path,
    format         = fmt,
    size_bytes     = meta$size_bytes,
    content_hash   = meta$content_hash,
    code_hash      = meta$code_hash,
    created_at     = meta$created_at,
    sidecar_format = .st_sidecar_present(sp$path)
  )
  # Commit files AND parents
  .st_version_commit_files(sp$path, vid, parents = parents)

  cli::cli_inform(c("v" = "Saved [{.field {fmt}}] \u2192 {.field {sp$path}} @ version {.field {vid}}"))
  invisible(list(path = sp$path, metadata = meta, version_id = vid))
}



#' Load an object from disk (format auto-detected; optional integrity checks)
#' @param file path or st_path
#' @param format optional format override
#' @param ... forwarded to format reader
#' @return the loaded object
#' @export
st_load <- function(file, format = NULL, ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)
  if (!fs::file_exists(sp$path)) {
    cli::cli_abort("File does not exist: {.field {sp$path}}")
  }

  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}}. See {.fn st_formats}.")
  }

  do_verify <- isTRUE(st_opts("verify_on_load", .get = TRUE))

  # Read sidecar once if we might verify anything
  meta <- if (do_verify) {
    tryCatch(st_read_sidecar(sp$path), error = function(e) NULL)
  } else NULL

  # 1) Optional FILE integrity check (sidecar file hash vs current file)
  if (do_verify && is.list(meta) && is.character(meta$file_hash) && nzchar(meta$file_hash)) {
    now <- tryCatch(st_hash_file(sp$path), error = function(e) NA_character_)
    if (!is.na(now) && !identical(now, meta$file_hash)) {
      cli::cli_warn("File hash mismatch for {.field {sp$path}} (sidecar vs disk). The file may have changed outside {.pkg stamp}.")
    }
  }

  # Read the artifact
  res <- h$read(sp$path, ...)

  # 2) Optional CONTENT integrity check (rehash loaded object vs sidecar content_hash)
  if (do_verify && is.list(meta) && is.character(meta$content_hash) && nzchar(meta$content_hash)) {
    h_now <- tryCatch(st_hash_obj(res), error = function(e) NA_character_)
    if (!is.na(h_now) && !identical(h_now, meta$content_hash)) {
      cli::cli_warn("Loaded object hash mismatch for {.field {sp$path}} (content hash differs from sidecar).")
    }
  }

  cli::cli_inform(c("v" = "Loaded [{.field {fmt}}] \u2190 {.field {sp$path}}"))
  res
}

#' Inspect an artifact's current status (sidecar + catalog + snapshot location)
#' @param path Artifact path
#' @return A named list with fields:
#'   - sidecar: sidecar list (or NULL)
#'   - catalog: list(latest_version_id, n_versions)
#'   - snapshot_dir: absolute path to latest version dir (or NA)
#'   - parents: list(...) parsed from latest version's parents.json (if any)
#' @export
st_info <- function(path) {
  sc  <- st_read_sidecar(path)
  cat <- .st_catalog_read()
  aid <- .st_artifact_id(path)

  latest <- st_latest(path)
  artrow <- cat$artifacts[cat$artifacts$artifact_id == aid, , drop = FALSE]
  nvers  <- if (nrow(artrow)) artrow$n_versions[[1L]] else 0L

  vdir   <- .st_version_dir_latest(path)
  # Prefer committed snapshot parents (parents.json) when available.
  # If no snapshot exists, fall back to the artifact sidecar's quick parents
  # metadata so users can still inspect lineage even when a snapshot was not created.
  parents <- if (is.na(vdir)) sc$parents %||% list() else .st_version_read_parents(vdir)

  list(
    sidecar      = sc,
    catalog      = list(latest_version_id = latest, n_versions = nvers),
    snapshot_dir = vdir,
    parents      = parents
  )
}


# -------- Helpers --------------
#' Explain why an artifact would change
#' @inheritParams st_changed
#' @return Character scalar: "no_change", "missing_artifact", "missing_meta", or e.g. "content+code"
#' @export
st_changed_reason <- function(path, x = NULL, code = NULL, mode = c("any","content","code","file")) {
  mode <- match.arg(mode)
  res <- st_changed(path, x = x, code = code, mode = mode)
  res$reason
}

#' Decide if a save should proceed given current st_opts()
#' Uses versioning policy and code-change rule.
#' @inheritParams st_changed
#' @return list(save = <lgl>, reason = <chr>, latest_version_id = <chr or NA>)
#' @export
# Returns list(save, reason)
st_should_save <- function(path, x = NULL, code = NULL) {
  # First write always allowed
  if (!fs::file_exists(path)) {
    return(list(save = TRUE, reason = "missing_artifact"))
  }
  # No sidecar? write to re-materialize metadata
  meta <- tryCatch(st_read_sidecar(path), error = function(e) NULL)
  if (is.null(meta)) {
    return(list(save = TRUE, reason = "missing_meta"))
  }

  # Policy: by default write when content OR code changed
  # (per earlier decision; no extra option needed)
  res <- st_changed(path, x = x, code = code, mode = "any")
  if (res$changed) {
    return(list(save = TRUE, reason = res$reason))
  }

  # Respect versioning = "timestamp" (always write), "off" (never write)
  vers <- st_opts("versioning", .get = TRUE) %||% "content"
  if (identical(vers, "timestamp")) return(list(save = TRUE,  reason = "policy_timestamp"))
  if (identical(vers, "off"))       return(list(save = FALSE, reason = "no_change_policy"))

  # default: no change → skip
  list(save = FALSE, reason = "no_change_policy")
}


