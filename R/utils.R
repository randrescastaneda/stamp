#' Package internal state environment
#'
#' An internal environment used by the package to store lightweight
#' runtime state (for example the path to the state directory). It is
#' implemented with an `rlang` environment so values can be read and
#' updated from multiple functions without exporting mutable global
#' variables.
#'
#' This object is internal to the package and not intended for end-user
#' consumption.
#'
#' @keywords internal
.stamp_state <- rlang::env(
  state_dir = ".stamp"  # default; overridden by st_init()
)

#' Get a value from the package state environment
#'
#' Convenience wrapper to read a named value from the internal package
#' state environment created in `.stamp_state`. If the key does not
#' exist the supplied `default` value is returned.
#'
#' @param name Character scalar: name of the value to read from the
#'   state environment.
#' @param default Value to return when `name` is not present. Defaults
#'   to `NULL`.
#' @return The value stored in the state environment for `name`, or
#'   `default` when the key is absent.
#' @examples
#' # set a value and read it back
#' stamp:::st_state_set(test = 1)
#' stamp:::st_state_get("test")
#'
#' @keywords internal
st_state_get <- function(name, default = NULL) {
  if (rlang::env_has(.stamp_state, name)) rlang::env_get(.stamp_state, name) else default
}

#' Set values in the package state environment
#'
#' Bind one or more named values into the internal package state
#' environment. This is a thin wrapper around `rlang::env_bind()` that
#' returns invisibly.
#'
#' @param ... Named values to bind into the state environment.
#' @return Invisibly returns `NULL`.
#' @rdname st_state_get
st_state_set <- function(...) {
  rlang::env_bind(.stamp_state, ...)
  invisible(NULL)
}


#' Current time as UTC character
#'
#' Return the current system time converted to UTC and coerced to a
#' character string. This helper is used when storing timestamps in the
#' package state or in saved metadata.
#'
#' @return Character scalar with the current time in UTC.
#' @keywords internal
.st_now_utc <- function() {
  as.character(as.POSIXct(Sys.time(), tz = "UTC"))
}

#' Ensure directory exists
#'
#' Create `path` if it does not already exist. Uses the `fs` package
#' and will create intermediate directories when required.
#'
#' @param path Character scalar path to create.
#' @return Invisibly returns `NULL`.
#' @keywords internal
.st_dir_create <- function(path) {
  if (!fs::dir_exists(path)) fs::dir_create(path, recurse = TRUE)
}




