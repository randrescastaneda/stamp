# ---- Version store & catalog -------------------------------------------------

#' Normalize a path for use as an identifier (internal)
#'
#' Convert a path to an absolute, canonical character representation
#' suitable for deterministic hashing and use as an identifier.
#'
#' @param p Character path.
#' @return Character scalar absolute path.
#' @keywords internal
#' @noRd
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
#' @noRd
.st_artifact_id <- function(path) {
  secretbase::siphash13(.st_norm_path(path))
}

#' Versions root directory (internal)
#'
#' Return the path to the package-managed versions root directory
#' (under the package state directory) and ensure it exists.
#'
#' @return Character scalar directory path.
#' @keywords internal
#' @noRd
.st_versions_root <- function() {
  state_dir  <- st_state_get("state_dir", ".stamp")
  state_root <- st_state_get("state_root", fs::path_abs("."))

  state_base <- if (fs::is_absolute_path(state_dir)) state_dir else fs::path(state_root, state_dir)
  vs <- fs::path(state_base, "versions")
  .st_dir_create(vs)
  vs
}


#' Version directory for an artifact (internal)
#'
#' Compute the path to the version directory for `artifact_path` and
#' `version_id` under the versions root.
#'
#' @param artifact_path Path to the artifact file.
#' @param version_id Version identifier (character).
#' @return Character scalar path to the version directory.
#' @keywords internal
#' @noRd
.st_version_dir <- function(artifact_path, version_id) {
  rel <- fs::path_rel(.st_norm_path(artifact_path), start = fs::path_abs("."))
  fs::path(.st_versions_root(), rel, version_id)
}

# Catalog paths & IO

#' Catalog file path (internal)
#'
#' Return the path where the in-memory catalog is persisted.
#'
#' @return Character scalar path to the catalog file.
#' @keywords internal
#' @noRd
.st_catalog_path <- function() {
  state_dir  <- st_state_get("state_dir", ".stamp")
  state_root <- st_state_get("state_root", fs::path_abs("."))

  # If state_dir is not absolute, resolve it under state_root
  state_base <- if (fs::is_absolute_path(state_dir)) state_dir else fs::path(state_root, state_dir)

  fs::path(state_base, "catalog.qs2")
}


#' Empty catalog template (internal)
#'
#' Return an empty catalog structure compatible with the package's
#' catalog persistence format. The function prefers `data.table`
#' objects when available, otherwise falls back to base `data.frame`.
#'
#' @return A list with `artifacts` and `versions` tables.
#' @keywords internal
#' @noRd
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
#' Load the persisted catalog from disk if present, otherwise return an
#' empty catalog structure.
#'
#' @return Catalog list with `artifacts` and `versions`.
#' @keywords internal
#' @noRd
.st_catalog_read <- function() {
  p <- .st_catalog_path()
  if (fs::file_exists(p)) .st_read_qs2(p) else .st_catalog_empty()
}

#' Write catalog to disk (internal)
#'
#' Persist the in-memory `cat` to the catalog file location. Uses a
#' temporary file + move strategy to reduce risk of partial writes.
#'
#' @param cat Catalog object (list with `artifacts` and `versions`).
#' @return Invisibly returns `NULL`.
#' @keywords internal
#' @noRd
.st_catalog_write <- function(cat) {
  p <- .st_catalog_path()
  fs::dir_create(fs::path_dir(p), recurse = TRUE)
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(p), pattern = fs::path_file(p))
  .st_write_qs2(cat, tmp)
  if (fs::file_exists(p)) fs::file_delete(p)
  fs::file_move(tmp, p)
}

# Public API -------------------------------------------------------------

#' List versions for an artifact path
#'
#' Return the recorded versions for the artifact identified by
#' `path`. The result is returned as a `data.frame` or `data.table`
#' depending on available packages.
#'
#' @param path Character scalar path to the artifact file.
#' @return Table (data.frame or data.table) with rows for each
#'   recorded version, ordered by creation time (most recent first).
#' @examples
#' # st_versions("data/myfile.qs2")
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
#'
#' Return the `version_id` for the most recently recorded version of
#' the artifact identified by `path`, or `NA_character_` when no
#' versions exist for that artifact.
#'
#' @param path Character scalar path to the artifact file.
#' @return Character scalar `version_id` or `NA_character_`.
#' @examples
#' # st_latest("data/myfile.qs2")
#' @export
st_latest <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  art <- cat$artifacts[cat$artifacts$artifact_id == aid, , drop = FALSE]
  if (nrow(art) == 0L) return(NA_character_)
  art$latest_version_id[[1L]]
}

#' Load a specific version of an artifact
#'
#' Load the previously recorded version of an artifact from the
#' versions store. The function will locate the version directory and
#' dispatch to the appropriate format reader.
#'
#' @param path Character path of the artifact (used to infer format if needed).
#' @param version_id Character version identifier to load.
#' @param ... Additional arguments passed to the registered reader.
#' @return The artifact object as returned by the registered format reader.
#' @examples
#' # st_load_version("data/myfile.qs2", "20250101T000000Z-abcdef01")
#' @export
st_load_version <- function(path, version_id, ...) {
  vdir <- .st_version_dir(path, version_id)
  art  <- fs::path(vdir, "artifact")
  if (!fs::file_exists(art)) {
    cli::cli_abort("Version {.field {version_id}} not found for {.field {path}}.")
  }

  # infer format from original path; fall back to configured default
  fmt <- .st_guess_format(path) %||% st_opts("default_format", .get = TRUE)
  h   <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}} for version load.")
  }

  cli::cli_inform(c(
    "v" = "Loaded \u2190 {.field {path}} @ {.field {version_id}} [{.field {fmt}}]"
  ))
  h$read(art, ...)
}

# ---- Catalog update & version commit helpers ---------------------------------

#' Construct a compact version id (internal)
#'
#' Build a sortable version identifier based on `created_at` and an
#' optional short hash suffix derived from `content_hash` or
#' `code_hash`.
#'
#' @param created_at Character scalar timestamp (UTC) used as primary key.
#' @param content_hash Optional content hash (character).
#' @param code_hash Optional code hash (character).
#' @return Character scalar version id.
#' @keywords internal
#' @noRd
.st_version_id <- function(created_at, content_hash = NA_character_, code_hash = NA_character_) {
  ts <- gsub("[-:]", "", created_at, fixed = FALSE)
  ts <- gsub("Z$", "Z", ts) # keep the trailing Z
  h  <- if (!is.na(content_hash) && nzchar(content_hash)) content_hash else
        if (!is.na(code_hash)    && nzchar(code_hash))    code_hash    else ""
  if (nzchar(h)) sprintf("%s-%s", ts, substr(h, 1L, 8L)) else ts
}

#' Which sidecar formats exist for a path (internal)
#'
#' Check for the presence of sidecar metadata files for `path` and
#' return one of `"json"`, `"qs2"`, `"both"`, or `"none"`.
#'
#' @param path Character path of the artifact.
#' @return Character scalar indicating available sidecar formats.
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
#'
#' Copy the main artifact and any present sidecars into the computed
#' version directory. Files are copied (not moved) so the working
#' artifact remains in place.
#'
#' @param artifact_path Character path to the artifact file.
#' @param version_id Character version identifier.
#' @return Invisibly returns the version directory path.
#' @keywords internal
#' @noRd
.st_version_commit_files <- function(artifact_path, version_id) {
  # Copy artifact + available sidecars into: .stamp/versions/<rel-path>/<vid>/
  rel   <- fs::path_rel(fs::path_abs(artifact_path), start = fs::path_abs("."))
  vdir  <- fs::path(.st_versions_root(), rel, version_id)
  .st_dir_create(fs::path_dir(vdir))
  .st_dir_create(vdir)

  # write artifact copy
  fs::file_copy(artifact_path, fs::path(vdir, "artifact"), overwrite = TRUE)

  # copy sidecars if present
  scj <- .st_sidecar_path(artifact_path, "json")
  scq <- .st_sidecar_path(artifact_path, "qs2")
  if (fs::file_exists(scj)) fs::file_copy(scj, fs::path(vdir, "sidecar.json"), overwrite = TRUE)
  if (fs::file_exists(scq)) fs::file_copy(scq, fs::path(vdir, "sidecar.qs2"),  overwrite = TRUE)

  invisible(vdir)
}


#' Upsert artifact row in catalog (internal)
#'
#' Insert a new artifact row into the catalog or update the existing
#' row's `latest_version_id` and increment `n_versions`.
#'
#' @param cat Catalog list.
#' @param artifact_id Character artifact identifier.
#' @param path Character artifact path.
#' @param format Character format string.
#' @param latest_version_id Character latest version id.
#' @return Updated catalog list.
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
#'
#' Add a single version record to the catalog's versions table.
#'
#' @param cat Catalog list.
#' @param row A data.frame or list representing the new versions row.
#' @return Updated catalog list.
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
#'
#' High level helper that records a newly created version into the
#' catalog: appends a versions row, upserts the artifact row, and
#' persists the catalog.
#'
#' @param artifact_path Character path to the artifact file.
#' @param format Character format name for the artifact.
#' @param size_bytes Numeric size of the artifact in bytes.
#' @param content_hash Optional character content hash.
#' @param code_hash Optional character code hash.
#' @param created_at Character timestamp used for the version id.
#' @param sidecar_format Character indicating sidecar availability
#'   ("json", "qs2", "both", or "none").
#' @return Invisibly returns the chosen `version_id`.
#' @keywords internal
#' @noRd
# Create/append a version row and update artifact row; return version_id
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

  # upsert artifact
  idx_a <- which(cat$artifacts$artifact_id == aid)
  if (length(idx_a)) {
    cat$artifacts$path[idx_a]              <- .st_norm_path(artifact_path)
    cat$artifacts$format[idx_a]            <- format
    cat$artifacts$latest_version_id[idx_a] <- vid
    cat$artifacts$n_versions[idx_a]        <- cat$artifacts$n_versions[idx_a] + 1L
  } else {
    new_a <- data.frame(
      artifact_id = aid,
      path = .st_norm_path(artifact_path),
      format = format,
      latest_version_id = vid,
      n_versions = 1L,
      stringsAsFactors = FALSE
    )
    cat$artifacts <- rbind(cat$artifacts, new_a)
  }

  # append version
  new_v <- data.frame(
    version_id = vid,
    artifact_id = aid,
    content_hash = content_hash %||% NA_character_,
    code_hash    = code_hash %||% NA_character_,
    size_bytes   = as.numeric(size_bytes),
    created_at   = created_at,
    sidecar_format = sidecar_format,
    stringsAsFactors = FALSE
  )
  cat$versions <- rbind(cat$versions, new_v)

  .st_catalog_write(cat)
  vid
}


# Return the latest version row (or NULL) for an artifact path
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

