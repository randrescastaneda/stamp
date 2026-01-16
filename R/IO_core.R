# ---- st_init -----------------------------------------------------------------
#' Initialize stamp project structure
#' @param root project root (default ".")
#' @param state_dir directory name for internal state (default ".stamp")
#' @return (invisibly) the absolute state dir
#' @param alias Optional character alias to identify this stamp folder.
#'   If `NULL`, uses "default" for backwards compatibility.
#' @export
st_init <- function(root = ".", state_dir = ".stamp", alias = NULL) {
  root_abs <- fs::path_abs(root)
  alias <- alias %||% "default" # Backwards-compatible default alias

  sd <- fs::path(root_abs, state_dir)
  sd_abs <- fs::path_abs(sd)

  # Enforce: same alias cannot map to different folders
  existing <- .st_alias_get(alias)
  if (!is.null(existing) && !identical(existing$stamp_path, sd_abs)) {
    cli::cli_abort(c(
      "x" = "Alias {.val {alias}} is already registered for a different folder.",
      "i" = paste0(
        "Existing: ",
        existing$stamp_path,
        "; Requested: ",
        sd_abs,
        ". Use a different alias or remove the conflict."
      )
    ))
  }

  # Warn: different aliases pointing to the same folder
  for (nm in rlang::env_names(.stamp_aliases)) {
    if (identical(nm, alias)) {
      next
    }
    cfg <- rlang::env_get(.stamp_aliases, nm, default = NULL)
    if (!is.null(cfg) && identical(cfg$stamp_path, sd_abs)) {
      cli::cli_warn(c(
        "!" = "Alias {.val {alias}} points to the same folder as existing alias {.val {nm}}.",
        "i" = "They will share the same catalog and versions."
      ))
    }
  }

  # Maintain legacy single-folder state for default alias
  if (identical(alias, "default")) {
    st_state_set(root_dir = root_abs, state_dir = state_dir)
  }

  # Ensure directories exist (idempotent)
  .st_dir_create(sd)
  .st_dir_create(fs::path(sd, "temp"))
  .st_dir_create(fs::path(sd, "logs"))

  # Register alias configuration for multi-folder management
  .st_alias_register(
    alias,
    root = root_abs,
    state_dir = state_dir,
    stamp_path = sd_abs
  )

  cli::cli_inform(c(
    "v" = "stamp initialized",
    " " = paste0("alias: ", alias),
    " " = paste0("root: ", root_abs),
    " " = paste0("state: ", sd_abs)
  ))
  invisible(sd_abs)
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
  cli::cli_inform(
    "<{.field st_path}> {.field {x$path}} [format={.field {x$format}}]"
  )
  invisible(x)
}

# ---- format inference --------------------------------------------------------

.st_guess_format <- function(path) {
  ext <- tolower(fs::path_ext(path))
  if (!nzchar(ext)) {
    return(NULL)
  }
  if (rlang::env_has(.st_formats_env, ext)) {
    return(ext)
  }
  if (rlang::env_has(.st_extmap_env, ext)) {
    return(rlang::env_get(.st_extmap_env, ext))
  }
  NULL
}


# ---- Load and Save -----------------------------------------------------------

#' Save an R object to disk with metadata & versioning (atomic move)
#'
#' @param x object to save
#' @param file destination path (character or st_path)
#' @param format optional format override ("qs2" | "rds" | "csv" | "fst" | "json")
#' @param metadata named list of extra metadata (merged into sidecar)
#' @param code Optional function/expression/character whose hash is stored as `code_hash`.
#' @param parents Optional list of parent descriptors:
#'   list(list(path = "<path>", version_id = "<id>"), ...).
#' @param code_label Optional short label/description of the producing code (for humans).
#' @param pk optional character vector of primary-key columns (for tables)
#' @param domain optional character scalar or vector label(s) for the dataset
#' @param unique logical; enforce uniqueness of pk at save time (default TRUE)
#' @param ... forwarded to format writer
#' @param verbose logical; if `FALSE`, suppress informational messages and package-generated
#'   warnings (default TRUE). When `FALSE`, messages about skipped saves or save
#'   failures emitted by `st_save()` will not be shown.
#' @param alias Optional stamp alias to target a specific stamp folder.
#'   If `NULL` (default), uses the default/legacy stamp folder initialized
#'   via `st_init()`. Use aliases to operate across multiple stamp folders.
#' @return invisibly, a list with path, metadata, and version_id (or skipped=TRUE)
#' @export
st_save <- function(
  x,
  file,
  format = NULL,
  metadata = list(),
  code = NULL,
  parents = NULL,
  code_label = NULL,
  pk = NULL,
  domain = NULL,
  unique = TRUE,
  verbose = TRUE,
  alias = NULL,
  ...
) {
  # Input validation for verbose
  stopifnot(is.logical(verbose), length(verbose) == 1L, !is.na(verbose))
  # Normalize path + format selection
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)

  # Primary-key handling for tabular objects
  if (!is.null(pk)) {
    if (!is.data.frame(x)) {
      cli::cli_abort("{.arg pk} supplied but object is not a data.frame.")
    }
    x <- st_set_pk(x, pk = pk, domain = domain, unique = unique)
  } else {
    if (is.data.frame(x)) st_assert_pk(x) # sanity check for attached PK metadata
  }

  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort(
      "Unknown format {.field {fmt}}. See {.fn st_formats} or {.fn st_register_format}."
    )
  }

  # Prepare sanitized object (content-only for tabular data) for hashing & storage
  x_sanitized <- st_sanitize_for_hash(x)

  # Decide if we should create a new version (hashes, code hash, etc.)
  # Use sanitized object so decision aligns with stored content
  dec <- st_should_save(sp$path, x = x_sanitized, code = code)
  if (!dec$save) {
    if (isTRUE(verbose)) {
      cli::cli_inform(c(
        "v" = "Skip save (reason: {.field {dec$reason}}) for {.file {sp$path}}"
      ))
    }
    return(invisible(list(path = sp$path, skipped = TRUE, reason = dec$reason)))
  }

  # Ensure destination directory exists (idempotent)
  fs::dir_create(fs::path_dir(sp$path), recurse = TRUE)

  # Write + sidecar + catalog under a best-effort file lock
  out <- tryCatch(
    .st_with_lock(sp$path, {
      # 1) Atomic artifact write (overwrite-in-place policy lives here)
      .st_write_atomic(
        obj = x_sanitized,
        path = sp$path,
        writer = function(obj, pth) {
          # Forward writer args including verbose to the concrete writer.
          # Filter out st_save-specific args (e.g. pk, domain) that format
          # writers don't expect.
          args_local <- list(...)
          writer_formals <- names(formals(h$write))

          if (!is.null(writer_formals) && length(args_local)) {
            # Keep only named args that the writer accepts
            named <- names(args_local)
            named <- if (is.null(named)) rep("", length(args_local)) else named
            keep_idx <- which(named != "" & named %in% writer_formals)
            if (length(keep_idx)) {
              do.call(
                h$write,
                c(list(obj, pth, verbose = verbose), args_local[keep_idx])
              )
            } else {
              h$write(obj, pth, verbose = verbose)
            }
          } else {
            h$write(obj, pth, verbose = verbose)
          }
        },
        overwrite = TRUE
      )

      # 2) Assemble sidecar metadata (needs size/file hash after the move)
      meta <- c(
        list(
          path = as.character(sp$path),
          format = fmt,
          created_at = .st_now_utc(),
          size_bytes = unname(fs::file_info(sp$path)$size),
          content_hash = st_hash_obj(x_sanitized),
          code_hash = if (
            isTRUE(st_opts("code_hash", .get = TRUE)) && !is.null(code)
          ) {
            st_hash_code(code)
          } else {
            NA_character_
          },
          file_hash = if (isTRUE(st_opts("store_file_hash", .get = TRUE))) {
            st_hash_file(sp$path)
          } else {
            NA_character_
          },
          code_label = code_label %||% NA_character_,
          parents = parents %||% list(),
          attrs = list()
        ),
        metadata
      )

      # Mirror PK/domain from the object into sidecar when applicable
      if (is.data.frame(x_sanitized)) {
        pk_keys <- st_get_pk(x_sanitized)
        if (length(pk_keys)) {
          meta$pk <- list(keys = pk_keys)
        }
        dom <- attr(x_sanitized, "stamp_domain", exact = TRUE)
        if (!is.null(dom)) meta$domain <- as.character(dom)
      }

      # 3) Sidecar write (should be atomic inside the helper)
      .st_write_sidecar(sp$path, meta)

      # 4) Catalog snapshot + version commit
      vid <- .st_catalog_record_version(
        artifact_path = sp$path,
        format = fmt,
        size_bytes = meta$size_bytes,
        content_hash = meta$content_hash,
        code_hash = meta$code_hash,
        created_at = meta$created_at,
        sidecar_format = .st_sidecar_present(sp$path),
        alias = alias
      )
      # Defensive fallback: if for any reason the catalog helper returned
      # an empty or non-character id, compute a stable local version id
      # based on timestamp and available hashes so callers (and tests)
      # receive a non-empty identifier.
      if (!is.character(vid) || !nzchar(vid)) {
        vid <- .st_version_id(
          meta$created_at,
          meta$content_hash,
          meta$code_hash
        )
      }
      .st_version_commit_files(sp$path, vid, parents = parents, alias = alias)

      # 5) Optional retention for this artifact
      .st_apply_retention(sp$path, alias = alias)

      if (isTRUE(verbose)) {
        cli::cli_inform(c(
          "v" = "Saved [{.field {fmt}}] \u2192 {.file {sp$path}} @ version {.field {vid}}"
        ))
      }
      list(path = sp$path, metadata = meta, version_id = vid)
    }),
    error = function(e) {
      # Best-effort: surface a warning and allow the function to fall back
      # to a safe return value rather than failing the whole process.
      if (isTRUE(verbose)) {
        cli::cli_warn(c(
          "x" = "Save failed for {.file {sp$path}}: {conditionMessage(e)}",
          "i" = "Returning fallback result (no metadata/version)."
        ))
      }
      NULL
    }
  )

  invisible(out %||% list(path = sp$path, metadata = NULL, version_id = NULL))
}


#' Load an object from disk (format auto-detected; optional integrity checks)
#' @param file path or st_path
#' @param format optional format override
#' @param version An integer or a quoted directive. Retrieve a specific version
#'   of an artifact. See details.
#' @param ... forwarded to format reader
#' @param verbose logical; if FALSE, suppress informational messages and package-generated
#'   warnings (default TRUE). When `FALSE`, warnings about file/content hash
#'   mismatches and a missing primary key recorded by `st_load()` will not be shown.
#' @param alias Optional stamp alias to target a specific stamp folder.
#'   If `NULL` (default), uses the default/legacy stamp folder initialized
#'   via `st_init()`. Use aliases to operate across multiple stamp folders.
#' @return the loaded object
#' @details
#' The `version` argument allows you to load specific versions:
#'   * `NULL` (default): loads the most recent version available.
#'   * Negative integer (e.g., `-1`) or zero (`0`): loads that number of versions
#'     before the most recent version. So, if `0`, it loads the current
#'     version, which is equivalent to `NULL`. If `-1`, it will load the version
#'     right before the current one, `-2` loads two versions before, and so on.
#'   * Positive numbers: Error.
#'   * Character: treated as a specific version ID (e.g., "20250801T162739Z-d86e8").
#'   * `"select"`, `"pick"`, or `"choose"`: displays an interactive menu to select from
#'     available versions (only in interactive R sessions).
#' @examples
#' \dontrun{
#' # Basic usage: load latest version
#' data <- st_load("data/mydata.rds")
#'
#' # Load previous version
#' old_data <- st_load("data/mydata.rds", version = -1)
#'
#' # Load specific version by ID
#' vid <- st_versions("data/mydata.rds")$version_id[3]
#' specific <- st_load("data/mydata.rds", version = vid)
#'
#' # Interactive menu (in interactive sessions only)
#' selected <- st_load("data/mydata.rds", version = "select")
#' # or use "pick" or "choose"
#' selected <- st_load("data/mydata.rds", version = "pick")
#' }
#' @export
st_load <- function(
  file,
  format = NULL,
  version = NULL,
  verbose = TRUE,
  alias = NULL,
  ...
) {
  # Input validation for verbose
  stopifnot(is.logical(verbose), length(verbose) == 1L, !is.na(verbose))
  # Normalize input into an st_path
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)

  # If a specific version is requested, resolve it and delegate to st_load_version
  if (!is.null(version)) {
    version_id <- .st_resolve_version(sp$path, version, alias = alias)
    if (is.na(version_id)) {
      cli::cli_abort(
        "Could not resolve version {.val {version}} for {.file {sp$path}}"
      )
    }
    return(st_load_version(
      sp$path,
      version_id,
      ...,
      verbose = verbose,
      alias = alias
    ))
  }

  # Existence check
  if (!fs::file_exists(sp$path)) {
    cli::cli_abort("File does not exist: {.file {sp$path}}")
  }

  # Resolve format
  fmt <- format %||%
    sp$format %||%
    .st_guess_format(sp$path) %||%
    st_opts("default_format", .get = TRUE)

  # Lookup format handlers
  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}}. See {.fn st_formats}.")
  }

  # Read sidecar once (we'll reuse it for verify, pk/schema, etc.)
  meta <- tryCatch(st_read_sidecar(sp$path), error = function(e) NULL)

  # (1) Optional FILE integrity check: sidecar$file_hash vs current file hash
  if (isTRUE(st_opts("verify_on_load", .get = TRUE))) {
    if (
      is.list(meta) && is.character(meta$file_hash) && nzchar(meta$file_hash)
    ) {
      now <- tryCatch(st_hash_file(sp$path), error = function(e) NA_character_)
      if (!is.na(now) && !identical(now, meta$file_hash)) {
        if (isTRUE(verbose)) {
          cli::cli_warn(c(
            "File hash mismatch for {.file {sp$path}} (sidecar vs disk).",
            "i" = "The file may have changed outside {.pkg stamp}."
          ))
        }
      }
    }
  }

  # Read the artifact with the registered reader
  res <- h$read(sp$path, verbose = verbose, ...)

  # (2) Optional CONTENT integrity check: sidecar$content_hash vs rehash of loaded object
  if (isTRUE(st_opts("verify_on_load", .get = TRUE))) {
    if (
      is.list(meta) &&
        is.character(meta$content_hash) &&
        nzchar(meta$content_hash)
    ) {
      h_now <- tryCatch(st_hash_obj(res), error = function(e) NA_character_)
      if (!is.na(h_now) && !identical(h_now, meta$content_hash)) {
        if (isTRUE(verbose)) {
          cli::cli_warn(
            "Loaded object hash mismatch for {.file {sp$path}} (content hash differs from sidecar)."
          )
        }
      }
    }
  }

  # Restore original object attributes (data.table class, row.names, etc.)
  res <- .st_restore_sanitized_object(res)

  #  pk presence check on load (warn or error depending on options) \
  pk_keys <- character(0)
  if (is.list(meta) && !is.null(meta$pk)) {
    # expect meta$pk$keys
    if (!is.null(meta$pk$keys)) {
      pk_keys <- as.character(meta$pk$keys)
    }
    pk_keys <- pk_keys[nzchar(pk_keys)]
  }

  if (!length(pk_keys)) {
    if (isTRUE(st_opts("require_pk_on_load", .get = TRUE))) {
      cli::cli_abort(c(
        "No primary key recorded for {.file {sp$path}}.",
        "i" = "Record it with {.code st_add_pk({.file {sp$path}}, keys = c('...'))}."
      ))
    } else if (isTRUE(st_opts("warn_missing_pk_on_load", .get = TRUE))) {
      if (isTRUE(verbose)) {
        cli::cli_warn(c(
          "No primary key recorded for {.file {sp$path}}.",
          "i" = "You can add one with {.fn st_add_pk}."
        ))
      }
    }
  } else if (is.data.frame(res)) {
    # Attach pk keys as a convenience attribute
    attr(res, "stamp_pk") <- list(keys = pk_keys)
  }

  # Reattach schema if present and not already attached
  if (
    !is.null(meta$schema) &&
      is.data.frame(res) &&
      is.null(attr(res, "stamp_schema"))
  ) {
    attr(res, "stamp_schema") <- meta$schema
  }

  # Reattach domain if present and not already attached
  if (
    !is.null(meta$domain) &&
      is.data.frame(res) &&
      is.null(attr(res, "stamp_domain"))
  ) {
    attr(res, "stamp_domain") <- meta$domain
  }

  if (isTRUE(verbose)) {
    cli::cli_inform(c("v" = "Loaded [{.field {fmt}}] \u2190 {.file {sp$path}}"))
  }
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
st_info <- function(path, alias = NULL) {
  sc <- st_read_sidecar(path)
  cat <- .st_catalog_read(alias = alias)
  aid <- .st_artifact_id(path)

  latest <- st_latest(path, alias = alias)
  artrow <- cat$artifacts[cat$artifacts$artifact_id == aid, , drop = FALSE]
  nvers <- if (nrow(artrow)) artrow$n_versions[[1L]] else 0L

  vdir <- .st_version_dir_latest(path, alias = alias)
  # Prefer committed snapshot parents (parents.json) when available.
  # If no snapshot exists, fall back to the artifact sidecar's quick parents
  # metadata so users can still inspect lineage even when a snapshot was not created.
  parents <- if (is.na(vdir)) {
    sc$parents %||% list()
  } else {
    .st_version_read_parents(vdir)
  }

  list(
    sidecar = sc,
    catalog = list(latest_version_id = latest, n_versions = nvers),
    snapshot_dir = vdir,
    parents = parents
  )
}


# -------- Helpers --------------
#' Explain why an artifact would change
#' @inheritParams st_changed
#' @return Character scalar: "no_change", "missing_artifact", "missing_meta", or e.g. "content+code"
#' @export
st_changed_reason <- function(
  path,
  x = NULL,
  code = NULL,
  mode = c("any", "content", "code", "file")
) {
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
  if (identical(vers, "timestamp")) {
    return(list(save = TRUE, reason = "policy_timestamp"))
  }
  if (identical(vers, "off")) {
    return(list(save = FALSE, reason = "no_change_policy"))
  }

  # default: no change → skip
  list(save = FALSE, reason = "no_change_policy")
}

#' @keywords internal
.st_write_atomic <- function(obj, path, writer, overwrite = FALSE) {
  dir.create(fs::path_dir(path), recursive = TRUE, showWarnings = FALSE)

  tmp <- paste0(
    path,
    ".tmp-",
    sprintf("%08x", sample.int(.Machine$integer.max, 1))
  )
  on.exit(try(fs::file_delete(tmp), silent = TRUE), add = TRUE)

  writer(obj, tmp) # e.g., qs::qsave / saveRDS / jsonlite::write_json ...

  if (!fs::file_exists(tmp)) {
    stop("Temp file not created: ", tmp, call. = FALSE)
  }
  if (fs::file_exists(path)) {
    if (isTRUE(overwrite)) {
      fs::file_delete(path) # atomic move below requires dest not to exist
    } else {
      stop("Destination exists and overwrite = FALSE: ", path, call. = FALSE)
    }
  }
  fs::file_move(tmp, path) # atomic on same filesystem
  invisible(path)
}


#' @keywords internal
.st_with_lock <- function(path, expr) {
  # Best-effort lock: use filelock if available; otherwise just run expr.
  lockfile <- paste0(
    normalizePath(path, winslash = "/", mustWork = FALSE),
    ".lock"
  )
  # Evaluate the provided expression in the caller's environment so that
  # assignments using `<<-` inside the block affect variables in the
  # calling function (important for code that captures results by
  # side-effect, e.g. `result <<- ...` inside a lock block).
  eval_env <- parent.frame()
  if (requireNamespace("filelock", quietly = TRUE)) {
    dir.create(dirname(lockfile), recursive = TRUE, showWarnings = FALSE)
    lock <- filelock::lock(lockfile, timeout = 5000) # 5s
    on.exit(try(filelock::unlock(lock), silent = TRUE), add = TRUE)
    eval(substitute(expr), envir = eval_env)
  } else {
    eval(substitute(expr), envir = eval_env) # advisory fallback
  }
}
