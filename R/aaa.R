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
.st_extmap_env  <- rlang::env()

# Options store used by st_opts() (values populated at load time)
.stamp_opts     <- rlang::env()

# Lightweight package state (keeps paths, etc.)
.stamp_state    <- rlang::env(
  state_dir = ".stamp"  # default; can be overridden via st_state_set()
)

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
# Internal option defaults (single source of truth for st_opts_init_defaults())
# Note: st_opts() itself lives elsewhere; these are the defaults it consumes.
# ------------------------------------------------------------------------------

.stamp_default_opts <- list(
  # Sidecar & metadata
  meta_format          = "json",       # "json" | "qs2" | "both"

  # Versioning
  versioning           = "content",    # "content" | "timestamp" | "off"
  force_on_code_change = TRUE,  # if code hash differs, write a new version
  retain_versions      = Inf,    # keep all versions by default


  # Hashing toggles
  code_hash       = TRUE,         # compute code hash when code= is supplied
  store_file_hash = FALSE,        # compute file hash at save (extra I/O)
  verify_on_load  = FALSE,        # verify file hash on load if available

  # Usability / misc (mirrors; used as we adopt them)
  default_format  = "qs2",        # resolved writer key for auto-inference
  verbose         = TRUE,         # future-use for chatty messages
  timezone        = (Sys.timezone() %||% "UTC"),
  timeformat      = "%Y%m%d%H%M%S",
  usetz           = FALSE
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
