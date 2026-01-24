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
.st_root_dir <- function(alias = NULL) {
  # Resolve project root via alias config; fall back to legacy state.
  cfg <- .st_alias_get(alias)
  if (!is.null(cfg)) {
    return(cfg$root)
  }
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
.st_state_dir_abs <- function(alias = NULL) {
  # Compute absolute state dir; alias only selects configuration.
  cfg <- .st_alias_get(alias)
  if (!is.null(cfg)) {
    return(cfg$stamp_path)
  }
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
.st_versions_root <- function(alias = NULL) {
  # Versions root is under the resolved state dir; no alias in path names.
  vs <- fs::path(.st_state_dir_abs(alias), "versions")
  .st_dir_create(vs)
  vs
}

#' Version directory for an artifact (internal)
#'
#' Compute the version directory path for a file.
#' New structure: <data_folder>/<rel_path>/versions/<version_id>
#'
#' @param rel_path Relative path from alias root (includes filename).
#' @param version_id Version identifier (character).
#' @param alias Optional alias
#' @return Character scalar path to the version directory, or NA if version_id is NA/empty.
#' @keywords internal
.st_version_dir <- function(rel_path, version_id, alias = NULL) {
  if (is.na(version_id) || !length(version_id) || !nzchar(version_id)) {
    return(NA_character_)
  }

  # Get file storage directory in .st_data structure
  storage_dir <- .st_file_storage_dir(rel_path, alias = alias)

  # Version directory: <storage_dir>/versions/<version_id>
  fs::path(storage_dir, "versions", version_id)
}

# Catalog paths & IO -----------------------------------------------------------

#' Catalog file path (internal)
#'
#' Return the path to the on-disk catalog file under the package state
#' directory: <root>/<state_dir>/catalog.qs2
#'
#' @return Character scalar path to the catalog file.
#' @keywords internal
.st_catalog_path <- function(alias = NULL) {
  # Catalog remains centralized at alias root for efficient querying
  fs::path(.st_state_dir_abs(alias), "catalog.qs2")
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
    ),
    parents_index = data.table(
      parent_artifact_id = character(),
      parent_version_id = character(),
      child_artifact_id = character(),
      child_version_id = character()
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
.st_catalog_read <- function(alias = NULL) {
  p <- .st_catalog_path(alias = alias)
  cat <- if (fs::file_exists(p)) .st_read_qs2(p) else .st_catalog_empty()
  # Coerce to data.table invariant if loaded catalog used older data.frame layout
  if (!is.data.table(cat$artifacts)) {
    cat$artifacts <- as.data.table(cat$artifacts)
  }
  if (!is.data.table(cat$versions)) {
    cat$versions <- as.data.table(cat$versions)
  }
  if (is.null(cat$parents_index)) {
    cat$parents_index <- as.data.table(.st_catalog_empty()$parents_index)
  } else if (!is.data.table(cat$parents_index)) {
    cat$parents_index <- as.data.table(cat$parents_index)
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
.st_catalog_write <- function(cat, alias = NULL) {
  p <- .st_catalog_path(alias = alias)
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
#' @param alias Optional stamp alias to target a specific stamp folder.
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
st_versions <- function(path, alias = NULL) {
  # Normalize to get logical_path for artifact_id computation
  # Don't auto-switch: we want to query the specified alias's catalog
  norm <- .st_normalize_user_path(
    path,
    alias = alias,
    must_exist = FALSE,
    auto_switch = FALSE
  )
  logical_path <- norm$logical_path
  versioning_alias <- norm$alias

  aid <- .st_artifact_id(logical_path)
  cat <- .st_catalog_read(alias = versioning_alias)
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
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @export
st_latest <- function(path, alias = NULL) {
  # Derive latest from the versions table ordering to avoid relying on
  # artifacts.latest_version_id, which may be stale if a prior write failed.
  vers <- st_versions(path, alias = alias)
  if (nrow(vers) == 0L) {
    return(NA_character_)
  }
  as.character(vers$version_id[[1L]])
}

#' Resolve version specification to a concrete version_id (internal)
#'
#' @param path artifact path
#' @param version NULL (latest), integer (relative), character (specific version ID),
#'   or "select"/"pick"/"choose" to show interactive menu
#' @return character version_id or NA_character_
#' @keywords internal
.st_resolve_version <- function(path, version = NULL, alias = NULL) {
  # NULL or 0 -> latest
  if (is.null(version) || (is.numeric(version) && version == 0)) {
    return(st_latest(path, alias = alias))
  }

  # Positive integers are not allowed
  if (is.numeric(version) && length(version) == 1L && version > 0) {
    cli::cli_abort(c(
      "x" = "Positive version numbers are not allowed.",
      "i" = "Use NULL for latest, 0 for current, or negative integers for relative versions."
    ))
  }

  # Negative integers: relative to latest
  if (is.numeric(version)) {
    if (length(version) != 1L || is.na(version)) {
      cli::cli_abort(
        "Invalid numeric version specification: must be a single non-NA value"
      )
    }
    if (version < 0) {
      vers <- st_versions(path, alias = alias)
      if (nrow(vers) == 0L) {
        cli::cli_abort("No versions found for {.file {path}}")
      }

      # vers is already sorted by created_at descending (newest first)
      idx <- abs(as.integer(version)) + 1L
      if (idx > nrow(vers)) {
        cli::cli_abort(c(
          "x" = "Version index {version} goes beyond available versions.",
          "i" = "Only {nrow(vers)} version{?s} available for {.file {path}}"
        ))
      }

      return(as.character(vers$version_id[idx]))
    }
    # If numeric and non-negative (handled earlier for >0 and 0), treat as invalid
    cli::cli_abort("Invalid numeric version specification: {.val {version}}")
  }

  # Character: check for interactive menu request or specific version ID
  if (is.character(version)) {
    if (length(version) != 1L || is.na(version)) {
      cli::cli_abort(
        "Invalid character version specification: must be a single non-NA value"
      )
    }
    vers <- st_versions(path, alias = alias)
    if (nrow(vers) == 0L) {
      cli::cli_abort("No versions found for {.file {path}}")
    }

    # Interactive menu on explicit request
    if (tolower(version) %in% c("select", "pick", "choose")) {
      return(.st_prompt_select_version(path, alias = alias))
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

# Internal: interactive version picker (explicit opt-in only)
.st_prompt_select_version <- function(path, alias = NULL) {
  vers <- st_versions(path, alias = alias)
  if (nrow(vers) == 0L) {
    cli::cli_abort("No versions found for {.file {path}}")
  }
  if (!interactive()) {
    cli::cli_abort(c(
      "x" = "Interactive selection is not supported (not interactive).",
      "i" = "Pass a specific version id (character) or a negative integer for relative selection (e.g., -1)."
    ))
  }

  # Build menu labels: created_at, size_bytes, version_id
  labels <- vapply(
    seq_len(nrow(vers)),
    function(i) {
      ts <- as.character(vers$created_at[[i]])
      sz <- vers$size_bytes[[i]] %||% NA_real_
      id <- as.character(vers$version_id[[i]])
      paste0(
        "[",
        i,
        "] ",
        ts,
        "  ",
        format(sz, digits = 4, big.mark = ","),
        " bytes  ",
        id
      )
    },
    character(1L)
  )

  choice <- utils::menu(labels, title = sprintf("Select version for %s", path))
  if (choice < 1L || choice > nrow(vers)) {
    cli::cli_abort("No selection made.")
  }
  as.character(vers$version_id[[choice]])
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
#' @param verbose Logical; if TRUE (default), print informational messages.
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @return The object produced by the format-specific read handler (typically an R object loaded from disk).
#' @examples
#' \dontrun{
#' # load a historical version of a dataset
#' old <- st_load_version("data/cleaned.rds", "20250101T000000Z-abcdef01")
#' }
#' @export
st_load_version <- function(
  path,
  version_id,
  verbose = TRUE,
  ...,
  alias = NULL
) {
  # Normalize path to get rel_path for version operations
  norm <- .st_normalize_user_path(path, alias = alias, must_exist = FALSE)
  rel_path <- norm$rel_path
  versioning_alias <- norm$alias

  vdir <- .st_version_dir(rel_path, version_id, alias = versioning_alias)
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
  res <- h$read(art, verbose = verbose, ...)

  # Restore original object attributes (data.table class, row.names, etc.)
  res <- .st_restore_sanitized_object(res)

  if (isTRUE(verbose)) {
    cli::cli_inform(c(
      "v" = "Loaded \u2190 {.field {path}} @ {.field {version_id}} [{.field {fmt}}]"
    ))
  }
  res
}

#' Show immediate or recursive parents for an artifact
#' @param path Artifact path (child)
#' @param depth Integer depth >= 1. Use Inf to walk recursively.
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @return data.frame with columns: level, child_path, child_version, parent_path, parent_version
#' @export
st_lineage <- function(path, depth = 1L, alias = NULL) {
  stopifnot(is.numeric(depth), depth >= 1)
  visited <- list()
  rows <- list()

  walk <- function(child_path, child_vid, level) {
    if (level > depth) {
      return(invisible(NULL))
    }

    # Convert child_path to rel_path for version operations
    root <- .st_root_dir(alias = alias)
    child_rel_path <- as.character(fs::path_rel(child_path, start = root))

    vdir <- .st_version_dir(child_rel_path, child_vid, alias = alias)
    # Prefer committed parents.json in the version snapshot. If not present
    # and we're at the first level, fall back to the artifact sidecar parents
    # for convenience. Recursive walking beyond level 1 will only use
    # snapshot-backed parents to preserve reproducible lineage traversal.
    parents <- .st_version_read_parents(vdir)
    if (!length(parents) && level == 1L) {
      sc <- tryCatch(
        st_read_sidecar(child_rel_path, alias = alias),
        error = function(e) NULL
      )
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

  vid <- st_latest(path, alias = alias)
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
.st_sidecar_present <- function(rel_path, alias = NULL) {
  scj <- .st_sidecar_path(rel_path, "json", alias = alias)
  scq <- .st_sidecar_path(rel_path, "qs2", alias = alias)
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
#' @param rel_path Relative path from alias root (includes filename).
#' @param version_id Version identifier for the snapshot.
#' @param parents Optional list of parent descriptors to write into parents.json.
#' @param alias Optional alias.
#' @return Invisibly returns the version directory path.
#' @keywords internal
.st_version_commit_files <- function(
  rel_path,
  version_id,
  parents = NULL,
  alias = NULL
) {
  # Compute version directory using rel_path
  vdir <- .st_version_dir(rel_path, version_id, alias = alias)
  .st_dir_create(fs::path_dir(vdir))
  .st_dir_create(vdir)

  # Get actual artifact path for copying
  artifact_path <- .st_artifact_path(rel_path, alias = alias)

  # artifact copy
  fs::file_copy(artifact_path, fs::path(vdir, "artifact"), overwrite = TRUE)

  # sidecars (if present)
  scj <- .st_sidecar_path(rel_path, "json", alias = alias)
  scq <- .st_sidecar_path(rel_path, "qs2", alias = alias)
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


.st_version_dir_latest <- function(rel_path, alias = NULL) {
  vid <- st_latest(rel_path, alias = alias)
  # vid may be NA or empty; guard accordingly
  if (is.null(vid) || is.na(vid) || !nzchar(as.character(vid))) {
    return(NA_character_)
  }
  vdir <- .st_version_dir(rel_path, as.character(vid), alias = alias)
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
  # Use base indexing to avoid data.table NSE shadowing of argument names
  idx <- which(as.character(a$artifact_id) == as.character(artifact_id))
  if (!length(idx)) {
    a <- rbindlist(
      list(
        a,
        data.table(
          artifact_id = as.character(artifact_id),
          path = as.character(path),
          format = as.character(format),
          latest_version_id = as.character(latest_version_id),
          n_versions = as.integer(1L)
        )
      ),
      use.names = TRUE,
      fill = TRUE
    )
  } else {
    a[
      idx,
      `:=`(
        latest_version_id = as.character(latest_version_id),
        n_versions = as.integer(n_versions) + 1L
      )
    ]
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
  sidecar_format,
  alias = NULL,
  parents = NULL
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

  catalog_path <- .st_catalog_path(alias = alias)
  lock_path <- fs::path(fs::path_dir(catalog_path), "catalog.lock")

  .st_with_lock(lock_path, {
    cat <- .st_catalog_read(alias = alias)

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

    # Append parent relationships into parents_index (if provided)
    if (!is.null(parents) && length(parents)) {
      parents <- .st_parents_normalize(parents)
      if (length(parents)) {
        rows <- lapply(parents, function(p) {
          # For each parent, compute its artifact_id the same way we do for the child
          # Both artifact_ids are computed from the logical (absolute) path
          parent_aid <- .st_artifact_id(p$path)
          
          data.table(
            parent_artifact_id = parent_aid,
            parent_version_id = as.character(p$version_id),
            child_artifact_id = aid,
            child_version_id = vid
          )
        })
        cat$parents_index <- rbindlist(
          list(
            cat$parents_index,
            rbindlist(rows, use.names = TRUE, fill = TRUE)
          ),
          use.names = TRUE,
          fill = TRUE
        )
      }
    }

    .st_catalog_write(cat, alias = alias)
  })

  vid
}


# Return the latest version row (or NULL) for an artifact path
# (Removed unused `.st_catalog_latest_version_row()` helper; left here as
# plain comments to avoid generating orphaned Rd documentation.)

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
.st_children_once <- function(path, version_id = NULL, alias = NULL) {
  cat <- .st_catalog_read(alias)
  # Prefer parents_index when available; fall back to scanning if empty
  if (NROW(cat$parents_index) > 0L) {
    pai <- .st_artifact_id(path)
    idx <- if (!is.null(version_id) && nzchar(version_id)) {
      cat$parents_index[
        parent_artifact_id == pai &
          parent_version_id == as.character(version_id)
      ]
    } else {
      cat$parents_index[parent_artifact_id == pai]
    }
    if (NROW(idx) == 0L) {
      return(data.frame(
        child_path = character(),
        child_version = character(),
        parent_path = character(),
        parent_version = character(),
        stringsAsFactors = FALSE
      ))
    }
    rows <- lapply(seq_len(NROW(idx)), function(i) {
      c_aid <- idx$child_artifact_id[[i]]
      c_vid <- idx$child_version_id[[i]]
      cpth <- .st_artifact_path_from_id(c_aid, cat = cat)
      # cpth is already the absolute logical path from the artifact record
      data.frame(
        child_path = cpth,
        child_version = as.character(c_vid),
        parent_path = .st_norm_path(path),
        parent_version = as.character(idx$parent_version_id[[i]]),
        stringsAsFactors = FALSE
      )
    })
    return(do.call(rbind, rows))
  }

  # Fallback: scan committed parents.json files (legacy behavior)
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
  for (k in seq_len(NROW(cat$versions))) {
    vrow <- cat$versions[k]
    aid <- vrow$artifact_id[[1L]]
    cvid <- vrow$version_id[[1L]]
    cpth <- .st_artifact_path_from_id(aid, cat = cat)
    if (!nzchar(cpth)) {
      next
    }

    # Convert cpth (logical path) to rel_path for version operations
    root <- .st_root_dir(alias = alias)
    c_rel_path <- as.character(fs::path_rel(cpth, start = root))

    vdir <- .st_version_dir(c_rel_path, cvid, alias = alias)
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
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @return \code{data.frame} with columns:
#'   \code{level}, \code{child_path}, \code{child_version},
#'   \code{parent_path}, \code{parent_version}.
#' @export
st_children <- function(path, version_id = NULL, depth = 1L, alias = NULL) {
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
    kids <- .st_children_once(p_path_abs, version_id = p_vid, alias = alias)
    if (!NROW(kids)) {
      return(invisible(NULL))
    }
    add_rows(kids, level)
    if (is.infinite(depth) || level < depth) {
      # Recurse from each child as the new parent (by its latest version)
      for (i in seq_len(NROW(kids))) {
        cp <- kids$child_path[[i]]
        cv <- st_latest(cp, alias = alias) # recurse from current latest of the child
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
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @return Logical scalar. `TRUE` if any parent advanced, otherwise `FALSE`.
#' @export
st_is_stale <- function(path, alias = NULL) {
  # Normalize the path to get rel_path for version directory lookup
  norm <- .st_normalize_user_path(
    path,
    alias = alias,
    must_exist = FALSE,
    auto_switch = FALSE
  )
  
  vdir <- .st_version_dir_latest(norm$rel_path, alias = norm$alias)
  if (is.na(vdir) || !nzchar(vdir)) {
    return(FALSE)
  }
  parents <- .st_version_read_parents(vdir)
  if (!length(parents)) {
    return(FALSE)
  }

  for (p in parents) {
    cur <- st_latest(p$path, alias = alias)
    # If parent has no versions now, treat as not advancing (conservative).
    if (!is.na(cur) && !identical(cur, p$version_id)) return(TRUE)
  }
  FALSE
}
