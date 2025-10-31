# ---- Version store & catalog -------------------------------------------------

#' Normalize a path for use as an identifier (internal)
#'
#' Convert a path to an absolute, canonical character representation
#' suitable for deterministic hashing and use as an identifier.
#'
#' @param p Character path.
#' @return Character scalar absolute path.
#' @keywords internal
.st_norm_path <- function(p) as.character(fs::path_abs(p))

#' Compute artifact identifier (internal)
#'
#' Derive an artifact identifier from `path` using a stable SipHash
#' of the normalized path. This identifier is used to group versions
#' belonging to the same logical artifact.
#'
#' @param path Character path to the artifact.
#' @return Character scalar identifier.
#' @keywords internal
.st_artifact_id <- function(path) {
  secretbase::siphash13(.st_norm_path(path))
}

# Root/state helpers -----------------------------------------------------------

#' Project root directory recorded by st_init() (internal)
#'
#' Return the absolute project root directory previously recorded by
#' `st_init()`. If not set, defaults to the current working directory.
#'
#' @return Character scalar absolute path to project root.
#' @keywords internal
.st_root_dir <- function() {
  st_state_get("root_dir", fs::path_abs("."))
}

# Absolute state dir: <root>/<state_dir>
#' Absolute state directory path (internal)
#'
#' Compute the absolute path to the package state directory. This is
#' constructed as <root>/<state_dir> where `root` is from
#' `st_init()` and `state_dir` is an option stored in the package state.
#'
#' @return Character scalar absolute path to the state directory.
#' @keywords internal
.st_state_dir_abs <- function() {
  fs::path(.st_root_dir(), st_state_get("state_dir", ".stamp"))
}

#' Versions root directory (internal)
#'
#' Return the versions root directory under the package state directory
#' (i.e. <root>/<state_dir>/versions). The directory is created if it
#' does not already exist.
#'
#' @return Character scalar path to the versions root directory.
#' @keywords internal
.st_versions_root <- function() {
  vs <- fs::path(.st_state_dir_abs(), "versions")
  .st_dir_create(vs)
  vs
}

#' Version directory for an artifact (internal)
#'
#' Compute the version directory path for `artifact_path` and `version_id`
#' under <root>/<state_dir>/versions. We store snapshots under the *relative*
#' artifact path from root; if the artifact is outside the root, we fall back
#' to the artifact's basename to avoid exploding the versions tree.
#'
#' @param artifact_path Path to the artifact file.
#' @param version_id Version identifier (character).
#' @return Character scalar path to the version directory.
#' @keywords internal
.st_version_dir <- function(artifact_path, version_id) {
  ap_abs <- .st_norm_path(artifact_path)
  rd     <- .st_root_dir()

  rel <- tryCatch(
    fs::path_rel(ap_abs, start = rd),
    error = function(e) fs::path_file(ap_abs)
  )

  fs::path(.st_versions_root(), rel, version_id)
}

# Catalog paths & IO -----------------------------------------------------------

#' Catalog file path (internal)
#'
#' Return the path to the on-disk catalog file under the package state
#' directory: <root>/<state_dir>/catalog.qs2
#'
#' @return Character scalar path to the catalog file.
#' @keywords internal
.st_catalog_path <- function() {
  fs::path(.st_state_dir_abs(), "catalog.qs2")
}

#' Empty catalog template (internal)
#'
#' Create an empty catalog structure used when no catalog file exists on
#' disk. The structure contains `artifacts` and `versions` tables and will
#' use `data.table` if available, otherwise base `data.frame`.
#'
#' @return A list with elements `artifacts` and `versions` (data.frame or data.table).
#' @keywords internal
.st_catalog_empty <- function() {
  if (requireNamespace("data.table", quietly = TRUE)) {
    list(
      artifacts = data.table::data.table(
        artifact_id = character(), path = character(), format = character(),
        latest_version_id = character(), n_versions = integer()
      ),
      versions = data.table::data.table(
        version_id = character(), artifact_id = character(),
        content_hash = character(), code_hash = character(),
        size_bytes = numeric(), created_at = character(), sidecar_format = character()
      )
    )
  } else {
    list(
      artifacts = data.frame(
        artifact_id = character(), path = character(), format = character(),
        latest_version_id = character(), n_versions = integer(), stringsAsFactors = FALSE
      ),
      versions = data.frame(
        version_id = character(), artifact_id = character(),
        content_hash = character(), code_hash = character(),
        size_bytes = numeric(), created_at = character(), sidecar_format = character(),
        stringsAsFactors = FALSE
      )
    )
  }
}

#' Read catalog from disk (internal)
#'
#' Read the persisted catalog from the on-disk catalog file. If the file
#' does not exist, an empty catalog template is returned.
#'
#' @return A list with elements `artifacts` and `versions`.
#' @keywords internal
.st_catalog_read <- function() {
  p <- .st_catalog_path()
  if (fs::file_exists(p)) .st_read_qs2(p) else .st_catalog_empty()
}

#' Write catalog to disk (internal)
#'
#' Persist the catalog list to disk using a QS2-backed format. The write
#' is performed atomically by writing to a temporary file in the same
#' directory and then moving it into place.
#'
#' @param cat Catalog list to persist (with `artifacts` and `versions`).
#' @return Invisible path to the catalog file.
#' @keywords internal
.st_catalog_write <- function(cat) {
  p <- .st_catalog_path()
  fs::dir_create(fs::path_dir(p), recurse = TRUE)
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(p), pattern = fs::path_file(p))
  .st_write_qs2(cat, tmp)
  if (fs::file_exists(p)) fs::file_delete(p)
  fs::file_move(tmp, p)
}

# Public API -------------------------------------------------------------------

#' List versions for an artifact path
#' @export
st_versions <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  ver <- if (isTRUE(requireNamespace("data.table", quietly = TRUE))) {
    data.table::as.data.table(cat$versions)
  } else cat$versions

  out <- ver[ver$artifact_id == aid, , drop = FALSE]
  if (nrow(out) == 0L) return(out)
  out[order(out$created_at, decreasing = TRUE), , drop = FALSE]
}

#' Get the latest version_id for an artifact path
#' @export
st_latest <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  art <- cat$artifacts[cat$artifacts$artifact_id == aid, , drop = FALSE]
  if (nrow(art) == 0L) return(NA_character_)
  art$latest_version_id[[1L]]
}

#' Load a specific version of an artifact
#' @export
st_load_version <- function(path, version_id, ...) {
  vdir <- .st_version_dir(path, version_id)
  art  <- fs::path(vdir, "artifact")
  if (!fs::file_exists(art)) {
    cli::cli_abort("Version {.field {version_id}} not found for {.field {path}}.")
  }

  fmt <- .st_guess_format(path) %||% st_opts("default_format", .get = TRUE)
  h   <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}} for version load.")
  }

  cli::cli_inform(c("v" = "Loaded \u2190 {.field {path}} @ {.field {version_id}} [{.field {fmt}}]"))
  h$read(art, ...)
}

# ---- Catalog update & version commit helpers ---------------------------------

#' Construct a compact version id (internal)
#' @keywords internal
#' @noRd
.st_version_id <- function(created_at, content_hash = NA_character_, code_hash = NA_character_) {
  ts <- gsub("[-:]", "", created_at, fixed = FALSE)
  ts <- gsub("Z$", "Z", ts)
  h  <- if (!is.na(content_hash) && nzchar(content_hash)) content_hash else
        if (!is.na(code_hash)    && nzchar(code_hash))    code_hash    else ""
  if (nzchar(h)) sprintf("%s-%s", ts, substr(h, 1L, 8L)) else ts
}

#' Which sidecar formats exist for a path (internal)
#' @keywords internal
#' @noRd
.st_sidecar_present <- function(path) {
  scj <- .st_sidecar_path(path, "json")
  scq <- .st_sidecar_path(path, "qs2")
  has_j <- fs::file_exists(scj)
  has_q <- fs::file_exists(scq)
  if (has_j && has_q) return("both")
  if (has_j)          return("json")
  if (has_q)          return("qs2")
  "none"
}

#' Copy artifact and sidecars into version directory (internal)
#' @keywords internal
#' @noRd
.st_version_commit_files <- function(artifact_path, version_id, parents = NULL) {
  rel   <- fs::path_rel(fs::path_abs(artifact_path), start = fs::path_abs("."))
  vdir  <- fs::path(.st_versions_root(), rel, version_id)
  .st_dir_create(fs::path_dir(vdir))
  .st_dir_create(vdir)

  # artifact copy
  fs::file_copy(artifact_path, fs::path(vdir, "artifact"), overwrite = TRUE)

  # sidecars (if present)
  scj <- .st_sidecar_path(artifact_path, "json")
  scq <- .st_sidecar_path(artifact_path, "qs2")
  if (fs::file_exists(scj)) fs::file_copy(scj, fs::path(vdir, "sidecar.json"), overwrite = TRUE)
  if (fs::file_exists(scq)) fs::file_copy(scq, fs::path(vdir, "sidecar.qs2"),  overwrite = TRUE)

  # parents snapshot
  .st_version_write_parents(vdir, parents)

  invisible(vdir)
}

.st_version_dir_latest <- function(path) {
  vid <- st_latest(path)
  if (is.na(vid)) return(NA_character_)
  .st_version_dir(path, vid)
}


#' Upsert artifact row in catalog (internal)
#' @keywords internal
#' @noRd
.st_catalog_upsert_artifact <- function(cat, artifact_id, path, format, latest_version_id) {
  if (isTRUE(requireNamespace("data.table", quietly = TRUE))) {
    a <- data.table::as.data.table(cat$artifacts)
    idx <- which(a$artifact_id == artifact_id)
    if (length(idx) == 0L) {
      a <- data.table::rbindlist(list(
        a,
        data.table::data.table(
          artifact_id = artifact_id,
          path = as.character(path),
          format = format,
          latest_version_id = latest_version_id,
          n_versions = 1L
        )
      ), use.names = TRUE, fill = TRUE)
    } else {
      a$latest_version_id[idx] <- latest_version_id
      a$n_versions[idx]        <- a$n_versions[idx] + 1L
    }
    cat$artifacts <- a[]
  } else {
    a <- cat$artifacts
    idx <- which(a$artifact_id == artifact_id)
    if (length(idx) == 0L) {
      a <- rbind(
        a,
        data.frame(
          artifact_id = artifact_id,
          path = as.character(path),
          format = format,
          latest_version_id = latest_version_id,
          n_versions = 1L,
          stringsAsFactors = FALSE
        ),
        make.row.names = FALSE
      )
    } else {
      a$latest_version_id[idx] <- latest_version_id
      a$n_versions[idx]        <- a$n_versions[idx] + 1L
    }
    cat$artifacts <- a
  }
  cat
}

#' Append a version row to the catalog (internal)
#' @keywords internal
#' @noRd
.st_catalog_append_version <- function(cat, row) {
  if (isTRUE(requireNamespace("data.table", quietly = TRUE))) {
    v <- data.table::as.data.table(cat$versions)
    v <- data.table::rbindlist(list(v, data.table::as.data.table(row)), use.names = TRUE, fill = TRUE)
    cat$versions <- v[]
  } else {
    v <- cat$versions
    v <- rbind(v, row, make.row.names = FALSE)
    cat$versions <- v
  }
  cat
}

#' Record a new version in the catalog (internal)
#' @keywords internal
#' @noRd
.st_catalog_record_version <- function(artifact_path,
                                       format,
                                       size_bytes,
                                       content_hash,
                                       code_hash,
                                       created_at,
                                       sidecar_format) {
  aid <- .st_artifact_id(artifact_path)
  vid <- secretbase::siphash13(
    paste(aid, content_hash %||% "", code_hash %||% "", created_at %||% "", sep = "|")
  )

  cat <- .st_catalog_read()

  # upsert artifact row
  idx_a <- which(cat$artifacts$artifact_id == aid)
  if (length(idx_a)) {
    cat$artifacts$path[idx_a]              <- .st_norm_path(artifact_path)
    cat$artifacts$format[idx_a]            <- format
    cat$artifacts$latest_version_id[idx_a] <- vid
    cat$artifacts$n_versions[idx_a]        <- cat$artifacts$n_versions[idx_a] + 1L
  } else {
    new_a <- data.frame(
      artifact_id      = aid,
      path             = .st_norm_path(artifact_path),
      format           = format,
      latest_version_id= vid,
      n_versions       = 1L,
      stringsAsFactors = FALSE
    )
    cat$artifacts <- rbind(cat$artifacts, new_a)
  }

  # append version row
  new_v <- data.frame(
    version_id     = vid,
    artifact_id    = aid,
    content_hash   = content_hash %||% NA_character_,
    code_hash      = code_hash %||% NA_character_,
    size_bytes     = as.numeric(size_bytes),
    created_at     = created_at,
    sidecar_format = sidecar_format,
    stringsAsFactors = FALSE
  )
  cat$versions <- rbind(cat$versions, new_v)

  .st_catalog_write(cat)
  vid
}

# Return the latest version row (or NULL) for an artifact path
#' Retrieve the latest version row for an artifact (internal)
#'
#' Return the latest version record (a single-row data.frame or data.table)
#' for the artifact identified by `path`. If no artifact or version exists,
#' `NULL` is returned.
#'
#' @param path Path to the artifact.
#' @return A single-row `data.frame`/`data.table` with the version metadata, or `NULL`.
#' @keywords internal
.st_catalog_latest_version_row <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  art <- cat$artifacts[cat$artifacts$artifact_id == aid, , drop = FALSE]
  if (!nrow(art)) return(NULL)
  vid <- art$latest_version_id[[1L]]
  ver <- cat$versions[cat$versions$version_id == vid, , drop = FALSE]
  if (!nrow(ver)) return(NULL)
  ver[1L, , drop = FALSE]
}


# --- Provenance snapshot files inside each version dir ------------------------

# parents is a list of parent descriptors:
#   list(list(path = "<abs-or-rel>", version_id = "<id>"), ...)
# We'll store it as JSON for readability + diffs.
#' Write parents metadata for a version (internal)
#'
#' Persist the list of parent descriptors for a version as JSON inside the
#' version directory. The function performs an atomic write to avoid
#' partial files on disk.
#'
#' @param version_dir Path to the version directory where parents.json will be written.
#' @param parents List of parent descriptors (each a list with `path` and `version_id`).
#' @return Invisibly `NULL`.
#' @keywords internal
.st_version_write_parents <- function(version_dir, parents) {
  if (is.null(parents) || !length(parents)) return(invisible(NULL))
  fs::dir_create(version_dir, recurse = TRUE)
  pfile <- fs::path(version_dir, "parents.json")
  tmp   <- fs::file_temp(tmp_dir = fs::path_dir(pfile), pattern = fs::path_file(pfile))
  jsonlite::write_json(parents, tmp, auto_unbox = TRUE, pretty = TRUE, digits = NA)
  if (fs::file_exists(pfile)) fs::file_delete(pfile)
  fs::file_move(tmp, pfile)
  invisible(NULL)
}

#' Read parents metadata for a version (internal)
#'
#' Read and return the parents metadata stored in `parents.json` inside the
#' given `version_dir`. If no parents file exists an empty list is returned.
#'
#' @param version_dir Path to the version directory.
#' @return List of parent descriptors, or an empty list.
#' @keywords internal
.st_version_read_parents <- function(version_dir) {
  pfile <- fs::path(version_dir, "parents.json")
  if (!fs::file_exists(pfile)) return(list())
  jsonlite::read_json(pfile, simplifyVector = TRUE)
}

