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

#' Write using qs2 (internal)
#'
#' Write `x` to `path` using `qs2` APIs. Errors if the {.pkg qs2}
#' package is not installed or required entrypoints are unavailable.
#'
#' @return Invisibly returns what the underlying writer returns.
#' @rdname stamp-format-helpers
.st_write_qs2 <- function(x, path, verbose = TRUE, ...) {
  if (!requireNamespace("qs2", quietly = TRUE)) {
    cli::cli_abort(
      "{.pkg qs2} is required to write {.field qs2} format. Please install {.pkg qs2}."
    )
  }
  if (isTRUE(verbose)) {
    qs2::qs_save(x, path, ...)
  } else {
    suppressWarnings(qs2::qs_save(x, path, ...))
  }
}

#' Read using qs2 (internal)
#'
#' Read an object from `path` using `qs2` APIs. Errors if the {.pkg qs2}
#' package is not installed or required entrypoints are unavailable.
#'
#' @return The R object read from `path`.
#' @rdname stamp-format-helpers
.st_read_qs2 <- function(path, verbose = TRUE, ...) {
  if (!requireNamespace("qs2", quietly = TRUE)) {
    cli::cli_abort(
      "{.pkg qs2} is required to read {.field qs2} format. Please install {.pkg qs2}."
    )
  }
  if (isTRUE(verbose)) {
    qs2::qs_read(path, ...)
  } else {
    suppressWarnings(qs2::qs_read(path, ...))
  }
}

# Seed built-ins with explicit closures for all format handlers
rlang::env_bind(
  .st_formats_env,
  qs2 = list(read = .st_read_qs2, write = .st_write_qs2),
  qs = list(
    read = function(path, verbose = TRUE, ...) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        cli::cli_abort("{.pkg qs} is required for QS read.")
      }
      if (isTRUE(verbose)) {
        qs::qread(path, ...)
      } else {
        suppressWarnings(qs::qread(path, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (!requireNamespace("qs", quietly = TRUE)) {
        cli::cli_abort("{.pkg qs} is required for QS write.")
      }
      if (isTRUE(verbose)) {
        qs::qsave(x, path, ...)
      } else {
        suppressWarnings(qs::qsave(x, path, ...))
      }
    }
  ),
  rds = list(
    read = function(path, verbose = TRUE, ...) {
      if (isTRUE(verbose)) {
        readRDS(path, ...)
      } else {
        suppressWarnings(readRDS(path, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (isTRUE(verbose)) {
        saveRDS(x, path, ...)
      } else {
        suppressWarnings(saveRDS(x, path, ...))
      }
    }
  ),
  csv = list(
    read = function(path, verbose = TRUE, ...) {
      if (isTRUE(verbose)) {
        data.table::fread(path, ...)
      } else {
        suppressWarnings(data.table::fread(path, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (isTRUE(verbose)) {
        data.table::fwrite(x, path, ...)
      } else {
        suppressWarnings(data.table::fwrite(x, path, ...))
      }
    }
  ),
  fst = list(
    read = function(path, verbose = TRUE, ...) {
      if (!requireNamespace("fst", quietly = TRUE)) {
        cli::cli_abort("{.pkg fst} is required for FST read.")
      }
      if (isTRUE(verbose)) {
        fst::read_fst(path, ...)
      } else {
        suppressWarnings(fst::read_fst(path, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (!requireNamespace("fst", quietly = TRUE)) {
        cli::cli_abort("{.pkg fst} is required for FST write.")
      }
      if (isTRUE(verbose)) {
        fst::write_fst(x, path, ...)
      } else {
        suppressWarnings(fst::write_fst(x, path, ...))
      }
    }
  ),
  parquet = list(
    read = function(path, verbose = TRUE, ...) {
      if (!requireNamespace("nanoparquet", quietly = TRUE)) {
        cli::cli_abort("{.pkg nanoparquet} is required for Parquet read.")
      }
      if (isTRUE(verbose)) {
        nanoparquet::read_parquet(path, ...)
      } else {
        suppressWarnings(nanoparquet::read_parquet(path, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (!requireNamespace("nanoparquet", quietly = TRUE)) {
        cli::cli_abort("{.pkg nanoparquet} is required for Parquet write.")
      }
      if (isTRUE(verbose)) {
        nanoparquet::write_parquet(x, file = path, ...)
      } else {
        suppressWarnings(nanoparquet::write_parquet(x, file = path, ...))
      }
    }
  ),
  json = list(
    read = function(path, verbose = TRUE, ...) {
      if (!requireNamespace("jsonlite", quietly = TRUE)) {
        cli::cli_abort("{.pkg jsonlite} is required for JSON read.")
      }
      if (isTRUE(verbose)) {
        jsonlite::read_json(path, simplifyVector = TRUE, ...)
      } else {
        suppressWarnings(jsonlite::read_json(path, simplifyVector = TRUE, ...))
      }
    },
    write = function(x, path, verbose = TRUE, ...) {
      if (!requireNamespace("jsonlite", quietly = TRUE)) {
        cli::cli_abort("{.pkg jsonlite} is required for JSON write.")
      }
      if (isTRUE(verbose)) {
        jsonlite::write_json(x, path, auto_unbox = TRUE, digits = NA, ...)
      } else {
        suppressWarnings(jsonlite::write_json(
          x,
          path,
          auto_unbox = TRUE,
          digits = NA,
          ...
        ))
      }
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
  rlang::env_poke(.st_formats_env, name, list(read = read, write = write))

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
#' Build the path to a sidecar metadata file for `path`. Sidecars live in
#' a sibling directory named `stmeta` next to the file's directory. The
#' returned filename has the original basename with a `.stmeta.<ext>` suffix
#' where `ext` is typically `"json"` or `"qs2"`.
#'
#' @param path Character scalar path to the main data file.
#' @param ext Character scalar extension for the sidecar (e.g. "json" or "qs2").
#' @return Character scalar with the computed sidecar path.
#' @keywords internal
.st_sidecar_path <- function(path, ext = c("json", "qs2")) {
  ext <- match.arg(ext)
  dir <- fs::path_dir(path)
  base <- fs::path_file(path)
  sc_dir <- fs::path(dir, "stmeta")
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
    scq <- .st_sidecar_path(path, ext = "qs2")
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
#' Read the sidecar metadata for `path` if it exists, returning `NULL`
#' when no sidecar file is present. Preference order is JSON first,
#' then QS2.
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
    return(.st_read_qs2(scq))
  }
  invisible(NULL)
}
