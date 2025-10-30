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
  root <- fs::path_abs(root)
  st_state_set(state_dir = state_dir)

  sd <- fs::path(root, state_dir)
  .st_dir_create(sd)
  .st_dir_create(fs::path(sd, "temp"))
  .st_dir_create(fs::path(sd, "logs"))

  cli::cli_inform(c(
    "v" = "stamp initialized",
    " " = paste0("root: {.field ", root, "}"),
    " " = paste0("state: {.field ", fs::path_abs(sd), "}")
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
#' @param ... forwarded to format writer
#' @return invisibly, a list with path, metadata, and version_id
#' @export
st_save <- function(x, file, format = NULL, metadata = list(), code = NULL, ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)

  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}}. See {.fn st_formats} or {.fn st_register_format}.")
  }

  # ---- Hashes (Milestone 2) --------------------------------------------------
  versioning      <- st_opts("versioning", .get = TRUE)
  do_code_hash    <- isTRUE(st_opts("code_hash", .get = TRUE)) && !is.null(code)
  do_file_hash    <- isTRUE(st_opts("store_file_hash", .get = TRUE)) # computed AFTER write

  content_hash <- st_hash_obj(x) # cheap enough; we use it for change detection
  code_hash    <- if (do_code_hash) st_hash_code(code) else NA_character_

  # If versioning == "content", skip writing when content didn't change
  if (identical(versioning, "content")) {
    last <- .st_catalog_latest_version_row(sp$path)
    last_ch <- if (!is.null(last)) as.character(last$content_hash[[1L]]) else NA_character_
    if (!is.na(last_ch) && nzchar(last_ch) && identical(last_ch, content_hash)) {
      cli::cli_alert_info("No content change for {.field {sp$path}}; keeping latest version {.field {last$version_id[[1L]]}}.")
      # Still return a structured result
      return(invisible(list(
        path = sp$path,
        metadata = st_read_sidecar(sp$path),
        version_id = last$version_id[[1L]]
      )))
    }
  }

  # ensure parent dir exists
  .st_dir_create(fs::path_dir(sp$path))

  # write to temp in same dir, then move atomically
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(sp$path), pattern = fs::path_file(sp$path))
  h$write(x, tmp, ...)

  # move into place
  if (fs::file_exists(sp$path)) fs::file_delete(sp$path)
  fs::file_move(tmp, sp$path)

  # optional file hash (post-write)
  file_hash <- if (do_file_hash) st_hash_file(sp$path) else NA_character_

  # sidecar metadata
  meta <- c(
    list(
      path        = as.character(sp$path),
      format      = fmt,
      created_at  = .st_now_utc(),
      size_bytes  = unname(fs::file_info(sp$path)$size),
      content_hash = content_hash,
      code_hash    = code_hash,
      file_hash    = file_hash,
      attrs       = list()  # reserved for stamp internals
    ),
    metadata
  )
  .st_write_sidecar(sp$path, meta)

  # Record catalog version + snapshot
  vid <- .st_catalog_record_version(
    artifact_path  = sp$path,
    format         = fmt,
    size_bytes     = meta$size_bytes,
    content_hash   = meta$content_hash,
    code_hash      = meta$code_hash,
    created_at     = meta$created_at,
    sidecar_format = .st_sidecar_present(sp$path)
  )
  .st_version_commit_files(sp$path, vid)

  cli::cli_inform(c("v" = "Saved [{.field {fmt}}] \u2192 {.field {sp$path}} @ version {.field {vid}}"))
  invisible(list(path = sp$path, metadata = meta, version_id = vid))
}

#' Load an object from disk (format auto-detected by extension or explicit format)
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

  # Optional verify-on-load: compare stored file hash (if any) with current file
  if (isTRUE(st_opts("verify_on_load", .get = TRUE))) {
    meta <- st_read_sidecar(sp$path)
    if (is.list(meta) && is.character(meta$file_hash) && nzchar(meta$file_hash)) {
      now <- st_hash_file(sp$path)
      if (!identical(now, meta$file_hash)) {
        cli::cli_warn("File hash mismatch for {.field {sp$path}} (sidecar vs. disk). The file may have changed outside stamp.")
      }
    }
  }

  res <- h$read(sp$path, ...)
  cli::cli_inform(c("v" = "Loaded [{.field {fmt}}] \u2190 {.field {sp$path}}"))
  res
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
#' Uses versioning policy ("content"/"off") to gate writes.
#' @inheritParams st_changed
#' @return list(save = <lgl>, reason = <chr>, latest_version_id = <chr or NA>)
#' @export
st_should_save <- function(path, x = NULL, code = NULL) {
  ver <- st_opts("versioning", .get = TRUE)
  if (identical(ver, "off")) {
    return(list(save = TRUE, reason = "versioning_off", latest_version_id = st_latest(path)))
  }
  # default: treat anything not "off" as content-aware
  res <- st_changed(path, x = x, code = code, mode = "any")
  if (!res$changed) {
    list(save = FALSE, reason = "no_change", latest_version_id = st_latest(path))
  } else {
    list(save = TRUE,  reason = res$reason, latest_version_id = st_latest(path))
  }
}
