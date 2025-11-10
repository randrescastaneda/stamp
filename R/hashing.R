# hashing.R — content/code/file hashing with secretbase only

#' Stable SipHash-1-3 of an R object
#'
#' Serializes the object with base::serialize(version = 3) and hashes the raw
#' bytes via secretbase::siphash13(). This is stable across sessions (given the
#' same R version and object structure) and suitable for change detection.
#'
#' @param x Any R object.
#' @return Lowercase hex string (16 hex chars) from siphash13().
#' @keywords internal
st_hash_obj <- function(x) {
  raw <- serialize(x, connection = NULL, version = 3)
  secretbase::siphash13(raw)
}

#' Stable SipHash-1-3 of code
#'
#' Accepts a function, expression (language), or character. For functions,
#' includes both formals and body. Whitespace is normalized conservatively.
#'
#' @param code A function, expression, or character vector.
#' @return Lowercase hex string (16 hex chars).
#' @keywords internal
st_hash_code <- function(code) {
  if (is.function(code)) {
    fml <- formals(code)
    txt <- c(
      paste(deparse(fml), collapse = "\n"),
      paste(deparse(body(code)), collapse = "\n")
    )
  } else if (is.language(code)) {
    txt <- paste(deparse(code), collapse = "\n")
  } else {
    txt <- paste(as.character(code), collapse = "\n")
  }
  }
  # light normalization
  txt <- gsub("[ \t]+", " ", txt)
  txt <- gsub("\r\n?", "\n", txt, perl = TRUE)
  secretbase::siphash13(txt)
}

#' SipHash-1-3 of a file (bytes on disk)
#'
#' @param path Path to a file.
#' @return Lowercase hex string (16 hex chars).
#' @keywords internal
st_hash_file <- function(path) {
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
