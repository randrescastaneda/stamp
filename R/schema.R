# ---- Schema / keys (no partitioning) -----------------------------------------

#' Attach a primary-key schema to a data.frame (and return it)
#' @param x data.frame
#' @param pk character vector of column names that form the primary key
#' @param domain character scalar or vector; free-form labels for the dataset
#' @param unique logical; if TRUE, assert uniqueness of pk combinations
#' @return x with attr(x, "stamp_schema") set
#' @export
st_set_pk <- function(x, pk, domain = NULL, unique = TRUE) {
  stopifnot(is.data.frame(x), is.character(pk), length(pk) >= 1L)
  miss <- setdiff(pk, names(x))
  if (length(miss)) cli::cli_abort("Missing PK columns in data: {.field {miss}}.")
  if (isTRUE(unique)) .st_assert_unique_pk(x, pk)

  if (!is.null(domain)) {
    if (!is.character(domain)) {
      cli::cli_abort("{.arg domain} must be character (scalar or vector).")
    }
  }

  schema <- list(domain = domain, pk = pk, unique = isTRUE(unique))
  attr(x, "stamp_schema") <- schema
  x
}

#' Get the primary-key schema from a data.frame (if any)
#' @export
st_get_pk <- function(x) {
  sch <- attr(x, "stamp_schema", exact = TRUE)
  if (is.null(sch) || !is.list(sch) || is.null(sch$pk)) return(NULL)
  sch
}

#' Assert that a data.frame conforms to its schema (if present)
#' @export
st_assert_pk <- function(x) {
  sch <- st_get_pk(x)
  if (is.null(sch)) return(invisible(x))
  miss <- setdiff(sch$pk, names(x))
  if (length(miss)) cli::cli_abort("Object violates schema: missing {.field {miss}}.")
  if (isTRUE(sch$unique)) .st_assert_unique_pk(x, sch$pk)
  invisible(x)
}

.st_assert_unique_pk <- function(x, pk) {
  # Use data.table if available; otherwise a base-R fallback
  if (requireNamespace("data.table", quietly = TRUE)) {
    dt <- data.table::as.data.table(x)
    idx <- dt[, .N, keyby = ..pk]
    if (any(idx$N > 1L)) {
      bad <- idx[N > 1L][1L]
      cli::cli_abort(c(
        "Object violates unique PK constraint.",
        "i" = "First duplicate: {.val {as.list(bad[, ..pk])}}"
      ))
    }
  } else {
    # base fallback
    key <- do.call(paste, c(x[pk], sep = "\r"))
    dup <- duplicated(key)
    if (any(dup)) {
      first <- which(dup)[1L]
      cli::cli_abort(c(
        "Object violates unique PK constraint.",
        "i" = "First duplicate row index: {first}"
      ))
    }
  }
  invisible(NULL)
}

# ---- Query helper ------------------------------------------------------------

#' Query a schema-tagged table by primary-key values (no partitioning)
#' @param file artifact path (whole table)
#' @param filter named list like list(country="ARG", year=2019, reporting_level=c("national","urban"))
#' @param select optional character vector of columns to return (in addition to PK)
#' @param drop_attr logical; drop schema attribute on the returned subset
#' @return data.frame subset
#' @export
st_query_table <- function(file, filter, select = NULL, drop_attr = FALSE) {
  stopifnot(is.list(filter), length(filter) >= 1L)
  x <- st_load(file)  # st_load will reattach schema from sidecar if needed
  sch <- st_get_pk(x)
  if (is.null(sch)) cli::cli_abort("Artifact has no schema; use {.fn st_set_pk} / {.fn st_save(..., pk=...)}.")

  bad <- setdiff(names(filter), sch$pk)
  if (length(bad)) cli::cli_abort("Filter contains non-PK keys: {.field {bad}}. PK is {.field {sch$pk}}.")

  m <- rep(TRUE, nrow(x))
  for (k in names(filter)) {
    vals <- filter[[k]]
    m <- m & (x[[k]] %in% vals)
  }
  out <- x[m, , drop = FALSE]

  if (!is.null(select)) {
    keep_cols <- unique(c(sch$pk, select))
    miss <- setdiff(keep_cols, names(out))
    if (length(miss)) cli::cli_abort("Selected columns not found: {.field {miss}}.")
    out <- out[, keep_cols, drop = FALSE]
  }
  if (isTRUE(drop_attr)) attr(out, "stamp_schema") <- NULL
  out
}
