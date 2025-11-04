# ---- Version retention / pruning --------------------------------------------

#' Prune stored versions according to a retention policy
#'
#' Delete older version snapshots from the versions store and update the
#' catalog accordingly. The latest version of each artifact is always protected.
#'
#' @param path Character path to a single artifact to prune.
#'   If `NULL` (default), all artifacts in the catalog are considered.
#' @param policy Retention policy. One of:
#'   - `Inf` (default): keep everything (no-op)
#'   - single integer `n`: keep the **n** most recent versions
#'   - list with any of `n` (integer) and/or `days` (numeric):
#'       keep the union of the **n** most recent versions and
#'       all versions whose `created_at` is within the last `days`.
#' @param dry_run Logical; if `TRUE`, prints what would be removed but
#'   does not delete anything.
#' @return Invisibly, a data.frame with columns:
#'   artifact_path, version_id, created_at, action ("keep"|"delete")
#' @export
st_prune_versions <- function(path = NULL,
                              policy = st_opts("retain_versions", .get = TRUE) %||% Inf,
                              dry_run = FALSE) {
  cat <- .st_catalog_read()

  # Resolve target artifact paths
  targets <- if (is.null(path)) {
    if (!nrow(cat$artifacts)) {
      cli::cli_inform(c("v" = "No artifacts in catalog; nothing to prune."))
      return(invisible(.st_empty_prune_report()))
    }
    as.character(cat$artifacts$path)
  } else {
    as.character(.st_norm_path(path))
  }

  # Normalize policy
  pol <- .st_normalize_policy(policy)
  if (identical(pol$kind, "all")) {
    cli::cli_inform(c("v" = "Retention policy keeps all versions (no-op)."))
    return(invisible(.st_empty_prune_report()))
  }

  rows <- list()

  for (ap in unique(targets)) {
    aid <- .st_artifact_id(ap)
    # Versions for this artifact (most recent first)
    vtab <- if (isTRUE(requireNamespace("data.table", quietly = TRUE))) {
      data.table::as.data.table(cat$versions)
    } else {
      cat$versions
    }
    vtab <- vtab[vtab$artifact_id == aid, , drop = FALSE]
    if (!nrow(vtab)) next

    # Order newest -> oldest
    ord <- order(vtab$created_at, decreasing = TRUE)
    vtab <- vtab[ord, , drop = FALSE]

    # Protect latest row
    latest_vid <- st_latest(ap)
    keep_latest <- if (!is.na(latest_vid)) latest_vid else vtab$version_id[[1L]]

    # Evaluate keep set from policy
    keep_ids <- .st_policy_keep_ids(vtab, pol)
    # Always include latest
    keep_ids <- unique(c(keep_ids, keep_latest))

    # Partition keep/delete
    vtab$action <- ifelse(vtab$version_id %in% keep_ids, "keep", "delete")

    # Apply deletions
    del <- vtab[vtab$action == "delete", , drop = FALSE]
    if (nrow(del)) {
      cli::cli_inform(c("v" = "Pruning {.field {nrow(del)}} version{?s} for {.field {ap}}"))
      for (i in seq_len(nrow(del))) {
        vid  <- del$version_id[[i]]
        vdir <- .st_version_dir(ap, vid)
        if (isTRUE(dry_run)) {
          cli::cli_inform(c(" " = "• would remove {.file {vdir}}"))
        } else {
          .st_delete_version_dir_safe(vdir)
          # remove from catalog
          cat$versions <- cat$versions[cat$versions$version_id != vid, , drop = FALSE]
        }
      }
    }

    # Recompute artifact row (n_versions & latest_version_id)
    kept <- vtab[vtab$action == "keep", , drop = FALSE]
    new_latest <- if (nrow(kept)) kept$version_id[[1L]] else NA_character_

    idx_a <- which(cat$artifacts$artifact_id == aid)
    if (length(idx_a)) {
      if (!isTRUE(dry_run)) {
        cat$artifacts$n_versions[idx_a]        <- nrow(kept)
        cat$artifacts$latest_version_id[idx_a] <- new_latest
      }
    }

    rows[[length(rows) + 1L]] <- data.frame(
      artifact_path = ap,
      version_id    = vtab$version_id,
      created_at    = vtab$created_at,
      action        = vtab$action,
      stringsAsFactors = FALSE
    )
  }

  report <- if (length(rows)) do.call(rbind, rows) else .st_empty_prune_report()
  if (!isTRUE(dry_run)) .st_catalog_write(cat)
  invisible(report)
}

# ---- Internals ---------------------------------------------------------------

.st_empty_prune_report <- function() {
  data.frame(
    artifact_path = character(),
    version_id    = character(),
    created_at    = character(),
    action        = character(),
    stringsAsFactors = FALSE
  )
}

# Normalize policy object
#  - Inf                -> kind="all"
#  - numeric scalar     -> kind="n",     n = as.integer(value)
#  - list(n=?, days=?)  -> kind="combo", n=?, days=? (NULLs allowed)
.st_normalize_policy <- function(policy) {
  if (is.infinite(policy)) return(list(kind = "all"))
  if (is.numeric(policy) && length(policy) == 1L) {
    n <- as.integer(policy)
    if (is.na(n) || n < 0L) cli::cli_abort("Retention 'n' must be a non-negative integer.")
    return(list(kind = "n", n = n))
  }
  if (is.list(policy)) {
    n    <- policy$n    %||% NULL
    days <- policy$days %||% NULL
    if (!is.null(n)) {
      n <- as.integer(n)
      if (is.na(n) || n < 0L) cli::cli_abort("Retention 'n' must be a non-negative integer.")
    }
    if (!is.null(days)) {
      days <- as.numeric(days)
      if (is.na(days) || days < 0) cli::cli_abort("Retention 'days' must be a non-negative number.")
    }
    if (is.null(n) && is.null(days)) {
      cli::cli_abort("Retention list must include at least one of: n, days.")
    }
    return(list(kind = "combo", n = n, days = days))
  }
  cli::cli_abort("Unsupported retention policy type. Use Inf, integer n, or list(n=..., days=...).")
}

# Return the set of version_ids to KEEP under policy
.st_policy_keep_ids <- function(vtab, pol) {
  # vtab is newest -> oldest
  keep <- character(0)

  if (identical(pol$kind, "n")) {
    if (pol$n == 0L) return(character(0))
    take <- seq_len(min(pol$n, nrow(vtab)))
    keep <- unique(c(keep, vtab$version_id[take]))
  } else if (identical(pol$kind, "combo")) {
    if (!is.null(pol$n) && pol$n > 0L) {
      take <- seq_len(min(pol$n, nrow(vtab)))
      keep <- unique(c(keep, vtab$version_id[take]))
    }
    if (!is.null(pol$days) && pol$days >= 0) {
      now  <- as.POSIXct(Sys.time(), tz = "UTC")
      cut  <- now - as.difftime(pol$days, units = "days")
      ts   <- .st_parse_utc_times(vtab$created_at)
      idx  <- which(!is.na(ts) & ts >= cut)
      if (length(idx)) keep <- unique(c(keep, vtab$version_id[idx]))
    }
  }
  keep
}

.st_parse_utc_times <- function(chr) {
  # Accepts ISO-like strings from .st_now_utc()
  suppressWarnings(as.POSIXct(chr, tz = "UTC"))
}

.st_delete_version_dir_safe <- function(vdir) {
  if (fs::dir_exists(vdir)) {
    fs::dir_delete(vdir)
  } else {
    # Not fatal; catalog entry will be removed already
    cli::cli_warn("Version dir missing at {.file {vdir}}; updating catalog anyway.")
  }
}

# Optionally invoked after st_save()
.st_apply_retention <- function(artifact_path) {
  pol <- st_opts("retain_versions", .get = TRUE) %||% Inf
  if (is.infinite(pol)) return(invisible(NULL))
  # Not a dry run; apply for this artifact only
  st_prune_versions(path = artifact_path, policy = pol, dry_run = FALSE)
  invisible(NULL)
}
