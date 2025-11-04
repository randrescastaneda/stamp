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
  if (length(miss)) {
    cli::cli_abort("Missing PK columns in data: {.field {miss}}.")
  }
  if (isTRUE(unique)) {
    .st_assert_unique_pk(x, pk)
  }

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
  if (is.null(sch) || !is.list(sch) || is.null(sch$pk)) {
    return(NULL)
  }
  sch
}

#' Assert that a data.frame conforms to its schema (if present)
#' @export
st_assert_pk <- function(x) {
  sch <- st_get_pk(x)
  if (is.null(sch)) {
    return(invisible(x))
  }
  miss <- setdiff(sch$pk, names(x))
  if (length(miss)) {
    cli::cli_abort("Object violates schema: missing {.field {miss}}.")
  }
  if (isTRUE(sch$unique)) {
    .st_assert_unique_pk(x, sch$pk)
  }
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
  x <- st_load(file) # st_load will reattach schema from sidecar if needed
  sch <- st_get_pk(x)
  if (is.null(sch)) {
    cli::cli_abort(
      "Artifact has no schema; use {.fn st_set_pk} / {.fn st_save(..., pk=...)}."
    )
  }

  bad <- setdiff(names(filter), sch$pk)
  if (length(bad)) {
    cli::cli_abort(
      "Filter contains non-PK keys: {.field {bad}}. PK is {.field {sch$pk}}."
    )
  }

  m <- rep(TRUE, nrow(x))
  for (k in names(filter)) {
    vals <- filter[[k]]
    m <- m & (x[[k]] %in% vals)
  }
  out <- x[m, , drop = FALSE]

  if (!is.null(select)) {
    keep_cols <- unique(c(sch$pk, select))
    miss <- setdiff(keep_cols, names(out))
    if (length(miss)) {
      cli::cli_abort("Selected columns not found: {.field {miss}}.")
    }
    out <- out[, keep_cols, drop = FALSE]
  }
  if (isTRUE(drop_attr)) {
    attr(out, "stamp_schema") <- NULL
  }
  out
}

# ---- Domain & schema helpers (lightweight, attr-based) -----------------------

# Normalize a domain spec into a list of character column names
st_domain <- function(x = NULL, keys = NULL) {
  if (is.null(x) && is.null(keys)) {
    cli::cli_abort(
      "Provide either a data.frame (.arg x) or explicit keys (.arg keys)."
    )
  }
  if (!is.null(keys)) {
    keys <- as.character(keys)
    if (!length(keys)) {
      cli::cli_abort("Domain keys must be a non-empty character vector.")
    }
    return(list(keys = unique(keys)))
  }
  if (!is.data.frame(x)) {
    cli::cli_abort(".arg x must be a data.frame when keys=NULL.")
  }
  # Heuristic: use attributes if present; otherwise, try common keys
  dom <- attr(x, "stamp_domain", exact = TRUE)
  if (is.list(dom) && length(dom$keys)) {
    return(dom)
  }
  common <- c("country", "year", "reporting_level")
  present <- intersect(common, names(x))
  list(keys = unique(present))
}

# Attach domain/schema to a data.frame (non-destructive)
st_with_meta <- function(x, domain = NULL, schema = NULL) {
  stopifnot(is.data.frame(x))
  if (!is.null(domain)) {
    attr(x, "stamp_domain") <- st_domain(keys = domain$keys)
  }
  if (!is.null(schema)) {
    attr(x, "stamp_schema") <- schema
  }
  x
}

# Retrieve domain keys from a data.frame or sidecar-like list
st_domain_keys <- function(x_or_meta) {
  dom <- if (is.data.frame(x_or_meta)) {
    attr(x_or_meta, "stamp_domain", exact = TRUE)
  } else if (is.list(x_or_meta)) {
    x_or_meta$domain %||% x_or_meta$stamp_domain %||% NULL
  } else {
    NULL
  }
  if (is.list(dom) && length(dom$keys)) dom$keys else character(0)
}

# Convenience: build a minimal schema from a data.frame (column types + nrow)
st_schema <- function(x) {
  stopifnot(is.data.frame(x))
  list(
    cols = setNames(
      vapply(x, function(col) class(col)[1L], character(1L)),
      names(x)
    ),
    nrow = nrow(x)
  )
}

# Save with domain/schema via metadata, using st_save() only
# Example usage:
#   dom <- st_domain(keys = c("country","year","reporting_level"))
#   sch <- st_schema(df)
#   st_save(df, path, metadata = list(domain = dom, schema = sch), code = my_code)
st_save_with_meta <- function(x, path, domain = NULL, schema = NULL, ...) {
  md <- list()
  if (!is.null(domain)) {
    md$domain <- st_domain(keys = domain$keys)
  }
  if (!is.null(schema)) {
    md$schema <- schema
  }
  st_save(x, path, metadata = md, ...)
}

# Query utility: filter a loaded data.frame by domain values (no partitions)
# filters: named list, e.g. list(country = "PER", year = 2019, reporting_level = c("national","urban"))
st_query <- function(df, filters = list(), strict = TRUE) {
  stopifnot(is.data.frame(df))
  if (!length(filters)) {
    return(df)
  }
  # Determine applicable keys
  keys <- st_domain_keys(df)
  if (!length(keys)) {
    keys <- intersect(names(filters), names(df))
  } # fall back

  # Optionally enforce that requested filters are valid keys
  if (isTRUE(strict)) {
    unknown <- setdiff(names(filters), names(df))
    if (length(unknown)) {
      cli::cli_abort(
        "Unknown filter columns (not in data): {paste(unknown, collapse = ', ')}"
      )
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
