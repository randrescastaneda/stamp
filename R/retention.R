# ---- Version retention / pruning --------------------------------------------

#' Prune stored versions according to a simple retention policy
#'
#' @param policy Either:
#'   - Inf (default): keep everything
#'   - numeric scalar (days): prune versions older than N days
#'   - list with optional fields:
#'       * days: numeric days threshold
#'       * keep_latest: integer, always keep the K most recent per artifact
#'       * min_keep: integer, never drop below M kept per artifact (default 1)
#' @param dry_run logical; if TRUE, only report what would be pruned
#' @return Invisibly, a data.frame of pruned (or would-prune) versions
#' @export
st_prune_versions <- function(policy = Inf, dry_run = TRUE) {
  # ---- normalize policy -------------------------------------------------------
  stopifnot(is.logical(dry_run), length(dry_run) == 1L)

  if (identical(policy, Inf)) {
    cli::cli_inform(c(
      "v" = "Retention policy is {.field Inf}: no pruning performed."
    ))
    return(invisible(data.frame()))
  }

  if (is.numeric(policy) && length(policy) == 1L) {
    policy <- list(days = as.numeric(policy), keep_latest = 0L, min_keep = 1L)
  } else if (is.list(policy)) {
    # fill defaults
    policy$days <- policy$days %||% Inf
    policy$keep_latest <- as.integer(policy$keep_latest %||% 0L)
    policy$min_keep <- as.integer(policy$min_keep %||% 1L)
  } else {
    cli::cli_abort("`policy` must be Inf, a numeric (days), or a list().")
  }

  if (!is.numeric(policy$days) || length(policy$days) != 1L) {
    cli::cli_abort("`policy$days` must be a single numeric or Inf.")
  }
  if (!is.finite(policy$days)) {
    cutoff_time <- as.POSIXct(NA) # effectively no age filter
  } else {
    cutoff_time <- as.POSIXct(
      Sys.time() - as.difftime(policy$days, units = "days"),
      tz = "UTC"
    )
  }

  keep_latest <- max(0L, policy$keep_latest)
  min_keep <- max(1L, policy$min_keep)

  # ---- load catalog -----------------------------------------------------------
  cat <- .st_catalog_read()
  if (!nrow(cat$versions)) {
    cli::cli_inform(c("v" = "No versions recorded; nothing to prune."))
    return(invisible(data.frame()))
  }

  # attach artifact paths to versions
  arts <- cat$artifacts[, c("artifact_id", "path"), drop = FALSE]
  vers <- merge(
    cat$versions,
    arts,
    by = "artifact_id",
    all.x = TRUE,
    sort = FALSE
  )

  # parse timestamps
  created <- tryCatch(
    as.POSIXct(vers$created_at, tz = "UTC"),
    error = function(e) rep(as.POSIXct(NA, tz = "UTC"), length(vers$created_at))
  )
  vers$`__created_time__` <- created

  # group by artifact and decide which versions to prune
  split_idx <- split(seq_len(nrow(vers)), vers$artifact_id)
  to_prune <- integer(0)

  for (aid in names(split_idx)) {
    idx <- split_idx[[aid]]
    block <- vers[idx, , drop = FALSE]

    # order newest first by created_at (fall back to row order if NA)
    ord <- order(block$`__created_time__`, decreasing = TRUE, na.last = TRUE)
    block <- block[ord, , drop = FALSE]
    idx <- idx[ord]

    n <- nrow(block)
    if (!n) {
      next
    }

    # Always keep the latest K
    keep_idx <- seq_len(min(keep_latest, n))

    # Keep newer than cutoff (if cutoff is not NA)
    if (!is.na(cutoff_time[1])) {
      keep_idx <- union(
        keep_idx,
        which(block$`__created_time__` >= cutoff_time)
      )
    }

    # Enforce min_keep (pad with newest)
    if (length(keep_idx) < min_keep) {
      keep_idx <- union(keep_idx, seq_len(min(n, min_keep)))
    }

    prune_idx <- setdiff(seq_len(n), keep_idx)
    if (length(prune_idx)) {
      to_prune <- c(to_prune, idx[prune_idx])
    }
  }

  if (!length(to_prune)) {
    cli::cli_inform(c(
      "v" = "Retention policy matched zero versions; nothing to prune."
    ))
    return(invisible(data.frame()))
  }

  candidates <- vers[
    to_prune,
    c("artifact_id", "path", "version_id", "created_at", "size_bytes"),
    drop = FALSE
  ]
  names(candidates)[names(candidates) == "path"] <- "artifact_path"
  candidates <- candidates[
    order(candidates$artifact_path, candidates$created_at),
    ,
    drop = FALSE
  ]

  if (isTRUE(dry_run)) {
    total_bytes <- sum(candidates$size_bytes %||% 0, na.rm = TRUE)
    cli::cli_inform(c(
      "v" = "DRY RUN: {nrow(candidates)} version{?s} would be pruned across {length(unique(candidates$artifact_id))} artifact{?s}.",
      " " = sprintf(
        "Estimated space reclaimed: ~%s",
        format(structure(total_bytes, class = "object_size"))
      )
    ))
    return(invisible(candidates))
  }

  # ---- destructive path (delete snapshots + update catalog) -------------------
  # Build a quick lookup: artifact_id -> artifact_path (absolute)
  aid2path <- stats::setNames(arts$path, arts$artifact_id)

  # delete snapshot dirs and remove rows from catalog
  for (i in seq_len(nrow(candidates))) {
    a_path <- candidates$artifact_path[[i]]
    vid <- candidates$version_id[[i]]
    vdir <- .st_version_dir(a_path, vid)
    if (fs::dir_exists(vdir)) {
      fs::dir_delete(vdir)
    }
  }

  # remove from versions table
  keep_mask <- !(cat$versions$version_id %in% candidates$version_id)
  cat$versions <- cat$versions[keep_mask, , drop = FALSE]

  # update artifacts table (n_versions and latest_version_id)
  for (aid in unique(candidates$artifact_id)) {
    v_rows <- cat$versions[cat$versions$artifact_id == aid, , drop = FALSE]
    a_idx <- which(cat$artifacts$artifact_id == aid)
    if (!nrow(v_rows)) {
      # No versions left → drop artifact row
      cat$artifacts <- cat$artifacts[-a_idx, , drop = FALSE]
    } else {
      # latest = newest by created_at
      ord <- order(v_rows$created_at, decreasing = TRUE)
      latest_vid <- v_rows$version_id[[ord[1L]]]
      cat$artifacts$latest_version_id[a_idx] <- latest_vid
      cat$artifacts$n_versions[a_idx] <- nrow(v_rows)
    }
  }

  .st_catalog_write(cat)

  total_bytes <- sum(candidates$size_bytes %||% 0, na.rm = TRUE)
  cli::cli_inform(c(
    "v" = "Pruned {nrow(candidates)} version{?s} across {length(unique(candidates$artifact_id))} artifact{?s}.",
    " " = sprintf(
      "Space reclaimed (est.): ~%s",
      format(structure(total_bytes, class = "object_size"))
    )
  ))
  invisible(candidates)
}


# ---- Internals ---------------------------------------------------------------

#' Empty prune report template (internal)
#'
#' Return an empty data.frame with the columns used by prune reporting:
#' artifact_path, version_id, created_at, action.
#'
#' @return A zero-row data.frame with standard prune report columns.
#' @keywords internal
.st_empty_prune_report <- function() {
  data.frame(
    artifact_path = character(),
    version_id = character(),
    created_at = character(),
    action = character(),
    stringsAsFactors = FALSE
  )
}

#' Normalize retention policy object (internal)
#'
#' Converts a user-provided retention policy specification into a normalized
#' internal list representation. Recognizes `Inf` (keep all), a single integer
#' (keep n most recent), or a list with `n` and/or `days`.
#'
#' @param policy Retention policy specification (Inf, integer, or list).
#' @return A list with `kind` and relevant fields (`n`, `days`).
#' @keywords internal
# Normalize policy object
#  - Inf                -> kind="all"
#  - numeric scalar     -> kind="n",     n = as.integer(value)
#  - list(n=?, days=?)  -> kind="combo", n=?, days=? (NULLs allowed)
.st_normalize_policy <- function(policy) {
  if (is.infinite(policy)) {
    return(list(kind = "all"))
  }
  if (is.numeric(policy) && length(policy) == 1L) {
    n <- as.integer(policy)
    if (is.na(n) || n < 0L) {
      cli::cli_abort("Retention 'n' must be a non-negative integer.")
    }
    return(list(kind = "n", n = n))
  }
  if (is.list(policy)) {
    n <- policy$n %||% NULL
    days <- policy$days %||% NULL
    if (!is.null(n)) {
      n <- as.integer(n)
      if (is.na(n) || n < 0L) {
        cli::cli_abort("Retention 'n' must be a non-negative integer.")
      }
    }
    if (!is.null(days)) {
      days <- as.numeric(days)
      if (is.na(days) || days < 0) {
        cli::cli_abort("Retention 'days' must be a non-negative number.")
      }
    }
    if (is.null(n) && is.null(days)) {
      cli::cli_abort("Retention list must include at least one of: n, days.")
    }
    return(list(kind = "combo", n = n, days = days))
  }
  cli::cli_abort(
    "Unsupported retention policy type. Use Inf, integer n, or list(n=..., days=...)."
  )
}

#' Compute version IDs to keep under a retention policy (internal)
#'
#' Given a version table (sorted newest -> oldest) and a normalized retention
#' policy, return the character vector of version IDs to keep.
#'
#' @param vtab Data.frame of versions sorted by created_at descending.
#' @param pol Normalized policy list (from `.st_normalize_policy`).
#' @return Character vector of version IDs to keep.
#' @keywords internal
# Return the set of version_ids to KEEP under policy
.st_policy_keep_ids <- function(vtab, pol) {
  # vtab is newest -> oldest
  keep <- character(0)

  if (identical(pol$kind, "n")) {
    if (pol$n == 0L) {
      return(character(0))
    }
    take <- seq_len(min(pol$n, nrow(vtab)))
    keep <- unique(c(keep, vtab$version_id[take]))
  } else if (identical(pol$kind, "combo")) {
    if (!is.null(pol$n) && pol$n > 0L) {
      take <- seq_len(min(pol$n, nrow(vtab)))
      keep <- unique(c(keep, vtab$version_id[take]))
    }
    if (!is.null(pol$days) && pol$days >= 0) {
      now <- as.POSIXct(Sys.time(), tz = "UTC")
      cut <- now - as.difftime(pol$days, units = "days")
      ts <- .st_parse_utc_times(vtab$created_at)
      idx <- which(!is.na(ts) & ts >= cut)
      if (length(idx)) keep <- unique(c(keep, vtab$version_id[idx]))
    }
  }
  keep
}

#' Parse UTC timestamp strings (internal)
#'
#' Parse character timestamps returned by `.st_now_utc()` into POSIXct objects
#' with UTC timezone. Warnings are suppressed.
#'
#' @param chr Character vector of ISO-like UTC timestamps.
#' @return POSIXct vector (UTC timezone).
#' @keywords internal
.st_parse_utc_times <- function(chr) {
  # Accepts ISO-like strings from .st_now_utc()
  suppressWarnings(as.POSIXct(chr, tz = "UTC"))
}

#' Safely delete a version directory (internal)
#'
#' Delete the version directory if it exists. If the directory is already
#' missing, issue a warning but do not fail (the catalog entry will be
#' removed regardless).
#'
#' @param vdir Character path to the version directory.
#' @return NULL (invisibly).
#' @keywords internal
.st_delete_version_dir_safe <- function(vdir) {
  if (fs::dir_exists(vdir)) {
    fs::dir_delete(vdir)
  } else {
    # Not fatal; catalog entry will be removed already
    cli::cli_warn(
      "Version dir missing at {.file {vdir}}; updating catalog anyway."
    )
  }
}

#' Apply retention policy for a single artifact (internal)
#'
## Optionally invoked after `st_save()` to prune older versions of the given
#' artifact according to the current `retain_versions` option. If the option
#' is `Inf` (keep all), this is a no-op.
#'
#' @param artifact_path Character path to the artifact.
#' @return NULL (invisibly).
#' @keywords internal
# Optionally invoked after st_save()
.st_apply_retention <- function(artifact_path) {
  pol <- st_opts("retain_versions", .get = TRUE) %||% Inf
  if (is.infinite(pol)) {
    return(invisible(NULL))
  }
  # Not a dry run; apply for this artifact only
  st_prune_versions(path = artifact_path, policy = pol, dry_run = FALSE)
  invisible(NULL)
}
