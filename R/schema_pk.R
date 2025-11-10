# ---- Primary-key (pk) metadata: declare, inspect, add/repair ---------------

#' Normalize a primary-key specification
#'
#' Normalize and validate a primary-key (pk) specification. The canonical
#' representation is a list with element `keys` containing a character vector
#' of column names. When `x` (a data.frame) is provided and `validate = TRUE`
#' the function will check that the columns exist (and optionally that they
#' uniquely identify rows).
#'
#' @param x Optional data.frame to validate the keys against. If `NULL`, only
#'   the `keys` vector is normalized.
#' @param keys Character vector of column names comprising the primary key.
#' @param validate Logical; when `TRUE` validate that columns exist (and
#'   uniqueness if `check_unique` is `TRUE`).
#' @param check_unique Logical; when `TRUE` assert that `keys` uniquely
#'   identify rows in `x` (only checked when `x` is provided).
#' @return A list with element `keys` containing the canonical character vector.
#' @export
st_pk <- function(x = NULL, keys, validate = TRUE, check_unique = FALSE) {
  stopifnot(is.character(keys), length(keys) >= 1L, all(nzchar(keys)))
  keys <- unique(as.character(keys))

  if (!is.null(x)) {
    if (!is.data.frame(x)) {
      cli::cli_abort(".arg x must be a data.frame when provided.")
    }
    missing <- setdiff(keys, names(x))
    if (validate && length(missing)) {
      cli::cli_abort(
        "pk refers to columns not in data: {paste(missing, collapse=', ')}"
      )
    }
    if (validate && isTRUE(check_unique)) {
      dup <- any(duplicated(x[keys]))
      if (dup) {
        cli::cli_abort("pk is not unique over the provided data.")
      }
    }
  }
  list(keys = keys)
}

#' Attach primary-key metadata to a data.frame (in-memory)
#'
#' Attach primary-key metadata to a data.frame by setting an attribute
#' `stamp_pk` with the normalized pk list returned by [st_pk()]. This does
#' not modify on-disk sidecars; it is an in-memory convenience.
#'
#' @param x Data.frame to annotate.
#' @param keys Character vector of column names making the primary key.
#' @return The input data.frame with attribute `stamp_pk` set.
#' @export
st_with_pk <- function(x, keys) {
  stopifnot(is.data.frame(x))
  attr(x, "stamp_pk") <- st_pk(x, keys = keys, validate = FALSE)
  x
}

#' Read primary-key keys from a data.frame or sidecar/meta list
#'
#' Extract the primary-key column names from either an in-memory data.frame
#' (via the `stamp_pk` attribute) or from a sidecar/meta list (a previously
#' recorded `pk` element). Returns an empty character vector when none is found.
#'
#' @param x_or_meta Either a data.frame (with attribute `stamp_pk`) or a
#'   sidecar/meta list as returned by [st_read_sidecar()].
#' @return Character vector of primary-key column names (may be length 0).
#' @export
st_get_pk <- function(x_or_meta) {
  pk <- if (is.data.frame(x_or_meta)) {
    attr(x_or_meta, "stamp_pk", exact = TRUE)
  } else if (is.list(x_or_meta)) {
    # prefer explicit pk, fall back to legacy fields if you ever add them later
    x_or_meta$pk %||% NULL
  } else {
    NULL
  }

  if (is.list(pk) && length(pk$keys)) pk$keys else character(0)
}

#' Inspect primary-key of an artifact from its sidecar
#'
#' Read the sidecar for `path` and return the recorded primary-key column
#' names. If no sidecar or pk information is present, returns `character(0)`.
#'
#' @param path Path to the artifact file.
#' @return Character vector of primary-key column names (may be length 0).
#' @export
st_inspect_pk <- function(path) {
  meta <- tryCatch(st_read_sidecar(path), error = function(e) NULL)
  if (is.null(meta)) {
    return(character(0))
  }
  st_get_pk(meta)
}

#' Add or repair primary-key metadata in an artifact sidecar
#'
#' Update the artifact sidecar for `path` to include primary-key metadata
#' (`pk` element). The artifact file itself is not rewritten. By default the
#' function validates the provided keys against the current on-disk artifact
#' (and optionally checks uniqueness). Use `validate = FALSE` to skip
#' validation and perform a pure metadata update.
#'
#' @param path Path to the artifact file whose sidecar will be updated.
#' @param keys Character vector of column names to set as the primary key.
#' @param validate Logical; when `TRUE` validate keys against the on-disk data.
#' @param check_unique Logical; when `TRUE` assert that the keys uniquely
#'   identify rows in the on-disk data (if `validate = TRUE`).
#' @return Invisibly returns the character vector of keys recorded.
#' @export
st_add_pk <- function(path, keys, validate = TRUE, check_unique = FALSE) {
  path <- as.character(path)
  if (!fs::file_exists(path)) {
    cli::cli_abort("Artifact not found: {.file {path}}")
  }

  # Optionally validate against the *current* on-disk content
  if (isTRUE(validate)) {
    # Temporarily disable PK requirement to allow loading artifacts without PK metadata
    old_require_pk <- st_opts("require_pk_on_load", .get = TRUE)
    on.exit(st_opts("require_pk_on_load" = old_require_pk), add = TRUE)
    st_opts("require_pk_on_load" = FALSE)

    obj <- st_load(path) # uses your existing readers
    # ensure columns exist (and uniqueness if requested)
    invisible(st_pk(
      obj,
      keys = keys,
      validate = TRUE,
      check_unique = check_unique
    ))
  }

  meta <- tryCatch(
    st_read_sidecar(path),
    error = function(e) list(),
    finally = NULL
  )
  if (!is.list(meta)) {
    meta <- list()
  }
  meta$pk <- list(keys = unique(as.character(keys)))

  .st_write_sidecar(path, meta)
  cli::cli_inform(c(
    "v" = "Recorded primary key for {.file {path}} --> {paste(meta$pk$keys, collapse=', ')}"
  ))
  invisible(meta$pk$keys)
}

#' Filter a data.frame by primary-key values (or arbitrary columns)
#'
#' Convenience helper to subset a data.frame by a set of named values. The
#' `filters` argument is a named list mapping column names to allowed values
#' (vector). When `strict = TRUE`, unknown filter columns raise an error.
#'
#' @param df A data.frame to filter.
#' @param filters Named list of filtering values, e.g. `list(country = "PER")`.
#' @param strict Logical; when `TRUE` unknown filter columns cause an error.
#' @return A subsetted data.frame (same columns as `df`).
#' @export
st_filter <- function(df, filters = list(), strict = TRUE) {
  stopifnot(is.data.frame(df))
  if (!length(filters)) {
    return(df)
  }

  if (isTRUE(strict)) {
    unknown <- setdiff(names(filters), names(df))
    if (length(unknown)) {
      cli::cli_abort("Unknown filter columns: {paste(unknown, collapse=', ')}")
    }
  }

  out <- df
  for (nm in names(filters)) {
    if (!nm %in% names(out)) {
      next
    }
    val <- filters[[nm]]
    out <- out[out[[nm]] %in% val, , drop = FALSE]
  }
  out
}

# ---- Tiny helpers used by st_save() ------------------------------------------

# Validate & attach pk (and optional domain) to a data.frame
# unique=TRUE -> check uniqueness; errors if violated
st_set_pk <- function(x, pk, domain = NULL, unique = TRUE) {
  stopifnot(is.data.frame(x))
  # Validate existence (+ uniqueness if requested)
  invisible(st_pk(x, keys = pk, validate = TRUE, check_unique = isTRUE(unique)))
  attr(x, "stamp_pk") <- list(keys = unique(as.character(pk)))
  if (!is.null(domain)) {
    attr(x, "stamp_domain") <- as.character(domain)
  }
  x
}

# If a pk attr exists, verify columns still exist; otherwise no-op
st_assert_pk <- function(x) {
  stopifnot(is.data.frame(x))
  pk <- attr(x, "stamp_pk", exact = TRUE)
  if (is.null(pk) || !length(pk$keys)) {
    return(invisible(TRUE))
  }
  missing <- setdiff(pk$keys, names(x))
  if (length(missing)) {
    cli::cli_abort(
      "Recorded pk refers to missing columns: {paste(missing, collapse=', ')}"
    )
  }
  invisible(TRUE)
}
