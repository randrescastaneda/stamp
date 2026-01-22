# ---- format registry ---------------------------------------------------------
# Internal registry lives in .st_formats_env; users can extend via st_register_format().
# Each entry: list(read = function(path, ...), write = function(x, path, ...))

#' Internal format handlers for stamp
#'
#' @param x R object to save.
#' @param path Destination file path.
#' @param ... Additional arguments passed to the underlying writer/reader.
#' @name stamp-format-helpers
#' @keywords internal
NULL

# ---- helpers: verbose-aware wrappers ----------------------------------------

# Wrap a reader: adds verbose arg and suppresses warnings when FALSE
.st_wrap_reader <- function(read_fn) {
  function(path, verbose = TRUE, ...) {
    if (isTRUE(verbose)) {
      read_fn(path, ...)
    } else {
      suppressWarnings(read_fn(path, ...))
    }
  }
}

# Wrap a writer: adds verbose arg and suppresses warnings when FALSE
.st_wrap_writer <- function(write_fn) {
  function(x, path, verbose = TRUE, ...) {
    if (isTRUE(verbose)) {
      write_fn(x, path, ...)
    } else {
      suppressWarnings(write_fn(x, path, ...))
    }
  }
}

# ---- base handlers (no verbose logic inside) --------------------------------

.st_write_qs2 <- function(x, path, ...) {
  if (!requireNamespace("qs2", quietly = TRUE)) {
    cli::cli_abort(
      "{.pkg qs2} is required to write {.field qs2} format. Please install {.pkg qs2}."
    )
  }
  qs2::qs_save(x, path, ...)
}

.st_read_qs2 <- function(path, ...) {
  if (!requireNamespace("qs2", quietly = TRUE)) {
    cli::cli_abort(
      "{.pkg qs2} is required to read {.field qs2} format. Please install {.pkg qs2}."
    )
  }
  qs2::qs_read(path, ...)
}

.st_qs_read <- function(path, ...) {
  qs::qread(path, ...)
}
.st_qs_write <- function(x, path, ...) {
  qs::qsave(x, path, ...)
}
.st_rds_read <- function(path, ...) {
  readRDS(path, ...)
}
.st_rds_write <- function(x, path, ...) {
  saveRDS(x, path, ...)
}
.st_csv_read <- function(path, ...) {
  data.table::fread(path, ...)
}
.st_csv_write <- function(x, path, ...) {
  data.table::fwrite(x, path, ...)
}

.st_fst_read <- function(path, ...) {
  if (!requireNamespace("fst", quietly = TRUE)) {
    cli::cli_abort("{.pkg fst} is required for FST read.")
  }
  fst::read_fst(path, ...)
}
.st_fst_write <- function(x, path, ...) {
  if (!requireNamespace("fst", quietly = TRUE)) {
    cli::cli_abort("{.pkg fst} is required for FST write.")
  }
  fst::write_fst(x, path, ...)
}

.st_parquet_read <- function(path, ...) {
  if (!requireNamespace("nanoparquet", quietly = TRUE)) {
    cli::cli_abort("{.pkg nanoparquet} is required for Parquet read.")
  }
  nanoparquet::read_parquet(path, ...)
}
.st_parquet_write <- function(x, path, ...) {
  if (!requireNamespace("nanoparquet", quietly = TRUE)) {
    cli::cli_abort("{.pkg nanoparquet} is required for Parquet write.")
  }
  nanoparquet::write_parquet(x, file = path, ...)
}

.st_json_read <- function(path, ...) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cli::cli_abort("{.pkg jsonlite} is required for JSON read.")
  }
  jsonlite::read_json(path, simplifyVector = TRUE, ...)
}
.st_json_write <- function(x, path, ...) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    cli::cli_abort("{.pkg jsonlite} is required for JSON write.")
  }
  jsonlite::write_json(x, path, auto_unbox = TRUE, digits = NA, ...)
}

# ---- bind wrapped handlers into registry ------------------------------------

rlang::env_bind(
  .st_formats_env,
  qs2 = list(
    read = .st_wrap_reader(.st_read_qs2),
    write = .st_wrap_writer(.st_write_qs2)
  ),
  qs = list(
    read = .st_wrap_reader(.st_qs_read),
    write = .st_wrap_writer(.st_qs_write)
  ),
  rds = list(
    read = .st_wrap_reader(.st_rds_read),
    write = .st_wrap_writer(.st_rds_write)
  ),
  csv = list(
    read = .st_wrap_reader(.st_csv_read),
    write = .st_wrap_writer(.st_csv_write)
  ),
  fst = list(
    read = .st_wrap_reader(.st_fst_read),
    write = .st_wrap_writer(.st_fst_write)
  ),
  parquet = list(
    read = .st_wrap_reader(.st_parquet_read),
    write = .st_wrap_writer(.st_parquet_write)
  ),
  json = list(
    read = .st_wrap_reader(.st_json_read),
    write = .st_wrap_writer(.st_json_write)
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
#' @param extensions Optional character vector of file extensions (e.g. `c("qs","qs2")`)
#'   to map to this format; case-insensitive; without dots.
#' @return Invisibly returns `TRUE` on success.
#' @export
#' @examples
#' st_register_format(
#'   "txt",
#'   read  = function(p, ...) readLines(p, ...),
#'   write = function(x, p, ...) writeLines(x, p, ...),
#'   extensions = "txt"
#' )
st_register_format <- function(name, read, write, extensions = NULL) {
  stopifnot(
    is.character(name),
    length(name) == 1L,
    is.function(read),
    is.function(write),
    is.null(extensions) || is.character(extensions)
  )

  replacing <- rlang::env_has(.st_formats_env, name)
  rlang::env_poke(
    .st_formats_env,
    name,
    list(read = .st_wrap_reader(read), write = .st_wrap_writer(write))
  )

  if (!is.null(extensions)) {
    .st_extmap_set(extensions, name)
  }

  cli::cli_inform(c(
    "v" = if (replacing) {
      paste0("Replaced format {.field ", name, "}")
    } else {
      paste0("Registered format {.field ", name, "}")
    },
    " " = if (!is.null(extensions) && length(extensions)) {
      uext <- unique(tolower(extensions[nzchar(extensions)]))
      paste0("extensions: .", paste(uext, collapse = ", ."))
    } else {
      "extensions: (none)"
    }
  ))
  invisible(TRUE)
}

# Map extensions -> format (helper)
.st_extmap_set <- function(extensions, format) {
  # Validate format exists
  if (!rlang::env_has(.st_formats_env, format)) {
    cli::cli_abort(c(
      "Format {.field {format}} is not registered",
      "i" = "Register it first with {.fn st_register_format}"
    ))
  }

  exts <- unique(tolower(extensions[nzchar(extensions)]))
  for (ext in exts) {
    rlang::env_poke(.st_extmap_env, ext, format)
  }
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
  sort(names(as.list(.st_formats_env)))
}

# ---- sidecar metadata --------------------------------------------------------

# Sidecar path helpers (both variants supported).
# e.g., "file.qs2" -> "data/stmeta/file.qs2.stmeta.json" or ".qs2"
# (Honors meta_format = "json" | "qs2" | "both")

#' Sidecar metadata path helper (internal)
#'
#' Build the path to a sidecar metadata file for a given relative path.
#' New structure: <data_folder>/<rel_path>/stmeta/<filename>.stmeta.<ext>
#'
#' @param rel_path Character relative path from alias root (includes filename).
#' @param ext Character scalar extension for the sidecar (e.g. "json" or "qs2").
#' @param alias Optional alias
#' @return Character scalar with the computed sidecar path.
#' @keywords internal
.st_sidecar_path <- function(rel_path, ext = c("json", "qs2"), alias = NULL) {
  ext <- match.arg(ext)

  # Get file storage directory in .st_data structure
  storage_dir <- .st_file_storage_dir(rel_path, alias = alias)
  filename <- fs::path_file(rel_path)

  # Sidecar path: <storage_dir>/stmeta/<filename>.stmeta.<ext>
  sc_dir <- fs::path(storage_dir, "stmeta")
  fs::path(sc_dir, paste0(filename, ".stmeta.", ext))
}

#' Write sidecar metadata (internal)
#'
#' Write `meta` (a list) as sidecar(s) for a file. The file(s) are first
#' written to temp files in the same directory and then moved into place
#' to reduce risk of partial writes.
#'
#' Respects `st_opts(meta_format = "json" | "qs2" | "both")`.
#'
#' @param rel_path Character relative path from alias root.
#' @param meta List or object convertible to JSON / qs2.
#' @param alias Optional alias.
#' @keywords internal
#' @noRd
.st_write_sidecar <- function(rel_path, meta, alias = NULL) {
  fmt <- st_opts("meta_format", .get = TRUE) %||% "json"

  if (fmt %in% c("json", "both")) {
    scj <- .st_sidecar_path(rel_path, ext = "json", alias = alias)
    fs::dir_create(fs::path_dir(scj), recurse = TRUE)
    tmp <- fs::file_temp(
      tmp_dir = fs::path_dir(scj),
      pattern = "stmeta-" # Fixed prefix only
    )
    jsonlite::write_json(
      meta,
      tmp,
      auto_unbox = TRUE,
      pretty = TRUE,
      digits = NA
    )
    if (fs::file_exists(scj)) {
      fs::file_delete(scj)
    }
    fs::file_move(tmp, scj)
  }

  if (fmt %in% c("qs2", "both")) {
    scq <- .st_sidecar_path(rel_path, ext = "qs2", alias = alias)
    fs::dir_create(fs::path_dir(scq), recurse = TRUE)
    tmp <- fs::file_temp(
      tmp_dir = fs::path_dir(scq),
      pattern = "stmeta-" # CHANGED: fixed prefix like JSON
    )
    .st_write_qs2(meta, tmp)
    if (fs::file_exists(scq)) {
      fs::file_delete(scq)
    }
    fs::file_move(tmp, scq)
  }
  invisible(NULL)
}


#' Read sidecar metadata (internal)
#'
#' Read the sidecar metadata for a file if it exists, returning `NULL`
#' when no sidecar file is present. Preference order is JSON first,
#' then QS2.
#'
#' @param rel_path Character relative path from alias root.
#' @param alias Optional alias.
#' @return A list (parsed JSON / qs object) or `NULL` if not found.
#' @export
st_read_sidecar <- function(rel_path, alias = NULL) {
  scj <- .st_sidecar_path(rel_path, ext = "json", alias = alias)
  if (fs::file_exists(scj)) {
    return(jsonlite::read_json(scj, simplifyVector = TRUE))
  }
  scq <- .st_sidecar_path(rel_path, ext = "qs2", alias = alias)
  if (fs::file_exists(scq)) {
    return(.st_read_qs2(scq))
  }
  invisible(NULL)
}
