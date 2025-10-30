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
