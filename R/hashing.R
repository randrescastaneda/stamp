# hashing.R — content/code/file hashing with secretbase only

#' Normalize attributes for consistent hashing (copy-based)
#'
#' Creates a normalized copy of an object with attributes in canonical order.
#' This ensures consistent serialization and hashing regardless of the order
#' attributes were originally set.
#'
#' @section Problem:
#' Operations like `collapse::rowbind()` + `collapse::funique()` can leave
#' attributes in different orders even when content is identical. Since
#' `serialize()` includes attribute order, this causes different byte streams
#' and thus different hashes for logically identical objects.
#'
#' @section Solution:
#' This function rebuilds the object with attributes in a canonical order:
#' 1. Priority attributes: names, row.names, class, .internal.selfref
#' 2. Additional attributes: alphabetically sorted
#'
#' @section Implementation Notes:
#' - For data.frames/data.tables: Rebuilds from column list to avoid copying
#'   large column data (columns are referenced, not copied)
#' - For lists/other objects: Uses `unclass()` + attribute replacement
#' - Does NOT mutate the original object (returns a new object)
#'
#' @param x A data.frame, data.table, list, or other object.
#' @return A normalized copy of the object with attributes in canonical order.
#' @keywords internal
#' @seealso [st_normalize_attrs_inplace()] for in-place normalization of data.tables
st_normalize_attrs <- function(x) {
  attrs <- attributes(x)

  # Fast path: no attributes to normalize
  if (is.null(attrs) || length(attrs) == 0L) {
    return(x)
  }

  attr_names <- names(attrs)

  # Define canonical priority order for common R object attributes
  # These are ordered to match the most "natural" structure and ensure
  # consistency across different object creation paths
  priority <- c("names", "row.names", "class", ".internal.selfref")

  # Separate attributes into priority (fixed order) and others (alphabetical)
  priority_present <- intersect(priority, attr_names)
  other_attrs <- setdiff(attr_names, priority)

  # Canonical order: priority items in specified order, then others alphabetically
  canonical_order <- c(priority_present, sort(other_attrs))

  # Strategy: Build a fresh object with attributes in canonical order
  # We avoid full deep copies of data; instead we reference existing columns/elements

  # --- Path 1: data.frames and data.tables ---
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
    # Both data.table and data.frame paths use the same base structure
    result <- structure(cols, row.names = .set_row_names(length(cols[[1L]])))

    # Apply the canonical attributes all at once
    # This replaces the minimal attributes from structure() with our full set
    attributes(result) <- new_attrs

    return(result)
  }

  # --- Path 2: lists and other objects ---
  # For non-data.frame objects, we unclass and rebuild with ordered attributes

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

#' Normalize attributes for data.tables in-place
#'
#' Mutates a data.table object to reorder its attributes in canonical order.
#' This is more efficient than creating a copy for large data.tables, and uses
#' `data.table::setattr()` to ensure data.table internal consistency is maintained.
#'
#' @section Why in-place for data.table only:
#' - data.table provides `setattr()` which is designed for safe in-place
#'   attribute modification without breaking internal references
#' - data.frames don't have an equivalent safe in-place mechanism
#' - For data.tables, in-place is faster and more memory-efficient
#'
#' @section How it works:
#' The challenge: R's `setattr()` or `attr<-()` don't let you reorder existing
#' attributes; you can only set values. To reorder, we:
#' 1. Save all current attributes
#' 2. Remove all attributes (sets to NULL, but doesn't break data.table)
#' 3. Use `data.table::setattr()` to re-add them in canonical order
#'
#' @section Safety:
#' - Uses `data.table::setattr()` exclusively (never base `attr<-()`)
#' - Only works on data.table objects (checked)
#' - Returns invisibly for use in piping/side-effect contexts
#'
#' @param x A data.table object
#' @return The same data.table object (modified in-place), invisibly
#' @keywords internal
#' @seealso [st_normalize_attrs()] for copy-based normalization
st_normalize_attrs_inplace <- function(x) {
  # Type check: only data.tables support safe in-place attribute modification
  if (!inherits(x, "data.table")) {
    stop(
      "st_normalize_attrs_inplace() only works with data.table objects. ",
      "Use st_normalize_attrs() for other object types."
    )
  }

  # Ensure data.table package is available
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("data.table package required for in-place attribute normalization")
  }

  attrs <- attributes(x)

  # Fast path: no attributes to normalize
  if (is.null(attrs) || length(attrs) == 0L) {
    return(invisible(x))
  }

  attr_names <- names(attrs)

  # Define canonical priority order (same as st_normalize_attrs)
  priority <- c("names", "row.names", "class", ".internal.selfref")

  # Separate attributes into priority and others
  priority_present <- intersect(priority, attr_names)
  other_attrs <- setdiff(attr_names, priority)

  # Canonical order
  canonical_order <- c(priority_present, sort(other_attrs))

  # Check if already in canonical order (fast path to avoid unnecessary work)
  if (identical(attr_names, canonical_order)) {
    return(invisible(x))
  }

  # Strategy for reordering attributes in-place:
  # We cannot directly reorder the internal attribute pairlist in R.
  # Instead, we must remove all attributes and re-add them in the desired order.
  # For data.table, this is safe because:
  # - setattr() is designed for this
  # - The column data is not affected (stored separately in the list structure)
  # - .internal.selfref gets properly updated by setattr()

  # Step 1: Save all attribute values
  saved_attrs <- attrs

  # Step 2: Clear ALL attributes
  # Note: This is safe for data.table despite looking dangerous
  # The actual column data is in the list structure, not in attributes
  attributes(x) <- NULL

  # Step 3: Re-add attributes in canonical order using data.table::setattr()
  # setattr() is the ONLY safe way to modify data.table attributes
  # It ensures .internal.selfref and other internals stay consistent
  for (nm in canonical_order) {
    data.table::setattr(x, nm, saved_attrs[[nm]])
  }

  # Return invisibly to support usage like: dt |> st_normalize_attrs_inplace()
  invisible(x)
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
#' The normalization creates a copy of the object with attributes reordered to:
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
#' - For large objects: creates a shallow copy (column data is referenced, not copied)
#' - The normalization cost is typically < 1% of total hashing time
#'
#' @param x Any R object (data.frame, data.table, list, vector, etc.)
#' @return Lowercase hex string (16 hex characters) from siphash13().
#'
#' @examples
#' \dontrun{
#' # Two ways to create the "same" data
#' dt_a <- data.table(x = 1:5) |> funique()
#' dt_b <- data.table(x = 1:5) |> rowbind(data.table(x = 1:5)) |> funique()
#'
#' # They're identical in content
#' identical(dt_a, dt_b)  # TRUE
#'
#' # And now they hash the same too!
#' st_hash_obj(dt_a) == st_hash_obj(dt_b)  # TRUE
#' }
#'
#' @export
st_hash_obj <- function(x) {
  # Step 1: Normalize attribute order for consistent serialization
  # This creates a shallow copy with reordered attributes but doesn't copy data
  x_normalized <- st_normalize_attrs(x)

  # Step 2: Serialize the normalized object to raw bytes
  # version = 3 ensures stable serialization format across R 3.5+
  raw <- serialize(x_normalized, connection = NULL, version = 3)

  # Step 3: Hash the raw bytes using SipHash-1-3
  # SipHash is fast and cryptographically strong enough for non-adversarial use
  secretbase::siphash13(raw)
}

#' Stable SipHash-1-3 of code
#'
#' Computes a stable hash of R code (functions, expressions, or character vectors).
#' For functions, includes both formals (arguments) and body. Whitespace is
#' lightly normalized to reduce spurious differences.
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
