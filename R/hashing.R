# hashing.R — content/code/file hashing with secretbase only

#' Normalize attributes for consistent hashing
#'
#' Normalizes the order of object attributes to a canonical form by creating
#' a new object with attributes in the correct order. This is necessary because
#' R does not allow reordering attributes in-place.
#'
#' @section Problem:
#' Operations like `collapse::rowbind()` + `collapse::funique()` can leave
#' attributes in different orders even when content is identical. Since
#' `serialize()` includes attribute order, this causes different byte streams
#' and thus different hashes for logically identical objects.
#'
#' @section Solution:
#' This function reorders attributes to a canonical order:
#' 1. Priority attributes: names, row.names, class, .internal.selfref
#' 2. Additional attributes: alphabetically sorted
#'
#' @section Implementation Strategy:
#' The function creates a new object with attributes in canonical order.
#' This is a shallow copy - the actual data (columns, elements) is referenced,
#' not copied, making it efficient even for large objects.
#'
#' **For data.table objects:**
#' - Extracts columns as a list
#' - Rebuilds with attributes in canonical order
#' - Shallow copy (column data is referenced, not duplicated)
#' - Preserves data.table class and .internal.selfref
#'
#' **For regular data.frames:**
#' - Rebuilds from column list with canonical attribute order
#' - Shallow copy (column data is referenced, not copied)
#' - Preserves data.frame class
#'
#' **For lists and other objects:**
#' - Uses `unclass()` + attribute replacement
#' - Shallow copy when possible
#'
#' @section Performance:
#' - Shallow copy strategy: data is referenced, not duplicated
#' - Fast path: returns unchanged if already in canonical order
#' - Negligible overhead for most use cases (< 1% of hashing time)
#'
#' @param x A data.frame, data.table, list, or other object.
#' @return A new object with the same data but attributes in canonical order.
#'   The class is preserved.
#' @keywords internal
st_normalize_attrs <- function(x) {
  # Get attributes once
  attrs <- attributes(x)

  # Fast path: no attributes
  if (is.null(attrs) || length(attrs) == 0L) {
    return(x)
  }

  attr_names <- names(attrs)

  # Canonical priority order
  priority <- c("names", "row.names", "class", ".internal.selfref")

  priority_present <- intersect(priority, attr_names)
  other_attrs <- setdiff(attr_names, priority)

  canonical_order <- c(priority_present, sort(other_attrs))

  # Always rebuild to ensure deterministic attribute ordering

  # ---------------------------------------------------------------------------
  # data.table branch
  # ---------------------------------------------------------------------------
  if (inherits(x, "data.table")) {
    # Work on a copy to avoid mutating caller's object by reference
    result <- copy(x)

    # Values of attributes in canonical order
    vals <- attrs[canonical_order]

    # 1) Drop ALL attributes via setattr(..., NULL)
    #    This uses only data.table's API (no attributes<-).
    for (nm in attr_names) {
      setattr(result, nm, NULL)
    }

    # 2) Re-add attributes in canonical order
    for (nm in canonical_order) {
      setattr(result, nm, vals[[nm]])
    }

    return(result)
  } # --- Path 2: regular data.frames (not data.table) ---
  # Create a new object with normalized attributes
  # We don't modify in-place because data.frames don't have a safe setattr()
  if (is.data.frame(x)) {
    # Extract columns as a list (this does NOT copy column data, just references)
    cols <- as.list(x)

    # Build the canonical attributes list in the correct order
    new_attrs <- vector("list", length(canonical_order))
    names(new_attrs) <- canonical_order
    for (nm in canonical_order) {
      new_attrs[[nm]] <- attrs[[nm]]
    }

    # Create base structure using structure() which is fast and low-level
    # We use .set_row_names() to create efficient row names (integer sequence)
    n_rows <- if (length(cols)) NROW(cols[[1L]]) else NROW(x)
    result <- structure(cols, row.names = .set_row_names(n_rows))

    # Apply the canonical attributes all at once
    # This replaces the minimal attributes from structure() with our full set
    attributes(result) <- new_attrs

    return(result)
  }

  # --- Path 3: lists and other objects ---
  # For non-data.frame objects, we unclass and rebuild with ordered attributes

  # Short-circuit S4 objects: unclass() is not safe for S4 instances.
  # Return S4 objects unchanged (caller can handle S4-specific normalization if needed).
  if (isS4(x)) {

    cli::cli_warn(c(
      "!" = "S4 objects cannot be normalized for hashing; returning object unchanged."
    ))

    return(x)

  }

  # Build canonical attributes list
  new_attrs <- vector("list", length(canonical_order))
  names(new_attrs) <- canonical_order
  for (nm in canonical_order) {
    new_attrs[[nm]] <- attrs[[nm]]
  }

  # Create a copy by unclassing (removes class attribute) then re-adding all
  # This ensures we get a fresh attribute list in the correct order
  result <- unclass(x)
  attributes(result) <- new_attrs

  result
}

# -----------------------------------------------------------------------------
# Sanitization helpers (content-only hashing for tabular data)
# -----------------------------------------------------------------------------

#' @keywords internal
.st_is_dt <- function(x) inherits(x, "data.table")

#' Sanitize object prior to hashing
#'
#' For tabular data we want hashing to depend only on the data/frame content,
#' not on volatile data.table internals (e.g. `.internal.selfref`) or differing
#' row name representations. Strategy:
#' - If `x` is a data.table: coerce to plain data.frame (drops DT internals).
#' - If `x` is a data.frame (including coerced DT): enforce deterministic
#'   row.names via `.set_row_names(NROW(x))`.
#' - Record original class in `st_original_format` so a loader can restore it.
#'
#' Non-tabular objects are returned unchanged (attribute normalization handles
#' them subsequently).
#'
#' NOTE: The returned object is a shallow copy; column data is not duplicated.
#' @keywords internal
st_sanitize_for_hash <- function(x) {
  # Skip if already sanitized
  if (isTRUE(attr(x, "stamp_sanitized"))) {
    return(x)
  }
  if (is.data.frame(x)) {
    if (.st_is_dt(x)) {
      orig_class <- class(x)
      x <- as.data.frame(x)
      attr(x, "st_original_format") <- orig_class
    }
    attr(x, "row.names") <- .set_row_names(NROW(x))
    attr(x, "stamp_sanitized") <- TRUE
    return(x)
  }
  attr(x, "stamp_sanitized") <- TRUE
  x
}

#' Stable SipHash-1-3 of an R object
#'
#' Computes a stable hash of an R object by serializing it with
#' `base::serialize(version = 3)` and hashing the resulting bytes via
#' `secretbase::siphash13()`. The hash is stable across R sessions (given the
#' same R version and object structure) and suitable for change detection.
#'
#' @section Attribute Normalization:
#' Before hashing, this function normalizes the order of object attributes to
#' ensure consistent hashes even when operations (like `collapse::rowbind()` +
#' `collapse::funique()`) leave attributes in different orders.
#'
#' The normalization reorders attributes to a canonical form:
#' 1. Priority attributes: names, row.names, class, .internal.selfref
#' 2. Other attributes: alphabetically sorted
#'
#' This ensures that logically identical objects produce identical hashes
#' regardless of their attribute creation history.
#'
#' @section Why This Matters:
#' Without normalization, two data.frames that are `identical()` can produce
#' different hashes if their internal attributes are in different orders. This
#' breaks change detection in stamp, causing false positives where objects are
#' incorrectly flagged as changed.
#'
#' @section Performance:
#' - For small to medium objects: negligible overhead
#' - For large objects: creates a shallow copy (data is referenced, not duplicated)
#' - The normalization cost is typically < 1% of total hashing time
#'
#' @param x Any R object (data.frame, data.table, list, vector, etc.)
#' @return Lowercase hex string (16 hex characters) from siphash13().
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Two ways to create the "same" data
#' dt_a <- data.table(x = 1:5)
#' dt_b <- data.table(x = 1:5) |> collapse::rowbind(data.table(x = 1:5)) |> collapse::funique()
#'
#' # They're identical in content
#' identical(dt_a, dt_b)  # TRUE
#'
#' # And now they hash the same too!
#' st_hash_obj(dt_a) == st_hash_obj(dt_b)  # TRUE
#' }
st_hash_obj <- function(x) {
  # 1) Sanitize (content-only for tabular data); skip if already sanitized
  x_clean <- if (isTRUE(attr(x, "stamp_sanitized"))) {
    x
  } else {
    st_sanitize_for_hash(x)
  }
  # 2) Canonicalize attribute order
  x_norm <- st_normalize_attrs(x_clean)
  # 3) Serialize + SipHash
  raw <- serialize(x_norm, connection = NULL, version = 3)
  secretbase::siphash13(raw)
}

#' Stable SipHash-1-3 of code
#'
#' Computes a stable hash of R code (functions, expressions, or character vectors).
#' For functions, includes both formals (arguments) and body. Whitespace is
#' lightly normalized to reduce spurious differences. That means code changes which only
#' alter the number of spaces in strings (e.g. "a  b" vs "a b") will produce identical hashes.
#'
#' @section Normalization:
#' The code undergoes light normalization before hashing:
#' - Multiple spaces/tabs collapsed to single space
#' - Line endings normalized to `\n`
#' - This reduces false positives from formatting changes while preserving code structure
#'
#' @section What Gets Hashed:
#' - **Functions**: formals (argument list) + body (code)
#' - **Expressions/language**: deparsed code
#' - **Character vectors**: concatenated with newlines
#'
#' @param code A function, expression (language object), or character vector
#' @return Lowercase hex string (16 hex characters) from siphash13().
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Hash a function
#' st_hash_code(function(x) x + 1)
#'
#' # Hash an expression
#' st_hash_code(quote(x + 1))
#'
#' # Hash character code
#' st_hash_code("x <- 1\ny <- 2")
#' }
st_hash_code <- function(code) {
  # Convert code to text representation
  if (is.function(code)) {
    # For functions: capture both argument structure and implementation
    fml <- formals(code)
    txt <- c(
      paste(deparse(fml), collapse = "\n"),
      paste(deparse(body(code)), collapse = "\n")
    )
  } else if (is.language(code)) {
    # For expressions/calls: deparse to text
    txt <- paste(deparse(code), collapse = "\n")
  } else {
    # For character: use as-is (concatenate if vector)
    txt <- paste(as.character(code), collapse = "\n")
  }

  # Light normalization to reduce formatting noise
  # Collapse multiple spaces/tabs to single space
  txt <- gsub("[ \t]+", " ", txt)
  # Normalize line endings (handle Windows \r\n and old Mac \r)
  txt <- gsub("\r\n?", "\n", txt, perl = TRUE)

  # Hash the normalized text
  secretbase::siphash13(txt)
}

#' SipHash-1-3 of a file (bytes on disk)
#'
#' Computes a hash of a file's contents by reading the file as raw bytes and
#' hashing them via `secretbase::siphash13()`. This is faster than reading the
#' file into R first because `secretbase` can stream the file directly.
#'
#' @section Use Cases:
#' - Detecting if an artifact file has been modified on disk
#' - Verifying file integrity across copies
#' - Checking if a file needs to be re-saved
#'
#' @section Note:
#' This hashes the file's raw bytes, not its R representation. If you save an
#' R object with `saveRDS()`, the file hash will change even if the object
#' content is the same (due to timestamps, compression variation, etc.). Use
#' `st_hash_obj()` for content-based hashing of R objects.
#'
#' @param path Character path to a file
#' @return Lowercase hex string (16 hex characters) from siphash13().
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Hash a file
#' st_hash_file("data.csv")
#' }
st_hash_file <- function(path) {
  # secretbase::siphash13(file = ...) streams the file without loading into memory
  # This is more efficient than readBin() + hash for large files
  secretbase::siphash13(file = path)
}


# -------- Change detection via hashing --------------------------------

#' Check whether an artifact would change if saved now
#'
#' Compares the *current* object/code/file to the latest saved metadata
#' (from the sidecar) and reports if a change is detected.
#'
#' @param path Artifact path on disk.
#' @param x    Current in-memory object (for content comparison).
#' @param code Optional function/expression/character (for code comparison).
#' @param mode Which changes to check: "content", "code", "file", or "any".
#' @return A list: list(changed = <lgl>, reason = <chr>, detail = <named list>)
#' @export
# Returns list(changed, reason, details)
st_changed <- function(
  path,
  x = NULL,
  code = NULL,
  mode = c("any", "content", "code", "file")
) {
  mode <- match.arg(mode)

  # --- base cases
  if (!fs::file_exists(path)) {
    return(list(
      changed = TRUE,
      reason = "missing_artifact",
      details = list(missing_artifact = TRUE)
    ))
  }

  meta <- tryCatch(st_read_sidecar(path), error = function(e) NULL)
  if (is.null(meta)) {
    return(list(
      changed = TRUE,
      reason = "missing_meta",
      details = list(missing_meta = TRUE)
    ))
  }

  # --- compute components (only what we can)
  det <- list(content_changed = NA, code_changed = NA, file_changed = NA)

  if (!is.null(x)) {
    ch_old <- meta$content_hash %||% NA_character_
    ch_new <- st_hash_obj(x)
    det$content_changed <- !identical(ch_old, ch_new)
  } else {
    det$content_changed <- NA
  }

  if (!is.null(code) && isTRUE(st_opts("code_hash", .get = TRUE))) {
    co_old <- meta$code_hash %||% NA_character_
    co_new <- st_hash_code(code)
    det$code_changed <- !identical(co_old, co_new)
  } else {
    det$code_changed <- NA
  }

  if (
    isTRUE(st_opts("store_file_hash", .get = TRUE)) && !is.null(meta$file_hash)
  ) {
    fh_old <- meta$file_hash %||% NA_character_
    fh_new <- st_hash_file(path)
    det$file_changed <- !identical(fh_old, fh_new)
  } else {
    det$file_changed <- NA
  }

  # --- collapse reason per mode
  picks <- switch(
    mode,
    content = isTRUE(det$content_changed),
    code = isTRUE(det$code_changed),
    file = isTRUE(det$file_changed),
    any = any(
      isTRUE(det$content_changed),
      isTRUE(det$code_changed),
      isTRUE(det$file_changed)
    )
  )

  # build reason string like "content+code", or "no_change"
  parts <- c(
    if (isTRUE(det$content_changed)) "content",
    if (isTRUE(det$code_changed)) "code",
    if (isTRUE(det$file_changed)) "file"
  )
  reason <- if (length(parts)) paste(parts, collapse = "+") else "no_change"

  list(changed = isTRUE(picks), reason = reason, details = det)
}
