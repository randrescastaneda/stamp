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

#' saving in qs2 format in stamps
#' 
#' .st_qs2_write and .st_qs2_read are internal helpers that attempt to write/read
#' 
#' @param x R object to save.
#' @param path Destination file path.
#' @param ... Additional arguments passed to the underlying writer.
#' @name st_qs
#' @keywords internal
NULL
#> NULL

#' @return selected function
#' @rdname st_qs
.st_qs2_write <- function(x, path, ...) {
  if (requireNamespace("qs2", quietly = TRUE)) {
    ns <- asNamespace("qs2")
    for (cand in c("qs_save", "qsave")) {
      if (exists(cand, envir = ns, inherits = FALSE)) {
        return(get(cand, envir = ns)(x, path, ...))
      }
    }
  }
  if (requireNamespace("qs", quietly = TRUE)) {
    return(qs::qsave(x, path, ...))
  }
  cli::cli_abort("Neither {.pkg qs2} nor {.pkg qs} is installed; cannot write qs2 format.")
}

#' @return selected function
#' @rdname st_qs
.st_qs2_read <- function(path, ...) {
  if (requireNamespace("qs2", quietly = TRUE)) {
    ns <- asNamespace("qs2")
    for (cand in c("qs_read", "qread")) {
      if (exists(cand, envir = ns, inherits = FALSE)) {
        return(get(cand, envir = ns)(path, ...))
      }
    }
  }
  if (requireNamespace("qs", quietly = TRUE)) {
    return(qs::qread(path, ...))
  }
  cli::cli_abort("Neither {.pkg qs2} nor {.pkg qs} is installed; cannot read qs2 format.")
}



#' Write using qs2/q (internal)
#'
#' .st_write_qs2 attempts to write `x` to `path` using `qs2::qs_save()` when available,
#' otherwise fall back to `qs::qsave()`. If neither package is
#' installed an error is raised.
#'
#' @return Invisibly returns what the underlying writer returns.
#' @rdname st_qs
.st_write_qs2 <-  function(x, path, ...) .st_qs2_write(x, path, ...)

#' Read using qs2/q (internal)
#'
#' .st_read_qs2 reads an object from `path` using `qs2::qs_read()` when available, or
#' fall back to `qs::qread()` if not. Throws an error when neither
#' package is installed.
#'
#' @return The R object read from `path`.
#' @rdname st_qs
.st_read_qs2 <-  function(path, ...)    .st_qs2_read(path, ...)

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

#' Sidecar metadata path helper (internal)
#'
#' Build the path to a sidecar metadata file for `path`. Sidecars live in
#' a sibling directory named `stmeta` next to the file's directory. The
#' returned filename has the original basename with a `.stmeta.<ext>`
#' suffix where `ext` is typically `"json"` or `"qs2"`.
#'
#' Examples:
#' - `path = "data/file.qs2", ext = "json"` ->
#'   `data/stmeta/file.qs2.stmeta.json`
#' - `path = "dir/a.csv", ext = "qs2"` ->
#'   `dir/stmeta/a.csv.stmeta.qs2`
#'
#' @param path Character scalar path to the main data file.
#' @param ext Character scalar extension for the sidecar (e.g. "json" or "qs2").
#' @return Character scalar with the computed sidecar path.
#' @keywords internal
.st_sidecar_path <- function(path, ext = c("json", "qs2")) {
  ext <- match.arg(ext)
  # Directory and filename pieces
  dir <- fs::path_dir(path)
  base <- fs::path_file(path)
  # stmeta folder placed next to the data file
  sc_dir <- fs::path(dir, "stmeta")
  fs::dir_create(sc_dir, recurse = TRUE)
  fs::path(sc_dir, paste0(base, ".stmeta.", ext))
}

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
    scj <- .st_sidecar_path(path, ext = "json")
    tmp <- fs::file_temp(tmp_dir = fs::path_dir(scj), pattern = fs::path_file(scj))
    jsonlite::write_json(meta, tmp, auto_unbox = TRUE, pretty = TRUE, digits = NA)
    if (fs::file_exists(scj)) fs::file_delete(scj)
    fs::file_move(tmp, scj)
  }

  if (fmt %in% c("qs2", "both")) {
    scq <- .st_sidecar_path(path, ext = "qs2")
    tmp <- fs::file_temp(tmp_dir = fs::path_dir(scq), pattern = fs::path_file(scq))
    if (requireNamespace("qs2", quietly = TRUE)) {
      qs2::qs_save(meta, tmp)
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
#' @export
st_read_sidecar <- function(path) {
  scj <- .st_sidecar_path(path, ext = "json")
  if (fs::file_exists(scj)) {
    return(jsonlite::read_json(scj, simplifyVector = TRUE))
  }
  scq <- .st_sidecar_path(path, ext = "qs2")
  if (fs::file_exists(scq)) {
    if (requireNamespace("qs2", quietly = TRUE)) {
      return(qs2::qs_read(scq))
    } else if (requireNamespace("qs", quietly = TRUE)) {
      return(qs::qread(scq))
    } else {
      stop("Found QS2 sidecar but neither {qs2} nor {qs} is installed.")
    }
  }
  NULL
}
