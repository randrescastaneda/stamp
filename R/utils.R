# utils.R — small internal helpers (no global state defined here)

#' Current time as UTC ISO-8601 (Z) string
#'
#' @return Character scalar like "2025-10-30T15:42:07Z"
#' @keywords internal
.st_now_utc <- function() {
  # ISO 8601 with trailing 'Z' for UTC; stable for lexicographic sort
  strftime(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
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
  if (!fs::dir_exists(path)) fs::dir_create(path, recurse = TRUE)
  invisible(NULL)
}
