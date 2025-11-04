# ---- Version retention / pruning --------------------------------------------

#' Prune stored versions according to a retention policy
#'
#' @param path Optional character vector of artifact paths to restrict pruning.
#'   If NULL (default), applies the policy to all artifacts in the catalog.
#' @param policy One of:
#'   - `Inf` (keep everything)
#'   - numeric scalar `n` (keep the *n* most recent per artifact)
#'   - `list(n = <int>, days = <num>)` (keep most recent *n* and/or those
#'     newer than *days*; union of the two conditions)
#' @param dry_run logical; if TRUE, only report what would be pruned.
#' @return Invisibly, a data.frame of pruned (or would-prune) versions with
#'   columns: artifact_path, version_id, created_at, size_bytes.
#' @export
st_prune_versions <- function(path = NULL, policy = Inf, dry_run = TRUE) {
  stopifnot(is.logical(dry_run), length(dry_run) == 1L)

  # Normalize the policy using the internal helper (single source of truth)
  pol <- .st_normalize_policy(policy)
  if (identical(pol$kind, "all")) {
    cli::cli_inform(c(
      "v" = "Retention policy is {.field Inf}: no pruning performed."
    ))
    return(invisible(data.frame()))
  }

  # Load catalog
  cat <- .st_catalog_read()
  if (!nrow(cat$versions)) {
    cli::cli_inform(c("v" = "No versions recorded; nothing to prune."))
    return(invisible(data.frame()))
  }

  # Optional path filter → restrict to those artifacts
  if (!is.null(path)) {
    want <- .st_norm_path(path)
    a_keep <- cat$artifacts$path %in% want
    cat$artifacts <- cat$artifacts[a_keep, , drop = FALSE]
    if (!nrow(cat$artifacts)) {
      cli::cli_inform(c(
        "v" = "No catalog artifacts matched the provided path filter; nothing to prune."
      ))
      return(invisible(data.frame()))
    }
    cat$versions <- cat$versions[
      cat$versions$artifact_id %in% cat$artifacts$artifact_id,
      ,
      drop = FALSE
    ]
    if (!nrow(cat$versions)) {
      cli::cli_inform(c(
        "v" = "No versions exist for the provided path filter; nothing to prune."
      ))
      return(invisible(data.frame()))
    }
  }

  # Attach artifact paths to versions
  arts <- cat$artifacts[, c("artifact_id", "path"), drop = FALSE]
  vers <- merge(
    cat$versions,
    arts,
    by = "artifact_id",
    all.x = TRUE,
    sort = FALSE
  )

  # For safety, ensure creation ordering newest -> oldest
  ord <- order(vers$created_at, decreasing = TRUE)
  vers <- vers[ord, , drop = FALSE]

  # Group by artifact and choose which versions to KEEP under policy
  split_idx <- split(seq_len(nrow(vers)), vers$artifact_id)
  keep_ids <- character(0)

  # Always keep at least 1 newest per artifact (conservative default)
  min_keep <- 1L

  for (aid in names(split_idx)) {
    idx <- split_idx[[aid]]
    block <- vers[idx, , drop = FALSE]

    # newest -> oldest
    bord <- order(block$created_at, decreasing = TRUE)
    block <- block[bord, , drop = FALSE]

    # Compute "keep" set from normalized policy
    kid <- .st_policy_keep_ids(block, pol)

    # Enforce min_keep (pad with newest if policy returned fewer)
    if (length(kid) < min_keep && nrow(block) > 0L) {
      kid <- unique(c(
        kid,
        block$version_id[seq_len(min(nrow(block), min_keep))]
      ))
    }

    keep_ids <- c(keep_ids, kid)
  }

  keep_ids <- unique(keep_ids)
  prune_mask <- !(vers$version_id %in% keep_ids)
  candidates <- vers[
    prune_mask,
    c("artifact_id", "path", "version_id", "created_at", "size_bytes"),
    drop = FALSE
  ]
  names(candidates)[names(candidates) == "path"] <- "artifact_path"
  candidates <- candidates[
    order(candidates$artifact_path, candidates$created_at),
    ,
    drop = FALSE
  ]

  if (!nrow(candidates)) {
    cli::cli_inform(c(
      "v" = "Retention policy matched zero versions; nothing to prune."
    ))
    return(invisible(candidates))
  }

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
  # Delete version snapshot dirs
  for (i in seq_len(nrow(candidates))) {
    a_path <- candidates$artifact_path[[i]]
    vid <- candidates$version_id[[i]]
    vdir <- .st_version_dir(a_path, vid)
    .st_delete_version_dir_safe(vdir)
  }

  # Remove version rows from catalog
  keep_mask <- !(cat$versions$version_id %in% candidates$version_id)
  cat$versions <- cat$versions[keep_mask, , drop = FALSE]

  # Recompute artifacts table (n_versions & latest_version_id)
  for (aid in unique(candidates$artifact_id)) {
    v_rows <- cat$versions[cat$versions$artifact_id == aid, , drop = FALSE]
    a_idx <- which(cat$artifacts$artifact_id == aid)
    if (!nrow(v_rows)) {
      # No versions left → drop the artifact row
      cat$artifacts <- cat$artifacts[-a_idx, , drop = FALSE]
    } else {
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

#' Normalize retention policy object (internal)
#'
#' Interpretation:
#'  - Inf                -> kind = "all"   (keep everything)
#'  - numeric scalar n   -> kind = "n"     (keep n most recent per artifact)
#'  - list(n=?, days=?)  -> kind = "combo" (union of "keep n" and "newer than days")
#'
#' @keywords internal
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
#' @param vtab data.frame of versions **sorted newest → oldest**
#' @param pol  normalized policy from `.st_normalize_policy()`
#' @keywords internal
.st_policy_keep_ids <- function(vtab, pol) {
  keep <- character(0)

  if (identical(pol$kind, "n")) {
    if (pol$n > 0L) {
      take <- seq_len(min(pol$n, nrow(vtab)))
      keep <- unique(c(keep, vtab$version_id[take]))
    }
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
#' @keywords internal
.st_parse_utc_times <- function(chr) {
  suppressWarnings(as.POSIXct(chr, tz = "UTC"))
}

#' Safely delete a version directory (internal)
#' @keywords internal
.st_delete_version_dir_safe <- function(vdir) {
  if (fs::dir_exists(vdir)) {
    fs::dir_delete(vdir)
  } else {
    cli::cli_warn(
      "Version dir missing at {.file {vdir}}; updating catalog anyway."
    )
  }
}

#' Optionally invoked after st_save() to apply retention for a single artifact
#' @keywords internal
.st_apply_retention <- function(artifact_path) {
  pol <- st_opts("retain_versions", .get = TRUE) %||% Inf
  if (is.infinite(pol)) {
    return(invisible(NULL))
  }
  # Apply to just this artifact
  st_prune_versions(path = artifact_path, policy = pol, dry_run = FALSE)
  invisible(NULL)
}
