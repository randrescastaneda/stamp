# aaa.R — foundational objects, loaded first (alphabetical order)

#' Null-coalescing operator (internal)
#'
#' Return `b` when `a` is `NULL`, otherwise return `a`.
#'
#' @param a Value to test for `NULL`.
#' @param b Fallback value returned when `a` is `NULL`.
#' @return Either `a` (when not `NULL`) or `b`.
#' @keywords internal
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

# ------------------------------------------------------------------------------
# Package-level environments (central stores)
# ------------------------------------------------------------------------------

# Format registry: name -> list(read = fn, write = fn)
.st_formats_env <- rlang::env()

# Extension map: file extension -> format name (e.g., "qs" -> "qs2")
.st_extmap_env <- rlang::env()

# Options store used by st_opts() (values populated at load time)
.stamp_opts <- rlang::env()

# Lightweight package state (keeps paths, etc.)
.stamp_state <- rlang::env(
  state_dir = ".stamp" # default; can be overridden via st_state_set()
)

# Alias registry: alias -> list(root, state_dir, stamp_path)
# Holds in-memory configurations for each initialized stamp folder.
# Aliases do NOT affect on-disk paths; they only select which configuration
# (root/state_dir) subsequent calls should use.
.stamp_aliases <- rlang::env()

# Builder registry (used by st_register_builder / st_rebuild)
.st_builders_env <- rlang::env()


# ------------------------------------------------------------------------------
# State helpers (no side effects)
# ------------------------------------------------------------------------------

st_state_set <- function(...) {
  rlang::env_bind(.stamp_state, !!!rlang::list2(...))
  invisible(NULL)
}

st_state_get <- function(key, default = NULL) {
  rlang::env_get(.stamp_state, key, default = default)
}

# ------------------------------------------------------------------------------
# Alias helpers (internal)
# ------------------------------------------------------------------------------

#' Register or update an alias configuration (internal)
#' @keywords internal
.st_alias_register <- function(alias, root, state_dir, stamp_path) {
  # Register or update an alias → used purely for selecting config.
  stopifnot(is.character(alias), length(alias) == 1L, nzchar(alias))
  cfg <- list(root = root, state_dir = state_dir, stamp_path = stamp_path)
  rlang::env_poke(.stamp_aliases, alias, cfg)
  invisible(alias)
}

#' Retrieve alias configuration (internal)
#' @keywords internal
.st_alias_get <- function(alias) {
  # Retrieve alias config; NULL alias resolves to "default".
  stopifnot(is.character(alias) || is.null(alias))
  if (is.null(alias)) {
    alias <- "default"
  }
  rlang::env_get(.stamp_aliases, alias, default = NULL)
}

#' Check if a path belongs to an alias's root (internal)
#' @keywords internal
.st_path_matches_alias <- function(path, alias) {
  # Check if the path is under the alias's root directory
  if (is.null(alias)) {
    return(TRUE) # NULL alias means default; no mismatch warning needed
  }

  cfg <- .st_alias_get(alias)
  if (is.null(cfg)) {
    return(FALSE) # Alias not registered
  }

  path_abs <- .st_make_abs(path)
  root_abs <- as.character(cfg$root)

  # Normalize for platform-aware comparison
  path_norm <- .st_normalize_path(path_abs)
  root_norm <- .st_normalize_path(root_abs)

  # Ensure root ends with "/" for proper boundary matching
  root_norm_slash <- if (endsWith(root_norm, "/")) {
    root_norm
  } else {
    paste0(root_norm, "/")
  }

  # Path is exactly the root OR starts with root/
  identical(path_norm, root_norm) || startsWith(path_norm, root_norm_slash)
}

#' Detect which alias a path belongs to (internal)
#' @keywords internal
.st_detect_alias_from_path <- function(path) {
  # Find which registered alias's root contains this path
  # Returns the alias name, or NULL if no match found

  path_abs <- .st_make_abs(path)
  path_norm <- .st_normalize_path(path_abs)

  # Check all registered aliases
  all_aliases <- rlang::env_names(.stamp_aliases)

  # Build match vector (NA for non-matches)
  match_lengths <- vapply(
    all_aliases,
    function(alias_name) {
      cfg <- rlang::env_get(.stamp_aliases, alias_name, default = NULL)
      if (is.null(cfg)) {
        return(NA_integer_)
      }

      root_norm <- .st_normalize_path(cfg$root)
      root_norm_slash <- if (endsWith(root_norm, "/")) {
        root_norm
      } else {
        paste0(root_norm, "/")
      }

      # Check: path is exactly the root OR starts with root/
      is_match <- identical(path_norm, root_norm) ||
        startsWith(path_norm, root_norm_slash)
      if (is_match) nchar(root_norm) else NA_integer_
    },
    integer(1)
  )

  # Return longest match or NULL
  if (all(is.na(match_lengths))) {
    return(NULL)
  }
  all_aliases[which.max(match_lengths)]
}

#' Normalize path for platform-aware comparison (internal)
#' @keywords internal
.st_normalize_path <- function(path) {
  if (.Platform$OS.type == "windows") {
    tolower(normalizePath(
      as.character(path),
      winslash = "/",
      mustWork = FALSE
    ))
  } else {
    as.character(path)
  }
}

#' Helper: produce an absolute path safely (internal)
#' @keywords internal
.st_make_abs <- function(p) {
  stopifnot(is.character(p), length(p) == 1L)
  tryCatch(
    as.character(fs::path_abs(p)),
    error = function(e) as.character(p)
  )
}

#' Resolve file path using alias (internal)
#' @keywords internal
#' @param file character path (bare filename or path with directory)
#' @param alias character alias or NULL
#' @param verbose logical; if TRUE, emit warnings
#' @return list(path = resolved_path, alias_used = alias_name, was_bare = logical)
.st_resolve_file_path <- function(file, alias = NULL, verbose = TRUE) {
  # Input validation
  if (
    !is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)
  ) {
    cli::cli_abort(c(
      "x" = "`file` must be a non-missing, non-empty character scalar.",
      "i" = "Provide a single filename or path, e.g. {.file \"data.qs2\"} or {.file \"data/file.qs2\"}."
    ))
  }

  # Determine if file is a bare name (no directory component)
  file_dir <- fs::path_dir(file)
  is_bare <- identical(file_dir, ".") || identical(file_dir, "")

  # Case 1: Bare filename → resolve under alias root
  if (is_bare) {
    # Use provided alias or default
    alias_to_use <- alias %||% "default"
    cfg <- .st_alias_get(alias_to_use)

    if (is.null(cfg)) {
      cli::cli_abort(c(
        "x" = "Alias {.val {alias_to_use}} not found.",
        "i" = "Initialize it with {.fn st_init} or use a registered alias."
      ))
    }

    resolved_path <- fs::path(cfg$root, file)
    resolved_path_abs <- .st_make_abs(resolved_path)
    return(list(
      path = resolved_path_abs,
      alias_used = alias_to_use,
      was_bare = TRUE
    ))
  }

  # Case 2: Path with directory component
  # First, try to detect if path (as-is) matches any alias root
  detected_alias <- .st_detect_alias_from_path(file)

  # Case 2a: Path matches an existing alias root
  if (!is.null(detected_alias)) {
    # User provided explicit alias that doesn't match detected
    if (!is.null(alias) && nzchar(alias) && !identical(alias, detected_alias)) {
      cli::cli_abort(c(
        "x" = "Path {.file {file}} belongs to alias {.val {detected_alias}}, not {.val {alias}}.",
        "i" = "Either omit the alias parameter or use alias = {.val {detected_alias}}."
      ))
    }

    # Use detected alias (already absolute and under that alias root)
    path_abs <- .st_make_abs(file)
    return(list(
      path = path_abs,
      alias_used = detected_alias,
      was_bare = FALSE
    ))
  }

  # Case 2b: Path does NOT match any alias → treat as relative under alias
  # Use provided alias or default
  alias_to_use <- alias %||% "default"
  cfg <- .st_alias_get(alias_to_use)

  if (is.null(cfg)) {
    cli::cli_abort(c(
      "x" = "Alias {.val {alias_to_use}} not found.",
      "i" = "Initialize it with {.fn st_init} or provide a valid alias."
    ))
  }

  # Treat file as relative path under alias root
  resolved_path <- fs::path(cfg$root, file)
  resolved_path_abs <- .st_make_abs(resolved_path)

  if (isTRUE(verbose)) {
    # Inform user that subdirectory will be created
    if (!identical(fs::path_dir(file), ".")) {
      cli::cli_inform(c(
        "i" = "Creating subdirectory under alias {.val {alias_to_use}}.",
        " " = "Path: {.path {file}}"
      ))
    }
  }

  return(list(
    path = resolved_path_abs,
    alias_used = alias_to_use,
    was_bare = FALSE
  ))
}

#' Resolve file path and create st_path object (internal)
#' @keywords internal
#' @param file character path or st_path object
#' @param format optional format override
#' @param alias character alias or NULL
#' @param verbose logical; if TRUE, emit warnings
#' @return list(sp = st_path object, resolved_path, alias_used, was_bare)
.st_resolve_and_normalize <- function(
  file,
  format = NULL,
  alias = NULL,
  verbose = TRUE
) {
  resolved <- .st_resolve_file_path(file, alias = alias, verbose = verbose)

  sp <- if (inherits(file, "st_path")) {
    file$path <- resolved$path
    file
  } else {
    st_path(resolved$path, format = format)
  }

  list(
    sp = sp,
    resolved_path = resolved$path,
    alias_used = resolved$alias_used,
    was_bare = resolved$was_bare
  )
}

# ------------------------------------------------------------------------------
# Internal option defaults (single source of truth for st_opts_init_defaults())
# Note: st_opts() itself lives elsewhere; these are the defaults it consumes.
# ------------------------------------------------------------------------------

.stamp_default_opts <- list(
  # Sidecar & metadata
  meta_format = "json", # "json" | "qs2" | "both"

  # Versioning
  versioning = "content", # "content" | "timestamp" | "off"
  force_on_code_change = TRUE, # if code hash differs, write a new version
  retain_versions = Inf, # keep all versions by default

  # Hashing toggles
  code_hash = TRUE, # compute code hash when code= is supplied
  store_file_hash = FALSE, # compute file hash at save (extra I/O)
  verify_on_load = FALSE, # verify file hash on load if available

  # Usability / misc (mirrors; used as we adopt them)
  default_format = "qs2", # resolved writer key for auto-inference
  verbose = TRUE, # future-use for chatty messages
  timezone = (Sys.timezone() %||% "UTC"),
  timeformat = "%Y%m%d%H%M%S",
  usetz = FALSE,

  # primary key enforcement
  require_pk_on_load = FALSE,
  warn_missing_pk_on_load = TRUE
)

# Initialize defaults into .stamp_opts if missing (idempotent; invoked in .onLoad)
st_opts_init_defaults <- function() {
  for (nm in names(.stamp_default_opts)) {
    if (!rlang::env_has(.stamp_opts, nm)) {
      rlang::env_poke(.stamp_opts, nm, .stamp_default_opts[[nm]])
    }
  }
  invisible(NULL)
}

# Declare data.table non-standard evaluation column names to avoid R CMD check NOTES
utils::globalVariables(c(
  "artifact_id",
  "version_id",
  "created_at",
  "n_versions",
  "latest_version_id",
  "parent_artifact_id",
  "parent_version_id",
  "child_artifact_id",
  "child_version_id",
  "artifact_path",
  "size_bytes",
  "..available_cols",
  "..partitioning",
  "."
))
