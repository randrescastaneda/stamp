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
  if (is.null(x)) {
    cli::cli_abort("CSV cannot store NULL as an R object; use RDS or QS2.")
  }
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
  if (is.null(x)) {
    cli::cli_abort("FST cannot store NULL as an R object; use RDS or QS2.")
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
  if (is.null(x)) {
    cli::cli_abort("Parquet cannot store NULL as an R object; use RDS or QS2.")
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

.st_metadata_names <- function(x) {
  reserved <- c(
    "path", "format", "created_at", "size_bytes", "content_hash",
    "code_hash", "file_hash", "code_label", "parents", "attrs", "pk",
    "domain", "version_id", "receipt_id", "outcome_id", "request_id",
    "request", "semantic_schema", "semantic", "execution"
  )
  if (!is.list(x) || is.object(x) ||
      (length(x) && (is.null(names(x)) || anyNA(names(x)) ||
                    any(!nzchar(names(x))) || anyDuplicated(names(x))))) {
    cli::cli_abort("Modern metadata must be a uniquely named list.")
  }
  if (any(names(x) %in% reserved)) {
    cli::cli_abort("Metadata names must not collide with stamp-owned keys.")
  }
  invisible(NULL)
}

# Canonical schema and selected values retain presence, type and vector shape.
.st_semantic_validate <- function(schema, metadata) {
  .st_metadata_names(metadata)
  if (is.null(schema)) {
    return(list(schema = NULL, values = list()))
  }
  .st_metadata_names(schema)
  canonical <- list()
  values <- list()
  fields <- c("type", "shape", "required", "nullable", "allow_na")
  for (name in sort(names(schema), method = "radix")) {
    descriptor <- schema[[name]]
    if (!is.list(descriptor) || is.object(descriptor) ||
        length(descriptor) != length(fields) ||
        anyDuplicated(names(descriptor)) ||
        !setequal(names(descriptor), fields)) {
      cli::cli_abort("Invalid semantic descriptor for {.val {name}}.")
    }
    descriptor <- descriptor[fields]
    for (flag in c("required", "nullable", "allow_na")) {
      value <- descriptor[[flag]]
      if (!is.logical(value) || length(value) != 1L || is.na(value)) {
        cli::cli_abort("Semantic {.val {flag}} must be TRUE or FALSE.")
      }
    }
    if (!is.character(descriptor$type) || length(descriptor$type) != 1L ||
        is.na(descriptor$type) ||
        !descriptor$type %in% c("logical", "integer", "double", "character") ||
        !is.character(descriptor$shape) || length(descriptor$shape) != 1L ||
        is.na(descriptor$shape) ||
        !descriptor$shape %in% c("scalar", "vector")) {
      cli::cli_abort("Invalid semantic type or shape for {.val {name}}.")
    }
    canonical[name] <- list(descriptor)
    if (!name %in% names(metadata)) {
      if (descriptor$required) {
        cli::cli_abort("Required semantic field {.val {name}} is absent.")
      }
      next
    }
    value <- metadata[[name]]
    if (is.null(value)) {
      if (!descriptor$nullable) {
        cli::cli_abort("Semantic field {.val {name}} is not nullable.")
      }
    } else if (is.object(value) || !is.null(dim(value)) ||
               typeof(value) != descriptor$type ||
               (descriptor$shape == "scalar" && length(value) != 1L) ||
               (!descriptor$allow_na && anyNA(value)) ||
               (is.double(value) && (any(is.nan(value)) ||
                                      any(is.infinite(value))))) {
      cli::cli_abort("Semantic value {.val {name}} violates its descriptor.")
    }
    values[name] <- list(value)
  }
  return(list(schema = canonical, values = values))
}

.st_sidecar_is_modern <- function(meta) {
  is.list(meta) && is.list(meta$attrs) && is.list(meta$attrs$stamp) &&
    identical(meta$attrs$stamp$protocol, "stamp-sidecar-v1")
}

.st_sidecar_decode <- function(meta) {
  if (!is.list(meta)) {
    cli::cli_abort("Invalid sidecar metadata.")
  }
  if (!.st_sidecar_is_modern(meta)) return(meta)
  marker <- meta$attrs$stamp
  if (!identical(sort(names(marker)),
                 c("execution", "protocol", "semantic", "sidecars")) ||
      !is.logical(marker$semantic) || length(marker$semantic) != 1L ||
      is.na(marker$semantic) || !is.logical(marker$execution) ||
      length(marker$execution) != 1L || is.na(marker$execution) ||
      !is.character(marker$sidecars) || length(marker$sidecars) != 1L ||
      is.na(marker$sidecars) ||
      !marker$sidecars %in% c("json", "qs2", "both") ||
      (!marker$semantic && "semantic" %in% names(meta)) ||
      (!marker$execution && "execution" %in% names(meta))) {
    cli::cli_abort("Invalid modern sidecar protocol marker.")
  }
  if (anyDuplicated(names(meta))) {
    cli::cli_abort("Duplicated modern sidecar metadata names.")
  }
  if (marker$semantic) {
    envelope <- meta$semantic
    if (!is.list(envelope) ||
        !identical(sort(names(envelope)), c("definition", "schema", "values")) ||
        !identical(envelope$schema, 1L)) {
      cli::cli_abort("Invalid typed semantic envelope.")
    }
    schema <- .st_proof_decode(envelope$definition)
    values <- .st_proof_decode(envelope$values)
    selected <- .st_semantic_validate(schema, values)
    if (is.null(schema) || !identical(selected$schema, schema) ||
        !identical(selected$values, values)) {
      cli::cli_abort("Inconsistent typed semantic envelope.")
    }
    meta[names(values)] <- values
  }
  if (marker$execution) {
    envelope <- meta$execution
    if (!is.list(envelope) ||
        !identical(sort(names(envelope)), c("request", "schema")) ||
        !identical(envelope$schema, 1L) ||
        !is.list(.st_proof_decode(envelope$request))) {
      cli::cli_abort("Invalid execution metadata envelope.")
    }
  }
  return(meta)
}

# Sidecar path helpers (both variants supported).
# e.g., "file.qs2" -> "data/stmeta/file.qs2.stmeta.json" or ".qs2"
# (Honors meta_format = "json" | "qs2" | "both")

#' Sidecar metadata path helper (internal)
#'
#' Build the path to a sidecar metadata file for a given relative path.
#' New structure: `<data_folder>/<rel_path>/stmeta/<filename>.stmeta.<ext>`
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
    .st_write_atomic(
      meta, scj, overwrite = TRUE,
      writer = function(x, path) {
        jsonlite::write_json(x, path, auto_unbox = TRUE, pretty = TRUE, digits = NA)
      }
    )
  }

  if (fmt %in% c("qs2", "both")) {
    scq <- .st_sidecar_path(rel_path, ext = "qs2", alias = alias)
    .st_write_atomic(meta, scq, writer = .st_write_qs2, overwrite = TRUE)
  }
  # Remove the superseded representation only after the new write succeeds.
  if (fmt %in% c("json", "qs2")) {
    stale <- .st_sidecar_path(
      rel_path, ext = if (fmt == "json") "qs2" else "json", alias = alias
    )
    if (fs::file_exists(stale)) fs::file_delete(stale)
  }
  invisible(NULL)
}


#' Read current or exact historical sidecar metadata
#'
#' Read the sidecar metadata for a file if it exists, returning `NULL`
#' when no sidecar file is present. Preference order is JSON first,
#' then QS2.
#' Modern metadata restores declared semantic fields to their original R types
#' and validates both sidecars when both were required. Legacy JSON-first reads
#' do not reinterpret arbitrary descriptive lists as semantic/execution proof.
#'
#' @param rel_path Character relative path from alias root, or an absolute path.
#'   If an absolute path is provided, it will be normalized to a relative path.
#' @param alias Optional alias. If `NULL` and an absolute path is provided,
#'   the alias will be auto-detected from the path.
#' @param version_id Optional exact version identifier. Reads only that retained
#'   snapshot and errors if its artifact or required sidecars are unavailable.
#'   There is no fallback to current metadata. NULL keeps the current reader.
#'   No artifact format reader is called; metadata parsing is data-free.
#' @return A metadata list, with typed declared semantic fields for modern
#'   sidecars. Legacy metadata remains in its original reader representation.
#'   A current read with no sidecar returns NULL; explicit unavailable versions
#'   or inconsistent modern envelopes error.
#' @export
st_read_sidecar <- function(rel_path, alias = NULL, version_id = NULL) {
  rel_path <- as.character(rel_path)

  # If the path appears to be absolute, normalize it to relative path + alias
  if (fs::is_absolute_path(rel_path)) {
    norm <- tryCatch(
      .st_normalize_user_path(
        rel_path,
        alias = alias,
        must_exist = FALSE,
        verbose = FALSE
      ),
      error = function(e) NULL
    )
    if (!is.null(norm)) {
      rel_path <- norm$rel_path
      alias <- norm$alias
    }
  }

  if (!is.null(version_id)) {
    if (!is.character(version_id) || length(version_id) != 1L ||
        is.na(version_id) || !nzchar(version_id)) {
      cli::cli_abort("An exact nonempty version ID is required.")
    }
    versions <- st_versions(rel_path, alias = alias)
    requested_id <- version_id
    row <- versions[which(versions$version_id == requested_id), ]
    if (nrow(row) != 1L) {
      cli::cli_abort("Unknown exact version {.val {version_id}}.")
    }
    directory <- .st_version_dir(rel_path, version_id, alias = alias)
    if (!fs::file_exists(fs::path(directory, "artifact"))) {
      cli::cli_abort("Retained snapshot is unavailable.")
    }
    scj <- fs::path(directory, "sidecar.json")
    scq <- fs::path(directory, "sidecar.qs2")
    required <- row$sidecar_format[[1L]]
    if (!required %in% c("json", "qs2", "both") ||
        (required %in% c("json", "both") && !fs::file_exists(scj)) ||
        (required %in% c("qs2", "both") && !fs::file_exists(scq))) {
      cli::cli_abort("Required historical sidecar is unavailable.")
    }
  } else {
    scj <- .st_sidecar_path(rel_path, ext = "json", alias = alias)
    scq <- .st_sidecar_path(rel_path, ext = "qs2", alias = alias)
  }
  json <- if (fs::file_exists(scj)) {
    .st_sidecar_decode(jsonlite::read_json(scj, simplifyVector = TRUE))
  } else NULL
  # Legacy JSON remains authoritative; diagnostics never promote arbitrary
  # descriptive semantic/execution fields into modern proof.
  if (!is.null(json) && !.st_sidecar_is_modern(json)) {
    if (fs::file_exists(scq)) {
      other <- tryCatch(.st_read_qs2(scq), error = function(e) e)
      if (inherits(other, "error")) {
        cli::cli_warn(
          "QS2 sidecar metadata is unreadable for {.file {rel_path}}; using JSON."
        )
      } else {
        if (.st_sidecar_is_modern(other)) {
          cli::cli_abort("JSON and QS2 typed sidecars disagree.")
        }
        other <- jsonlite::fromJSON(jsonlite::toJSON(
          other, auto_unbox = TRUE, digits = NA
        ), simplifyVector = TRUE)
        if (!isTRUE(all.equal(json, other))) {
          cli::cli_warn(
            "Sidecar metadata differs between JSON and QS2 for {.file {rel_path}}; using JSON."
          )
        }
      }
    }
    return(json)
  }
  qs <- if (fs::file_exists(scq)) .st_sidecar_decode(.st_read_qs2(scq)) else NULL
  modern <- if (.st_sidecar_is_modern(json)) json else qs
  if (.st_sidecar_is_modern(modern)) {
    mode <- modern$attrs$stamp$sidecars
    if ((mode %in% c("json", "both") && is.null(json)) ||
        (mode %in% c("qs2", "both") && is.null(qs))) {
      cli::cli_abort("Required modern sidecar is unavailable.")
    }
  }
  if (!is.null(json) && !is.null(qs) &&
      (.st_sidecar_is_modern(json) || .st_sidecar_is_modern(qs))) {
    if (!identical(json$attrs$stamp, qs$attrs$stamp) ||
        !identical(json$semantic, qs$semantic) ||
        !identical(json$execution, qs$execution)) {
      cli::cli_abort("JSON and QS2 typed sidecars disagree.")
    }
  }
  return(json %||% qs)
}
