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
