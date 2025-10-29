# ---- format registry ---------------------------------------------------------
# Internal registry lives in an rlang env; users can extend via st_register_format().
# Each entry: list(read = function(path, ...), write = function(x, path, ...))

#' Internal formats registry
#'
#' An internal environment that stores available read/write handlers for
#' different file formats. Each registry entry is a list with two
#' elements: `read = function(path, ...)` and `write = function(x,
#' path, ...)`. Users can extend or override formats with
#' `st_register_format()`.
#'
#' @keywords internal
.st_formats_env <- rlang::env()

# small utility used here
`%||%` <- function(a, b) if (is.null(a)) b else a

# Prefer qs2::qsave/qread, else fallback to qs::qsave/qread, else error.

#' Write using qs2/q (internal)
#'
#' Attempt to write `x` to `path` using `qs2::qsave()` when available,
#' otherwise fall back to `qs::qsave()`. If neither package is
#' installed an error is raised.
#'
#' @param x R object to save.
#' @param path Destination file path.
#' @param preset Character preset passed to `qsave()`; defaults to `"high"`.
#' @param ... Additional arguments passed to the underlying writer.
#' @return Invisibly returns what the underlying writer returns.
#' @keywords internal
#' @noRd
.st_write_qs2 <- function(x, path, preset = "high", ...) {
  if (requireNamespace("qs2", quietly = TRUE)) {
    qs2::qsave(x, path, preset = preset, ...)
  } else if (requireNamespace("qs", quietly = TRUE)) {
    qs::qsave(x, path, preset = preset, ...) # best-effort fallback
  } else {
    stop("Neither {qs2} nor {qs} is installed; cannot write qs2 format.")
  }
}

#' Read using qs2/q (internal)
#'
#' Read an object from `path` using `qs2::qread()` when available, or
#' fall back to `qs::qread()` if not. Throws an error when neither
#' package is installed.
#'
#' @param path File path to read from.
#' @param ... Additional args passed to the underlying reader.
#' @return The R object read from `path`.
#' @keywords internal
#' @noRd
.st_read_qs2 <- function(path, ...) {
  if (requireNamespace("qs2", quietly = TRUE)) {
    qs2::qread(path, ...)
  } else if (requireNamespace("qs", quietly = TRUE)) {
    qs::qread(path, ...)
  } else {
    stop("Neither {qs2} nor {qs} is installed; cannot read qs2 format.")
  }
}

# Seed built-ins
rlang::env_bind(
  .st_formats_env,
  qs2  = list(read = .st_read_qs2, write = .st_write_qs2),
  rds  = list(
    read  = function(path, ...) readRDS(path, ...),
    write = function(x, path, ...) saveRDS(x, path, ...)
  ),
  csv  = list(
    read  = function(path, ...) {
      if (!requireNamespace("data.table", quietly = TRUE))
        stop("{data.table} required for csv read.")
      data.table::fread(path, ...)
    },
    write = function(x, path, ...) {
      if (!requireNamespace("data.table", quietly = TRUE))
        stop("{data.table} required for csv write.")
      data.table::fwrite(x, path, ...)
    }
  ),
  fst  = list(
    read  = function(path, ...) {
      if (!requireNamespace("fst", quietly = TRUE))
        stop("{fst} is required for fst read.")
      fst::read_fst(path, ...)
    },
    write = function(x, path, ...) {
      if (!requireNamespace("fst", quietly = TRUE))
        stop("{fst} is required for fst write.")
      fst::write_fst(x, path, ...)
    }
  ),
  json = list(
    read  = function(path, ...) {
      if (!requireNamespace("jsonlite", quietly = TRUE))
        stop("{jsonlite} is required for json read.")
      jsonlite::read_json(path, simplifyVector = TRUE, ...)
    },
    write = function(x, path, ...) {
      if (!requireNamespace("jsonlite", quietly = TRUE))
        stop("{jsonlite} is required for json write.")
      jsonlite::write_json(x, path, auto_unbox = TRUE, digits = NA, ...)
    }
  )
)

#' Register or override a format handler
#'
#' Public function that allows users to register a new format handler
#' or override an existing one. Handlers must be functions with the
#' expected signatures documented below.
#'
#' @param name Character scalar: format name (e.g. `"qs2"`, `"rds"`).
#' @param read Function `function(path, ...)` returning an R object.
#' @param write Function `function(object, path, ...)` that writes `object` to `path`.
#' @return Invisibly returns `TRUE` on success.
#' @export
#' @examples
#' st_register_format(
#'   "txt",
#'   read  = function(p, ...) readLines(p, ...),
#'   write = function(x, p, ...) writeLines(x, p, ...)
#' )
st_register_format <- function(name, read, write) {
  stopifnot(
    is.character(name), length(name) == 1L,
    is.function(read),  is.function(write)
  )
  rlang::env_poke(.st_formats_env, name, list(read = read, write = write))
  cli::cli_inform(c("v" = paste0("Registered format '", name, "'")))
  invisible(TRUE)
}

#' Inspect available formats
#'
#' Return a sorted character vector with the names of formats
#' currently registered in the internal registry.
#'
#' @return Character vector of format names.
#' @examples
#' st_formats()
#' @export
st_formats <- function() {
  # names(as.list(env)) is robust for rlang envs
  sort(names(as.list(.st_formats_env)))
}

# ---- sidecar metadata --------------------------------------------------------

# NOTE: st_opts(meta_format=) is expected to be defined elsewhere in the package.

# Sidecar path helpers (both variants supported).
# e.g., "file.qs2" -> "file.qs2.stmeta.json" / "file.qs2.stmeta.qs2"
# (Keep both to honor meta_format = "json" | "qs2" | "both")

#' @keywords internal
#' @noRd
.st_sidecar_json_path <- function(path) paste0(path, ".stmeta.json")

#' @keywords internal
#' @noRd
.st_sidecar_qs2_path  <- function(path) paste0(path, ".stmeta.qs2")

#' Write sidecar metadata (internal)
#'
#' Write `meta` (a list) as sidecar(s) for `path`. The file(s) are first
#' written to temp files in the same directory and then moved into place
#' to reduce risk of partial writes.
#'
#' Respects `st_opts(meta_format = "json" | "qs2" | "both")`.
#'
#' @param path Character path of the data file whose sidecar will be written.
#' @param meta List or object convertible to JSON / qs2.
#' @keywords internal
#' @noRd
.st_write_sidecar <- function(path, meta) {
  fmt <- st_opts("meta_format", .get = TRUE) %||% "json"

  if (fmt %in% c("json", "both")) {
    scj <- .st_sidecar_json_path(path)
    tmp <- fs::file_temp(tmp_dir = fs::path_dir(scj), pattern = fs::path_file(scj))
    jsonlite::write_json(meta, tmp, auto_unbox = TRUE, pretty = TRUE, digits = NA)
    if (fs::file_exists(scj)) fs::file_delete(scj)
    fs::file_move(tmp, scj)
  }

  if (fmt %in% c("qs2", "both")) {
    scq <- .st_sidecar_qs2_path(path)
    tmp <- fs::file_temp(tmp_dir = fs::path_dir(scq), pattern = fs::path_file(scq))
    if (requireNamespace("qs2", quietly = TRUE)) {
      qs2::qsave(meta, tmp)
    } else if (requireNamespace("qs", quietly = TRUE)) {
      qs::qsave(meta, tmp)
    } else {
      stop("meta_format includes 'qs2' but neither {qs2} nor {qs} is installed.")
    }
    if (fs::file_exists(scq)) fs::file_delete(scq)
    fs::file_move(tmp, scq)
  }
  invisible(NULL)
}

#' Read sidecar metadata (internal)
#'
#' Read the sidecar metadata for `path` if it exists, returning `NULL`
#' when no sidecar file is present. Preference order is JSON first,
#' then QS2. When a QS2 variant is encountered the function will use
#' `qs2` or fall back to `qs`.
#'
#' @param path Character path of the data file whose sidecar will be read.
#' @return A list (parsed JSON / qs object) or `NULL` if not found.
#' @keywords internal
#' @noRd
.st_read_sidecar <- function(path) {
  scj <- .st_sidecar_json_path(path)
  if (fs::file_exists(scj)) {
    return(jsonlite::read_json(scj, simplifyVector = TRUE))
  }
  scq <- .st_sidecar_qs2_path(path)
  if (fs::file_exists(scq)) {
    if (requireNamespace("qs2", quietly = TRUE)) {
      return(qs2::qread(scq))
    } else if (requireNamespace("qs", quietly = TRUE)) {
      return(qs::qread(scq))
    } else {
      stop("Found QS2 sidecar but neither {qs2} nor {qs} is installed.")
    }
  }
  NULL
}
