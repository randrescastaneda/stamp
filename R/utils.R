# utils.R — small internal helpers (no global state defined here)

#' Current time as UTC ISO-8601 (Z) string with microsecond precision
#'
#' @return Character scalar like "2025-10-30T15:42:07.123456Z"
#' @keywords internal
.st_now_utc <- function() {
  # ISO 8601 with microsecond precision and trailing 'Z' for UTC
  # %OS6 gives fractional seconds with 6 digits (microseconds)
  # This ensures proper ordering even for versions saved in rapid succession
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
}

#' Ensure directory exists (idempotent)
#'
#' Create `path` if it does not already exist. Intermediate directories
#' are created as needed.
#'
#' @param path Character scalar path to a directory.
#' @return Invisibly returns `NULL`.
#' @keywords internal
.st_dir_create <- function(path) {
  if (!fs::dir_exists(path)) {
    fs::dir_create(path, recurse = TRUE)
  }
  invisible(NULL)
}
