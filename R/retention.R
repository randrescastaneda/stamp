#' Prune stored versions for an artifact
#'
#' Keep only the `keep` most-recent versions for `path`, deleting older
#' snapshot directories and removing their catalog rows. Updates the
#' artifact row (latest_version_id, n_versions) accordingly.
#'
#' @param path Artifact path.
#' @param keep Integer number of most-recent versions to retain. Defaults to
#'   `st_opts("retain_versions")`. Use `Inf` to keep everything.
#' @return Invisibly, a data.frame of versions that were deleted (may be empty).
#' @export
st_prune_versions <- function(path, keep = NULL) {
  if (is.null(keep)) {
    keep <- st_opts("retain_versions", .get = TRUE) %||% Inf
  }
  if (!is.finite(keep)) {
    return(invisible(
      data.frame(version_id = character(), stringsAsFactors = FALSE)
    ))
  }
  keep <- as.integer(keep)
  if (keep < 0L) {
    keep <- 0L
  }

  aid <- .st_artifact_id(path)
  cat <- .st_catalog_read()

  # All versions for this artifact, newest first
  ver <- cat$versions[cat$versions$artifact_id == aid, , drop = FALSE]
  if (!nrow(ver)) {
    return(invisible(data.frame(
      version_id = character(),
      stringsAsFactors = FALSE
    )))
  }
  ver <- ver[order(ver$created_at, decreasing = TRUE), , drop = FALSE]

  # Nothing to prune?
  if (nrow(ver) <= keep) {
    return(invisible(data.frame(
      version_id = character(),
      stringsAsFactors = FALSE
    )))
  }

  # Split keep / drop
  to_keep <- ver$version_id[seq_len(keep)]
  to_drop <- ver$version_id[setdiff(seq_len(nrow(ver)), seq_len(keep))]

  # Delete snapshot dirs for to_drop (best-effort)
  for (vid in to_drop) {
    vdir <- .st_version_dir(path, vid)
    if (fs::dir_exists(vdir)) {
      fs::dir_delete(vdir)
    }
  }

  # Remove dropped versions from catalog
  cat$versions <- cat$versions[
    !(cat$versions$version_id %in% to_drop),
    ,
    drop = FALSE
  ]

  # Update artifact row
  aidx <- which(cat$artifacts$artifact_id == aid)
  if (length(aidx)) {
    cat$artifacts$latest_version_id[aidx] <- to_keep[[1L]]
    cat$artifacts$n_versions[aidx] <- length(to_keep)
  }

  .st_catalog_write(cat)

  invisible(data.frame(version_id = to_drop, stringsAsFactors = FALSE))
}
