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
    txt <- c(
      paste0("formals:", paste0(names(formals(code)), collapse = ",")),
      paste(deparse(body(code)), collapse = "\n")
    )
  } else if (is.language(code)) {
    txt <- paste(deparse(code), collapse = "\n")
  } else {
    txt <- paste(as.character(code), collapse = "\n")
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
st_changed <- function(path, x = NULL, code = NULL,
                       mode = c("any", "content", "code", "file")) {
  mode <- match.arg(mode)
  if (!fs::file_exists(path)) {
    return(list(changed = TRUE, reason = "missing_artifact", detail = list()))
  }

  meta <- st_read_sidecar(path)
  if (is.null(meta) || !is.list(meta)) {
    return(list(changed = TRUE, reason = "missing_meta", detail = list()))
  }

  checks <- list()

  # content check (object vs. last saved content_hash)
  if (mode %in% c("any", "content")) {
    if (is.null(x)) {
      checks$content <- NA
    } else {
      want <- meta$content_hash %||% NA_character_
      have <- st_hash_obj(x)
      checks$content <- !identical(want, have)
    }
  }

  # code check (code vs. last saved code_hash)
  if (mode %in% c("any", "code")) {
    if (is.null(code)) {
      checks$code <- NA
    } else {
      want <- meta$code_hash %||% NA_character_
      have <- st_hash_code(code)
      checks$code <- !identical(want, have)
    }
  }

  # file check (bytes on disk vs. last saved file_hash, if present)
  if (mode %in% c("any", "file")) {
    want <- meta$file_hash %||% NA_character_
    if (is.na(want) || !nzchar(want)) {
      checks$file <- NA
    } else {
      have <- st_hash_file(path)
      checks$file <- !identical(want, have)
    }
  }

  # decide
  flags <- unlist(checks, use.names = TRUE)
  # consider only non-NA checks
  eff <- flags[!is.na(flags)]
  changed <- if (!length(eff)) FALSE else any(eff)

  reason <- if (!length(eff)) "no_checks"
            else if (changed) paste(names(eff)[as.logical(eff)], collapse = "+")
            else "no_change"

  list(changed = changed, reason = reason, detail = checks)
}
