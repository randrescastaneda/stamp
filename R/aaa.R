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

  path_abs <- tryCatch(
    as.character(fs::path_abs(path)),
    error = function(e) as.character(path)
  )
  root_abs <- as.character(cfg$root)

  # Check if path starts with the root (case-insensitive on Windows)
  if (.Platform$OS.type == "windows") {
    path_norm <- tolower(normalizePath(
      path_abs,
      winslash = "/",
      mustWork = FALSE
    ))
    root_norm <- tolower(normalizePath(
      root_abs,
      winslash = "/",
      mustWork = FALSE
    ))
  } else {
    path_norm <- path_abs
    root_norm <- root_abs
  }

  # Path should start with root directory
  startsWith(path_norm, root_norm)
}

#' Detect which alias a path belongs to (internal)
#' @keywords internal
.st_detect_alias_from_path <- function(path) {
  # Find which registered alias's root contains this path
  # Returns the alias name, or NULL if no match found
  
  path_abs <- tryCatch(
    as.character(fs::path_abs(path)),
    error = function(e) as.character(path)
  )
  
  # Normalize path for comparison
  if (.Platform$OS.type == "windows") {
    path_norm <- tolower(normalizePath(
      path_abs,
      winslash = "/",
      mustWork = FALSE
    ))
  } else {
    path_norm <- path_abs
  }
  
  # Check all registered aliases
  all_aliases <- rlang::env_names(.stamp_aliases)
  
  # Track matches with their root path lengths (to find most specific match)
  matches <- list()
  
  for (alias_name in all_aliases) {
    cfg <- rlang::env_get(.stamp_aliases, alias_name, default = NULL)
    if (is.null(cfg)) next
    
    root_abs <- as.character(cfg$root)
    if (.Platform$OS.type == "windows") {
      root_norm <- tolower(normalizePath(
        root_abs,
        winslash = "/",
        mustWork = FALSE
      ))
    } else {
      root_norm <- root_abs
    }
    
    # Check if path is under this root
    if (startsWith(path_norm, root_norm)) {
      matches[[alias_name]] <- nchar(root_norm)
    }
  }
  
  # If no matches, return NULL
  if (length(matches) == 0) {
    return(NULL)
  }
  
  # Return the most specific match (longest root path)
  # This handles nested roots correctly
  best_match <- names(matches)[which.max(unlist(matches))]
  return(best_match)
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
