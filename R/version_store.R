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
#' to a collision-free identifier based on the artifact's unique ID.
#'
#' @param artifact_path Path to the artifact file.
#' @param version_id Version identifier (character).
#' @return Character scalar path to the version directory, or NA if version_id is NA/empty.
#' @keywords internal
.st_version_dir <- function(artifact_path, version_id) {
  if (is.na(version_id) || !length(version_id) || !nzchar(version_id)) {
    return(NA_character_)
  }
  ap_abs <- .st_norm_path(artifact_path)
  rd <- .st_root_dir()

  rel <- tryCatch(
    as.character(fs::path_rel(ap_abs, start = rd)),
    error = function(e) NULL
  )

  if (is.null(rel) || identical(rel, ".") || !nzchar(rel)) {
    # Use artifact ID (hash of absolute path) to ensure collision-free storage
    aid <- .st_artifact_id(ap_abs)
    basename <- fs::path_file(ap_abs)
    rel <- fs::path("external", paste0(substr(aid, 1, 8), "-", basename))
  }

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
  list(
    artifacts = data.table(
      artifact_id = character(),
      path = character(),
      format = character(),
      latest_version_id = character(),
      n_versions = integer()
    ),
    versions = data.table(
      version_id = character(),
      artifact_id = character(),
      content_hash = character(),
      code_hash = character(),
      size_bytes = numeric(),
      created_at = character(),
      sidecar_format = character()
    )
  )
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
  cat <- if (fs::file_exists(p)) .st_read_qs2(p) else .st_catalog_empty()
  # Coerce to data.table invariant if loaded catalog used older data.frame layout
  if (!is.data.table(cat$artifacts)) {
    cat$artifacts <- as.data.table(cat$artifacts)
  }
  if (!is.data.table(cat$versions)) {
    cat$versions <- as.data.table(cat$versions)
  }
  cat
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
  if (fs::file_exists(p)) {
    fs::file_delete(p)
  }
  fs::file_move(tmp, p)
}

# Public API -------------------------------------------------------------------

#' List versions for an artifact path
#'
#' Return a table of recorded versions for the artifact identified by
#' `path` from the catalog. When `data.table` is available the result is a
#' `data.table`; otherwise a base `data.frame` is returned. The table contains
#' one row per recorded version with the columns described below. Rows are
#' ordered by `created_at` descending.
#'
#' @inheritParams st_path
#' @return A `data.frame` or `data.table` with columns:
#'   \item{version_id}{Character version identifier.}
#'   \item{artifact_id}{Character artifact identifier (hashed).}
#'   \item{content_hash}{Character content hash for the version (may be NA).}
#'   \item{code_hash}{Character code hash for the version (may be NA).}
#'   \item{size_bytes}{Numeric size of the stored artifact in bytes.}
#'   \item{created_at}{Character ISO8601 timestamp when the version was recorded.}
#'   \item{sidecar_format}{Character sidecar format present: "json", "qs2", "both", or "none".}
#' An empty table is returned when no versions exist for the given path.
#' @export
st_versions <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  ver <- cat$versions

  required_cols <- c(
    "version_id",
    "artifact_id",
    "content_hash",
    "code_hash",
    "size_bytes",
    "created_at",
    "sidecar_format"
  )
  miss <- setdiff(required_cols, names(ver))
  if (length(miss)) {
    cli::cli_abort(
      c(
        "Catalog schema mismatch in versions table.",
        "x" = "Missing columns: {toString(miss)}"
      )
    )
  }

  out <- ver[artifact_id == aid]
  if (nrow(out) == 0L) {
    return(out)
  }

  # created_at coercion (handle accidental list columns)
  if (is.list(out$created_at)) {
    out[,
      created_at := vapply(
        created_at,
        function(x) {
          if (is.null(x) || !length(x)) {
            return(NA_character_)
          }
          as.character(if (is.list(x) && length(x) == 1L) x[[1L]] else x)
        },
        character(1L)
      )
    ]
  } else {
    out[, created_at := as.character(created_at)]
  }

  # Drop corrupt rows
  bad <- is.na(out$created_at) | !nzchar(out$created_at)
  if (any(bad)) {
    dropped <- sum(bad)
    cli::cli_warn(c(
      "Dropped {dropped} corrupt version row{?s} with invalid created_at.",
      "i" = "Recreate versions if needed; catalog retained."
    ))
    out <- out[!bad]
  }
  if (nrow(out) == 0L) {
    return(out) # empty data.table
  }

  setorder(out, -created_at, -version_id)
  out
}

#' Get the latest version_id for an artifact path
#' @inheritParams st_path
#' @export
st_latest <- function(path) {
  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()
  art <- cat$artifacts[artifact_id == aid]
  if (nrow(art) == 0L) {
    return(NA_character_)
  }
  v <- art$latest_version_id[[1L]]
  if (is.null(v) || !length(v) || is.na(v) || !nzchar(as.character(v))) {
    return(NA_character_)
  }
  as.character(v)
}

#' Resolve version specification to a concrete version_id (internal)
#'
#' @param path artifact path
#' @param version NULL (latest), integer (relative), character (specific version ID), 
#'   or "select"/"pick"/"choose" to show interactive menu
#' @return character version_id or NA_character_
#' @keywords internal
.st_resolve_version <- function(path, version = NULL) {
  # NULL or 0 -> latest
  if (is.null(version) || (is.numeric(version) && version == 0)) {
    return(st_latest(path))
  }
  
  # Positive integers are not allowed
  if (is.numeric(version) && version > 0) {
    cli::cli_abort(c(
      "x" = "Positive version numbers are not allowed.",
      "i" = "Use NULL for latest, 0 for current, or negative integers for relative versions."
    ))
  }
  
  # Negative integers: relative to latest
  if (is.numeric(version) && version < 0) {
    vers <- st_versions(path)
    if (nrow(vers) == 0L) {
      cli::cli_abort("No versions found for {.file {path}}")
    }
    
    # vers is already sorted by created_at descending (newest first)
    # version=-1 means "one version back from latest" -> index 2
    # version=-2 means "two versions back from latest" -> index 3
    idx <- abs(version) + 1L
    if (idx > nrow(vers)) {
      cli::cli_abort(c(
        "x" = "Version index {version} goes beyond available versions.",
        "i" = "Only {nrow(vers)} version{?s} available for {.file {path}}"
      ))
    }
    
    return(as.character(vers$version_id[idx]))
  }
  
  # Character: check for interactive menu request or specific version ID
  if (is.character(version)) {
    vers <- st_versions(path)
    if (nrow(vers) == 0L) {
      cli::cli_abort("No versions found for {.file {path}}")
    }
    
    # Interactive menu
    if (tolower(version) %in% c("select", "pick", "choose")) {
      if (!interactive()) {
        cli::cli_abort(c(
          "x" = "Interactive menu requested but session is not interactive.",
          "i" = "Specify a version explicitly or use NULL for latest."
        ))
      }
      
      # Build menu choices with formatted dates and metadata
      choices <- character(nrow(vers))
      for (i in seq_len(nrow(vers))) {
        row <- vers[i, ]
        # Format timestamp - handle both old (seconds) and new (microseconds) formats
        ts <- tryCatch({
          # Try parsing with microseconds first
          dt <- as.POSIXct(row$created_at, format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
          if (is.na(dt)) {
            # Fallback to seconds-only format for backward compatibility
            dt <- as.POSIXct(row$created_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
          }
          format(dt, "%Y-%m-%d %H:%M:%OS3")  # Display with milliseconds
        },
        error = function(e) row$created_at
        )
        # Format size
        size_mb <- round(as.numeric(row$size_bytes) / (1024^2), 2)
        # Construct choice string
        choices[i] <- sprintf("[%d] %s (%.2f MB) - %s", 
                              i, ts, size_mb, substr(row$version_id, 1, 16))
      }
      
      # Show menu
      cli::cli_inform(c(
        "i" = "Select a version to load from {.file {path}}:",
        " " = "Latest version is [1]"
      ))
      
      selection <- utils::menu(choices, title = "Available versions:")
      
      if (selection == 0) {
        cli::cli_abort("Version selection cancelled by user.")
      }
      
      return(as.character(vers$version_id[selection]))
    }
    
    # Specific version ID
    if (!version %in% vers$version_id) {
      cli::cli_abort(c(
        "x" = "Version {.val {version}} not found for {.file {path}}",
        "i" = "Use {.fn st_versions} to see available versions or 'select' for a menu."
      ))
    }
    
    return(as.character(version))
  }
  
  cli::cli_abort("Invalid version specification: {.val {version}}")
}


#' Load a specific version of an artifact
#'
#' Load a previously committed snapshot for an artifact identified by
#' `path` and `version_id`. The artifact file for the requested version is
#' read from the version snapshot directory using the format-specific
#' read handler registered in the package. This is useful for inspecting or
#' restoring historical versions of artifacts.
#'
#' The function will abort if the requested version snapshot does not
#' exist or if there is no registered format handler for the artifact's
#' format.
#'
#' @param path Character path to the artifact (same value used with `st_save`/`st_load`).
#' @param version_id Character version identifier (as returned by `st_save` or present in the catalog).
#' @param ... Additional arguments forwarded to the format's read function (e.g. `read` options).
#' @return The object produced by the format-specific read handler (typically an R object loaded from disk).
#' @examples
#' \dontrun{
#' # load a historical version of a dataset
#' old <- st_load_version("data/cleaned.rds", "20250101T000000Z-abcdef01")
#' }
#' @export
st_load_version <- function(path, version_id, ...) {
  vdir <- .st_version_dir(path, version_id)
  art <- fs::path(vdir, "artifact")
  if (!fs::file_exists(art)) {
    cli::cli_abort(
      "Version {.field {version_id}} not found for {.field {path}}."
    )
  }

  fmt <- .st_guess_format(path) %||% st_opts("default_format", .get = TRUE)
  h <- rlang::env_get(.st_formats_env, fmt, default = NULL)
  if (is.null(h)) {
    cli::cli_abort("Unknown format {.field {fmt}} for version load.")
  }

  # Read the artifact with the registered reader
  res <- h$read(art, ...)

  # Restore original tabular format if it was a data.table at save time
  if (
    is.data.frame(res) &&
      !is.null(attr(res, "st_original_format")) &&
      "data.table" %in% attr(res, "st_original_format")
  ) {
    res <- as.data.table(res)
  }

  # Remove st_original_format attribute (internal marker, not part of user object)
  if (!is.null(attr(res, "st_original_format"))) {
    if (inherits(res, "data.table")) {
      setattr(res, "st_original_format", NULL)
    } else {
      attr(res, "st_original_format") <- NULL
    }
  }

  # Remove stamp_sanitized attribute (not part of user-visible object) after any verification
  if (!is.null(attr(res, "stamp_sanitized"))) {
    if (inherits(res, "data.table")) {
      setattr(res, "stamp_sanitized", NULL)
    } else {
      attr(res, "stamp_sanitized") <- NULL
    }
  }

  cli::cli_inform(c(
    "v" = "Loaded \u2190 {.field {path}} @ {.field {version_id}} [{.field {fmt}}]"
  ))
  res
}

#' Show immediate or recursive parents for an artifact
#' @param path Artifact path (child)
#' @param depth Integer depth >= 1. Use Inf to walk recursively.
#' @return data.frame with columns: level, child_path, child_version, parent_path, parent_version
#' @export
st_lineage <- function(path, depth = 1L) {
  stopifnot(is.numeric(depth), depth >= 1)
  visited <- list()
  rows <- list()

  walk <- function(child_path, child_vid, level) {
    if (level > depth) {
      return(invisible(NULL))
    }
    vdir <- .st_version_dir(child_path, child_vid)
    # Prefer committed parents.json in the version snapshot. If not present
    # and we're at the first level, fall back to the artifact sidecar parents
    # for convenience. Recursive walking beyond level 1 will only use
    # snapshot-backed parents to preserve reproducible lineage traversal.
    parents <- .st_version_read_parents(vdir)
    if (!length(parents) && level == 1L) {
      sc <- tryCatch(st_read_sidecar(child_path), error = function(e) NULL)
      if (is.list(sc) && length(sc$parents)) {
        parents <- .st_parents_normalize(sc$parents)
      }
    }

    if (!length(parents)) {
      return(invisible(NULL))
    }
    for (p in parents) {
      rows[[length(rows) + 1L]] <<- data.frame(
        level = level,
        child_path = .st_norm_path(child_path),
        child_version = child_vid,
        parent_path = .st_norm_path(p$path),
        parent_version = p$version_id,
        stringsAsFactors = FALSE
      )
      key <- paste(.st_norm_path(p$path), p$version_id, sep = "@")
      if (!isTRUE(visited[[key]])) {
        visited[[key]] <<- TRUE
        walk(p$path, p$version_id, level + 1L)
      }
    }
  }

  vid <- st_latest(path)
  if (is.na(vid)) {
    return(data.frame(
      level = integer(),
      child_path = character(),
      child_version = character(),
      parent_path = character(),
      parent_version = character(),
      stringsAsFactors = FALSE
    ))
  }

  walk(path, vid, 1L)
  if (!length(rows)) {
    return(data.frame(
      level = integer(),
      child_path = character(),
      child_version = character(),
      parent_path = character(),
      parent_version = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  out[order(out$level), , drop = FALSE]
}


# ---- Catalog update & version commit helpers ---------------------------------

#' Construct a compact version id (internal)
#' @keywords internal
#' @noRd
.st_version_id <- function(
  created_at,
  content_hash = NA_character_,
  code_hash = NA_character_
) {
  # Remove dashes, colons, and periods to create compact timestamp
  # E.g., "2025-10-30T15:42:07.123456Z" -> "20251030T154207123456Z"
  ts <- gsub("[-:.]", "", created_at, fixed = FALSE)
  ts <- gsub("Z$", "Z", ts)
  h <- if (!is.na(content_hash) && nzchar(content_hash)) {
    content_hash
  } else if (!is.na(code_hash) && nzchar(code_hash)) {
    code_hash
  } else {
    ""
  }
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
  if (has_j && has_q) {
    return("both")
  }
  if (has_j) {
    return("json")
  }
  if (has_q) {
    return("qs2")
  }
  "none"
}

#' Commit artifact and sidecars into a version snapshot (internal)
#'
#' Copy the artifact file, any sidecars, and write the parents snapshot into
#' the version directory for the given `version_id`.
#'
#' @param artifact_path Path to the artifact file on disk.
#' @param version_id Version identifier for the snapshot.
#' @param parents Optional list of parent descriptors to write into parents.json.
#' @return Invisibly returns the version directory path.
#' @keywords internal
.st_version_commit_files <- function(
  artifact_path,
  version_id,
  parents = NULL
) {
  # Use the *same* path logic as consumers:
  vdir <- .st_version_dir(artifact_path, version_id)
  .st_dir_create(fs::path_dir(vdir))
  .st_dir_create(vdir)

  # artifact copy
  fs::file_copy(artifact_path, fs::path(vdir, "artifact"), overwrite = TRUE)

  # sidecars (if present)
  scj <- .st_sidecar_path(artifact_path, "json")
  scq <- .st_sidecar_path(artifact_path, "qs2")
  if (fs::file_exists(scj)) {
    fs::file_copy(scj, fs::path(vdir, "sidecar.json"), overwrite = TRUE)
  }
  if (fs::file_exists(scq)) {
    fs::file_copy(scq, fs::path(vdir, "sidecar.qs2"), overwrite = TRUE)
  }

  # parents snapshot
  .st_version_write_parents(vdir, parents)

  invisible(vdir)
}


.st_version_dir_latest <- function(path) {
  vid <- st_latest(path)
  # vid may be NA or empty; guard accordingly
  if (is.null(vid) || is.na(vid) || !nzchar(as.character(vid))) {
    return(NA_character_)
  }
  vdir <- .st_version_dir(path, as.character(vid))
  if (is.na(vdir) || !nzchar(vdir)) {
    return(NA_character_)
  }
  if (fs::dir_exists(vdir)) vdir else NA_character_
}


#' Upsert artifact row in catalog (internal)
#' @keywords internal
#' @noRd
.st_catalog_upsert_artifact <- function(
  cat,
  artifact_id,
  path,
  format,
  latest_version_id
) {
  a <- cat$artifacts
  idx <- which(a$artifact_id == artifact_id)
  if (!length(idx)) {
    a <- rbindlist(
      list(
        a,
        data.table(
          artifact_id = artifact_id,
          path = as.character(path),
          format = format,
          latest_version_id = latest_version_id,
          n_versions = 1L
        )
      ),
      use.names = TRUE,
      fill = TRUE
    )
  } else {
    a$latest_version_id[idx] <- latest_version_id
    a$n_versions[idx] <- a$n_versions[idx] + 1L
  }
  cat$artifacts <- a
  cat
}

#' Append a version row to the catalog (internal)
#' @keywords internal
#' @noRd
.st_catalog_append_version <- function(cat, row) {
  v <- cat$versions
  v <- rbindlist(list(v, as.data.table(row)), use.names = TRUE, fill = TRUE)
  cat$versions <- v
  cat
}

#' Record a new version in the catalog (internal)
#' @keywords internal
#' Record a new version in the catalog (internal)
#'
#' Adds a new version row to the catalog for the given artifact, updating the artifact's
#' latest version id and incrementing its version count. Uses a catalog-level lock to
#' serialize concurrent updates. Returns the computed version id.
#'
#' @param artifact_path Character path to the artifact file.
#' @param format Character format name (e.g. "rds", "qs2").
#' @param size_bytes Numeric size of the artifact in bytes.
#' @param content_hash Character content hash of the artifact.
#' @param code_hash Character code hash (if available).
#' @param created_at Character ISO8601 timestamp of creation.
#' @param sidecar_format Character sidecar format present ("json", "qs2", "both", "none").
#' @return Character version id (SipHash of artifact id, hashes, timestamp).
#' @keywords internal
.st_catalog_record_version <- function(
  artifact_path,
  format,
  size_bytes,
  content_hash,
  code_hash,
  created_at,
  sidecar_format
) {
  aid <- .st_artifact_id(artifact_path)
  vid <- secretbase::siphash13(
    paste(
      aid,
      content_hash %||% "",
      code_hash %||% "",
      created_at %||% "",
      sep = "|"
    )
  )

  catalog_path <- .st_catalog_path()
  lock_path <- fs::path(fs::path_dir(catalog_path), "catalog.lock")

  .st_with_lock(lock_path, {
    cat <- .st_catalog_read()

    # Upsert artifact row using helper
    cat <- .st_catalog_upsert_artifact(
      cat,
      artifact_id = aid,
      path = artifact_path,
      format = format,
      latest_version_id = vid
    )

    # Append version row using helper (ensures consistent coercion)
    new_v <- data.table(
      version_id = vid,
      artifact_id = aid,
      content_hash = content_hash %||% NA_character_,
      code_hash = code_hash %||% NA_character_,
      size_bytes = as.numeric(size_bytes),
      created_at = as.character(created_at),
      sidecar_format = sidecar_format
    )
    cat <- .st_catalog_append_version(cat, new_v)

    .st_catalog_write(cat)
  })

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
  art <- cat$artifacts[artifact_id == aid]
  if (!nrow(art)) {
    return(NULL)
  }
  vid <- art$latest_version_id[[1L]]
  ver <- cat$versions[version_id == vid]
  if (!nrow(ver)) {
    return(NULL)
  }
  ver[1L]
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
  if (is.null(parents) || !length(parents)) {
    return(invisible(NULL))
  }
  fs::dir_create(version_dir, recurse = TRUE)
  pfile <- fs::path(version_dir, "parents.json")
  tmp <- fs::file_temp(
    tmp_dir = fs::path_dir(pfile),
    pattern = fs::path_file(pfile)
  )
  jsonlite::write_json(
    parents,
    tmp,
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = NA
  )
  if (fs::file_exists(pfile)) {
    fs::file_delete(pfile)
  }
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
  if (is.na(version_dir) || !nzchar(version_dir)) {
    return(list())
  }
  pfile <- fs::path(version_dir, "parents.json")
  if (!fs::file_exists(pfile)) {
    return(list())
  }
  obj <- tryCatch(
    jsonlite::read_json(pfile, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_warn(
        "Could not parse parents.json at {.field {pfile}}: {conditionMessage(e)}"
      )
      NULL
    }
  )
  if (is.null(obj)) {
    return(list())
  }
  .st_parents_normalize(obj)
}


# Normalize "parents" into list(list(path=..., version_id=...))
.st_parents_normalize <- function(parents) {
  if (is.null(parents) || !length(parents)) {
    return(list())
  }

  # Case: data.frame with columns path, version_id
  if (is.data.frame(parents)) {
    if (!all(c("path", "version_id") %in% names(parents))) {
      return(list())
    }
    return(lapply(seq_len(nrow(parents)), function(i) {
      as.list(parents[i, , drop = FALSE])
    }))
  }

  # Case: singleton object with fields
  if (
    is.list(parents) && !is.null(parents$path) && !is.null(parents$version_id)
  ) {
    return(list(list(path = parents$path, version_id = parents$version_id)))
  }

  # Case: list-of-lists already
  if (is.list(parents) && length(parents) && is.list(parents[[1]])) {
    # Be defensive: keep only entries that have both fields
    keep <- vapply(
      parents,
      function(z) is.list(z) && !is.null(z$path) && !is.null(z$version_id),
      logical(1)
    )
    return(parents[keep])
  }

  list()
}


# ---- Reverse lineage (children) ----------------------------------------------

# Map artifact_id -> current canonical path (from catalog)
.st_artifact_path_from_id <- function(aid, cat = NULL) {
  if (is.null(cat)) {
    cat <- .st_catalog_read()
  }
  i <- which(cat$artifacts$artifact_id == aid)
  if (!length(i)) {
    return(NA_character_)
  }
  as.character(cat$artifacts$path[[i[1L]]])
}

#' Normalize parents structure (internal)
#'
#' Ensure the `parents` object has the canonical shape: a list of lists
#' each containing `path` and `version_id`. Accepts data.frames, singleton
#' lists, or list-of-lists.
#'
#' @param parents Object representing parents (data.frame, list, etc.)
#' @return A list of parent descriptors (each a list with `path` and `version_id`).
#' @keywords internal
.st_parents_normalize <- .st_parents_normalize

# Return immediate children (artifacts that list `path` as a parent)
# If `version_id` is provided, match only that parent version.
# Otherwise, accept any version of `path` appearing as a parent.
# Result columns: child_path, child_version, parent_path, parent_version
.st_children_once <- function(path, version_id = NULL) {
  cat <- .st_catalog_read()
  if (NROW(cat$versions) == 0L) {
    return(data.frame(
      child_path = character(),
      child_version = character(),
      parent_path = character(),
      parent_version = character(),
      stringsAsFactors = FALSE
    ))
  }
  target_path_abs <- .st_norm_path(path)

  rows <- list()
  # Iterate all recorded versions; check their committed parents.json
  for (k in seq_len(NROW(cat$versions))) {
    vrow <- cat$versions[k, , drop = FALSE]
    aid <- vrow$artifact_id[[1L]]
    cvid <- vrow$version_id[[1L]]
    cpth <- .st_artifact_path_from_id(aid, cat = cat)
    if (!nzchar(cpth)) {
      next
    }

    vdir <- .st_version_dir(cpth, cvid)
    parents <- .st_version_read_parents(vdir)
    if (!length(parents)) {
      next
    }

    for (p in parents) {
      p_path_abs <- .st_norm_path(p$path)
      if (!identical(p_path_abs, target_path_abs)) {
        next
      }
      if (!is.null(version_id) && nzchar(version_id)) {
        if (!identical(as.character(p$version_id), as.character(version_id))) {
          next
        }
      }
      rows[[length(rows) + 1L]] <- data.frame(
        child_path = cpth,
        child_version = cvid,
        parent_path = p_path_abs,
        parent_version = as.character(p$version_id),
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(rows)) {
    return(data.frame(
      child_path = character(),
      child_version = character(),
      parent_path = character(),
      parent_version = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

#' List children (reverse lineage) of an artifact (internal helper)
#'
#' Internal helper that finds immediate children that list `path` as a parent
#' in their committed parents.json snapshots. Returned columns: child_path,
#' child_version, parent_path, parent_version.
#'
#' @param path Character path to the parent artifact.
#' @param version_id Optional version id to match; if provided, only children
#'   listing that exact parent version are returned.
#' @return A data.frame of matching children (may be empty).
#' @keywords internal
.st_children_once <- .st_children_once

#' List children (reverse lineage) of an artifact
#'
#' Finds artifacts that depend on \code{path} (i.e., that record it in their
#' \code{parents.json} snapshots). If \code{version_id} is given, matches only
#' that specific parent version; otherwise, any parent version of \code{path}.
#'
#' @param path Character path to the parent artifact.
#' @param version_id Optional version id of \code{path} to match. Default: any.
#' @param depth Integer depth >= 1. Use \code{Inf} to recurse fully.
#' @return \code{data.frame} with columns:
#'   \code{level}, \code{child_path}, \code{child_version},
#'   \code{parent_path}, \code{parent_version}.
#' @export
st_children <- function(path, version_id = NULL, depth = 1L) {
  stopifnot(is.numeric(depth), depth >= 1)
  target_path_abs <- .st_norm_path(path)

  out_rows <- list()
  seen <- new.env(parent = emptyenv()) # to avoid cycles

  add_rows <- function(df, level) {
    if (!NROW(df)) {
      return()
    }
    df$level <- level
    # de-dup at row level (child_path@child_version)
    for (i in seq_len(NROW(df))) {
      key <- paste(df$child_path[[i]], df$child_version[[i]], sep = "@")
      if (!isTRUE(rlang::env_has(seen, key))) {
        rlang::env_poke(seen, key, TRUE)
        out_rows[[length(out_rows) + 1L]] <<- df[i, , drop = FALSE]
      }
    }
  }

  recurse <- function(p_path_abs, p_vid, level) {
    if (level > depth) {
      return(invisible(NULL))
    }
    kids <- .st_children_once(p_path_abs, version_id = p_vid)
    if (!NROW(kids)) {
      return(invisible(NULL))
    }
    add_rows(kids, level)
    if (is.infinite(depth) || level < depth) {
      # Recurse from each child as the new parent (by its latest version)
      for (i in seq_len(NROW(kids))) {
        cp <- kids$child_path[[i]]
        cv <- st_latest(cp) # recurse from current latest of the child
        if (is.na(cv) || !nzchar(cv)) {
          next
        }
        recurse(.st_norm_path(cp), cv, level + 1L)
      }
    }
  }

  # If version_id not provided, accept any parent version at level 1
  recurse(target_path_abs, version_id %||% NULL, 1L)

  if (!length(out_rows)) {
    return(data.frame(
      level = integer(),
      child_path = character(),
      child_version = character(),
      parent_path = character(),
      parent_version = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, out_rows)
  out[order(out$level), , drop = FALSE]
}

# Is a child stale because one (or more) of its parents advanced?
# Looks only at committed parents.json of the child's latest snapshot.
# If no parents are recorded, returns FALSE (nothing to compare).
#' Is a child artifact stale because its parents advanced?
#'
#' Inspect the committed parents.json for the latest snapshot of `path` and
#' determine whether any parent now has a different latest version id.
#'
#' @param path Character path to the artifact to inspect.
#' @return Logical scalar. `TRUE` if any parent advanced, otherwise `FALSE`.
#' @export
st_is_stale <- function(path) {
  vdir <- .st_version_dir_latest(path)
  if (is.na(vdir) || !nzchar(vdir)) {
    return(FALSE)
  }
  parents <- .st_version_read_parents(vdir)
  if (!length(parents)) {
    return(FALSE)
  }

  for (p in parents) {
    cur <- st_latest(p$path)
    # If parent has no versions now, treat as not advancing (conservative).
    if (!is.na(cur) && !identical(cur, p$version_id)) return(TRUE)
  }
  FALSE
}
