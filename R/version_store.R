# ---- Version store & catalog -------------------------------------------------

# Normalize path string for IDs
.st_norm_path <- function(p) as.character(fs::path_abs(p))

# Artifact ID derived ONLY from the normalized path using siphash13
.st_artifact_id <- function(path) {
  secretbase::siphash13(.st_norm_path(path))
}

# Versions root: <state_dir>/versions
.st_versions_root <- function() {
  vs <- fs::path(st_state_get("state_dir", ".stamp"), "versions")
  .st_dir_create(vs)
  vs
}

# Version directory for an artifact path + version_id
.st_version_dir <- function(artifact_path, version_id) {
  rel <- fs::path_rel(.st_norm_path(artifact_path), start = fs::path_abs("."))
  fs::path(.st_versions_root(), rel, version_id)
}

# Catalog paths & IO
.st_catalog_path <- function() {
  fs::path(st_state_get("state_dir", ".stamp"), "catalog.qs2")
}

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

.st_catalog_read <- function() {
  p <- .st_catalog_path()
  if (fs::file_exists(p)) .st_read_qs2(p) else .st_catalog_empty()
}

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
#' @param path File path of the artifact (used to infer format if needed)
#' @param version_id Version identifier to load
#' @param ... Passed to the registered reader
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

# Construct a compact version_id:
# - primary = UTC timestamp (sortable)
# - optional suffix = first 8 chars of a hash (content_hash or code_hash) if present
.st_version_id <- function(created_at, content_hash = NA_character_, code_hash = NA_character_) {
  ts <- gsub("[-:]", "", created_at, fixed = FALSE)
  ts <- gsub("Z$", "Z", ts) # keep the trailing Z
  h  <- if (!is.na(content_hash) && nzchar(content_hash)) content_hash else
        if (!is.na(code_hash)    && nzchar(code_hash))    code_hash    else ""
  if (nzchar(h)) sprintf("%s-%s", ts, substr(h, 1L, 8L)) else ts
}

# Determine which sidecar formats currently exist for an artifact,
# return a scalar string "json" | "qs2" | "both" | "none"
.st_sidecar_present <- function(path) {
  p_json <- fs::file_exists(.st_sidecar_path(path, "json"))
  p_qs2  <- fs::file_exists(.st_sidecar_path(path, "qs2"))
  if (p_json && p_qs2) "both" else if (p_json) "json" else if (p_qs2) "qs2" else "none"
}

# Copy the just-written artifact & its sidecars into a version directory.
# Files are copied, not moved, so the working artifact remains in place.
.st_version_commit_files <- function(artifact_path, version_id) {
  vdir <- .st_version_dir(artifact_path, version_id)
  .st_dir_create(fs::path_dir(vdir))          # ensure parent tree exists
  .st_dir_create(vdir)

  # Copy main artifact to "<vdir>/artifact"
  dst_art <- fs::path(vdir, "artifact")
  fs::file_copy(artifact_path, dst_art, overwrite = TRUE)

  # Copy any present sidecars into "<vdir>/sidecar.*"
  sc_json <- .st_sidecar_path(artifact_path, "json")
  sc_qs2  <- .st_sidecar_path(artifact_path, "qs2")
  if (fs::file_exists(sc_json)) {
    fs::file_copy(sc_json, fs::path(vdir, "sidecar.json"), overwrite = TRUE)
  }
  if (fs::file_exists(sc_qs2)) {
    fs::file_copy(sc_qs2,  fs::path(vdir, "sidecar.qs2"),  overwrite = TRUE)
  }

  invisible(vdir)
}

# Upsert artifacts row and bump counters
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

# Append one row into versions table
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

# High-level: create & record a new version
# Returns the chosen version_id (invisibly).
.st_catalog_record_version <- function(artifact_path,
                                       format,
                                       size_bytes,
                                       content_hash = NA_character_,
                                       code_hash    = NA_character_,
                                       created_at   = .st_now_utc(),
                                       sidecar_format = .st_sidecar_present(artifact_path)) {
  aid <- .st_artifact_id(artifact_path)
  vid <- .st_version_id(created_at, content_hash, code_hash)

  # Read, update, write catalog
  cat <- .st_catalog_read()
  row <- data.frame(
    version_id     = vid,
    artifact_id    = aid,
    content_hash   = as.character(ifelse(is.na(content_hash), "", content_hash)),
    code_hash      = as.character(ifelse(is.na(code_hash),    "", code_hash)),
    size_bytes     = as.numeric(size_bytes),
    created_at     = created_at,
    sidecar_format = sidecar_format,
    stringsAsFactors = FALSE
  )
  cat <- .st_catalog_append_version(cat, row)
  cat <- .st_catalog_upsert_artifact(cat, aid, artifact_path, format, vid)
  .st_catalog_write(cat)

  invisible(vid)
}
