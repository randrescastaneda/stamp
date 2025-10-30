# ---- Hashing (secretbase only) -----------------------------------------------

#' Stable object hash
#'
#' Compute a canonical, encoding-independent hash for any R object.
#' The implementation serializes the object with `serialize(...,
#' version = 3)` and computes a SipHash-13 via `secretbase::siphash13`.
#' This yields a stable result across R sessions and independent of
#' file encodings or serialization presets.
#'
#' @param x Any R object to hash.
#' @return Character scalar containing the hex representation of the
#'   SipHash-13 of the serialized object.
#' @examples
#' st_hash_obj(list(a = 1, b = "x"))
#' @export
st_hash_obj <- function(x) {
  secretbase::siphash13(serialize(x, NULL, version = 3))
}

#' File content hash
#'
#' Compute a SipHash-13 over the contents of a file. Intended for
#' integrity and tamper checks. The function requires a single existing
#' file path.
#'
#' @param path Character scalar path to a file.
#' @return Character scalar containing the hex hash of the file
#'   contents.
#' @examples
#' # write a temp file and hash it
#' tf <- tempfile(); writeLines("hello", tf); st_hash_file(tf)
#' @export
st_hash_file <- function(path) {
  stopifnot(length(path) == 1L, fs::file_exists(path))
  secretbase::siphash13(file = path)
}

#' Hash R function code
#'
#' Compute a hash for a function's code by combining the textual
#' representation of its formals and body. The function intentionally
#' ignores the environment to avoid spurious differences coming from
#' enclosing environments.
#'
#' @param fun A function object to hash.
#' @return Character scalar with the SipHash-13 hex digest of the
#'   combined formals and body.
#' @examples
#' f <- function(x, y = 1) x + y
#' st_hash_code(f)
#' @export
st_hash_code <- function(fun) {
  stopifnot(is.function(fun))
  f <- paste0(deparse(formals(fun), width.cutoff = 500L), collapse = "\n")
  b <- paste0(deparse(body(fun),    width.cutoff = 500L), collapse = "\n")
  secretbase::siphash13(paste(f, b, sep = "\n\n"))
}
