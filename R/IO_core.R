#' stamp: Milestone 1 — I/O core (qs2-first), cli+fs only
#' Depends: cli, fs, jsonlite (and optionally qs2, qs, fst, data.table)
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
#' @param partition_key optional partition key (not used in M1)
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

  # 1) direct match: extension equals a registered format name
  if (rlang::env_has(.st_formats_env, ext)) return(ext)

  # 2) mapped extension (e.g., 'qs' -> 'qs2'); seeded in zzz.R
  if (rlang::env_has(.st_extmap_env, ext)) {
    return(rlang::env_get(.st_extmap_env, ext))
  }

  # 3) unknown
  NULL
}

# ---- Load and Save -----------------------------------------------------------

#' Save an R object to disk with sidecar metadata (atomic move)
#' @param x object to save
#' @param file destination path (character or st_path)
#' @param format optional format override ("qs2" | "rds" | "csv" | "fst" | "json")
#' @param metadata named list of extra metadata (stored in sidecar)
#' @param ... forwarded to format writer
#' @return invisibly, a list with path and metadata
#' @export
st_save <- function(x, file, format = NULL, metadata = list(), ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)

  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}}. See {.fn st_formats} or {.fn st_register_format}.")
  }

  # ensure parent dir exists
  .st_dir_create(fs::path_dir(sp$path))

  # write to temp in same dir, then move atomically
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(sp$path), pattern = fs::path_file(sp$path))
  h$write(x, tmp, ...)

  # move into place
  if (fs::file_exists(sp$path)) fs::file_delete(sp$path)
  fs::file_move(tmp, sp$path)

    # sidecar metadata (no hashing yet — will extend in Milestone 2)
  meta <- c(
    list(
      path        = as.character(sp$path),
      format      = fmt,
      created_at  = .st_now_utc(),
      size_bytes  = unname(fs::file_info(sp$path)$size),
      attrs       = list()  # reserved for stamp internals
    ),
    metadata
  )
  .st_write_sidecar(sp$path, meta)

  # --- NEW: record a version + commit files to versions/ ---
  created_at <- meta$created_at
  size_bytes <- meta$size_bytes
  # For now (Milestone 1) we don't compute hashes; pass NA.
  vid <- .st_catalog_record_version(
    artifact_path  = sp$path,
    format         = fmt,
    size_bytes     = size_bytes,
    content_hash   = NA_character_,
    code_hash      = NA_character_,
    created_at     = created_at,
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

  res <- h$read(sp$path, ...)
  cli::cli_inform(c("v" = "Loaded [{.field {fmt}}] \u2190 {.field {sp$path}}"))
  res
}
