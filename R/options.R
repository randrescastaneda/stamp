# options.R — validated options API for stamp
# Uses:
# - .stamp_opts           (env) from aaa.R
# - .stamp_default_opts   (list) from aaa.R
# - st_opts_init_defaults() from aaa.R (called in .onLoad)

# ---- Validation helpers ------------------------------------------------------

#' @keywords internal
.st_opts_validate <- function(dots) {
  if (!length(dots)) return(invisible(NULL))

  known <- names(.stamp_default_opts)
  unknown <- setdiff(names(dots), known)
  if (length(unknown)) {
    cli::cli_abort("Unknown option key(s): {.field {paste(unknown, collapse = ', ')}}")
  }

  if ("meta_format" %in% names(dots)) {
    mf <- dots$meta_format
    if (!is.character(mf) || length(mf) != 1L || !mf %in% c("json", "qs2", "both")) {
      cli::cli_abort("Option {.field meta_format} must be one of {.val json}, {.val qs2}, {.val both}.")
    }
  }

  if ("versioning" %in% names(dots)) {
    vm <- dots$versioning
    if (!is.character(vm) || length(vm) != 1L || !vm %in% c("content", "timestamp", "off")) {
      cli::cli_abort("Option {.field versioning} must be one of {.val content}, {.val timestamp}, {.val off}.")
    }
  }

  if ("default_format" %in% names(dots)) {
    df <- dots$default_format
    if (!is.character(df) || length(df) != 1L) {
      cli::cli_abort("Option {.field default_format} must be a single character value.")
    }
  }
  if ("force_on_code_change" %in% names(dots)) {
    foc <- dots$force_on_code_change
    if (!is.logical(foc) || length(foc) != 1L || is.na(foc)) {
      cli::cli_abort("Option {.field force_on_code_change} must be TRUE or FALSE.")
    }
  }

  invisible(NULL)
}

# ---- Public API --------------------------------------------------------------

#' Get or set package options
#'
#' - **Setter**: `st_opts(meta_format = "both", versioning = "timestamp")`
#' - **Getter**: `st_opts(.get = TRUE)` returns a named list of all options
#' - **Single getter**: `st_opts("meta_format", .get = TRUE)` returns one value
#'
#' Valid keys (see defaults in `aaa.R`): `meta_format`, `versioning`, `code_hash`,
#' `store_file_hash`, `verify_on_load`, `default_format`, `verbose`, `timezone`,
#' `timeformat`, `usetz`.
#'
#' @param ... Named pairs for setting options; or a single character key when `.get = TRUE`.
#' @param .get Logical. If `TRUE`, performs a read instead of a write.
#' @return For setters, `invisible(NULL)`. For getters, the requested value(s).
#' @export
st_opts <- function(..., .get = FALSE) {
  args <- rlang::list2(...)

  if (.get) {
    if (!length(args)) {
      return(as.list(.stamp_opts))
    }
    if (length(args) == 1L && is.character(args[[1]]) && length(args[[1]]) == 1L) {
      key <- args[[1]]
      return(rlang::env_get(.stamp_opts, key, default = NULL))
    }
    cli::cli_abort("For getting, use {.code st_opts(.get = TRUE)} or {.code st_opts('key', .get = TRUE)}.")
  }

  if (!length(args)) return(invisible(NULL))

  .st_opts_validate(args)
  rlang::env_bind(.stamp_opts, !!!args)

  # Pretty-print changes
  kv <- paste(
    names(args),
    vapply(args, function(x) cli::format_inline("{.val {paste0(x, collapse = ' ')}}"), ""),
    sep = " = ",
    collapse = ", "
  )

  cli::cli_inform(c("v" = "stamp options updated", " " = kv))
  invisible(NULL)
}

#' Reset all options to package defaults
#' @return `invisible(NULL)`
#' @export
st_opts_reset <- function() {
  rlang::env_bind(.stamp_opts, !!!.stamp_default_opts)
  invisible(NULL)
}

#' Convenience getter (optional sugar)
#' @param key Option name or `NULL` for all
#' @return Value or list of all values
#' @export
st_opts_get <- function(key = NULL) {
  if (is.null(key)) return(as.list(.stamp_opts))
  rlang::env_get(.stamp_opts, key, default = NULL)
}
