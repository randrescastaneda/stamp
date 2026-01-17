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
#' @param alias Optional stamp alias to target a specific stamp folder.
#' @return Invisibly, a data.frame of pruned (or would-prune) versions with
#'   columns: artifact_path, version_id, created_at, size_bytes.
#' @details
#' **Retention policy semantics**
#'
#' * `policy = Inf` — keep *all* versions (no pruning).
#' * `policy = <numeric>` — interpreted as “keep the **n** most recent versions
#'   per artifact.” For example, `policy = 2` keeps the latest two and prunes older ones.
#' * `policy = list(...)` — a combined policy where multiple conditions are
#'   UNIONed (kept if **any** condition keeps it):
#'   - `n`: keep the latest **n** per artifact.
#'   - `days`: keep versions whose `created_at` is within the last **days** days.
#'   - `keep_latest` / `min_keep` (internal fields in some flows) ensure at least
#'     a floor of versions are preserved; typical use is covered by `n` + `days`.
#'
#' **Grouping & order.** Pruning decisions are made per artifact, after sorting
#' each artifact’s versions by `created_at` (newest → oldest). The “latest n”
#' condition is applied on this order.
#'
#' **Dry runs vs destructive mode.** With `dry_run = TRUE`, the function only
#' reports what *would* be pruned (and estimates reclaimed space). With
#' `dry_run = FALSE`, it deletes the snapshot directories under
#' `<state_dir>/versions/...` and updates the catalog accordingly:
#'   - removes rows from the `versions` table,
#'   - adjusts each artifact’s `n_versions` and `latest_version_id`
#'     (to the newest remaining version), or drops the artifact row if none remain.
#'
#' **Scope.** You can restrict pruning to specific artifacts by supplying their paths via the `path` argument. By default (`path = NULL`), pruning considers all artifacts recorded in the catalog. If you provide one or more artifact paths, only versions associated with those artifacts are considered for pruning.
#'
#' **Integration with writes.** If you set a default policy via
#' `st_opts(retain_versions = <policy>)`, internal helpers may apply pruning
#' right after `st_save()` for the just-written artifact (keep-all is the default).
#'
#' **Safety notes.**
#' * Pruning never touches the **live artifact files** (`A.qs`, etc.) — only the
#'   stored version snapshots and catalog entries.
#' * Use `dry_run = TRUE` first to verify what would be removed.
#' @examples
#' \donttest{
#' # Minimal setup: temp project with three artifacts and multiple versions
#' st_opts_reset()
#' st_opts(versioning = "content", meta_format = "json")
#'
#' root <- tempdir()
#' st_init(root)
#'
#' # A, B, C
#' pA <- fs::path(root, "A.qs"); xA <- data.frame(a = 1:3)
#' pB <- fs::path(root, "B.qs"); pC <- fs::path(root, "C.qs")
#'
#' # First versions
#' st_save(xA, pA, code = function(z) z)
#' st_save(transform(xA, b = a * 2), pB, code = function(z) z,
#'         parents = list(list(path = pA, version_id = st_latest(pA))))
#' st_save(transform(st_load(pB), c = b + 1L), pC, code = function(z) z,
#'         parents = list(list(path = pB, version_id = st_latest(pB))))
#'
#' # Create a couple of extra versions for A to have data to prune
#' st_save(transform(xA, a = a + 10L), pA, code = function(z) z)
#' st_save(transform(xA, a = a + 20L), pA, code = function(z) z)
#'
#' # Inspect versions for A
#' st_versions(pA)
#'
#' # 1) Keep everything (no-op)
#' st_prune_versions(policy = Inf, dry_run = TRUE)
#'
#' # 2) Keep only the latest 1 per artifact (dry run)
#' st_prune_versions(policy = 1, dry_run = TRUE)
#'
#' # 3) Combined policy:
#' #    - keep the latest 2 per artifact
#' #    - and also keep any versions newer than 7 days (union of both)
#' st_prune_versions(policy = list(n = 2, days = 7), dry_run = TRUE)
#'
#' # 4) Restrict pruning to a single artifact path
#' st_prune_versions(path = pA, policy = 1, dry_run = TRUE)
#'
#' # 5) Apply pruning (destructive): keep latest 1 everywhere
#' #    (Uncomment to run for real)
#' # st_prune_versions(policy = 1, dry_run = FALSE)
#'
#' # Optional: set a default retention policy and have st_save() apply it
#' # after each write via .st_apply_retention() (internal helper).
#' # For example, keep last 2 versions going forward:
#' st_opts(retain_versions = 2)
#' # Next saves will write a new version and then prune older ones for that artifact.
#' }
#' @export
st_prune_versions <- function(
  path = NULL,
  policy = Inf,
  dry_run = TRUE,
  alias = NULL
) {
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
  catalog_path <- .st_catalog_path(alias)
  lock_path <- fs::path(fs::path_dir(catalog_path), "catalog.lock")

  result <- .st_with_lock(lock_path, {
    cat <- .st_catalog_read(alias) # already data.table invariant

    # Schema guards
    req_art <- c(
      "artifact_id",
      "path",
      "format",
      "latest_version_id",
      "n_versions"
    )
    req_ver <- c(
      "version_id",
      "artifact_id",
      "content_hash",
      "code_hash",
      "size_bytes",
      "created_at",
      "sidecar_format"
    )
    if (!all(req_art %in% names(cat$artifacts))) {
      cli::cli_abort(
        "Catalog artifacts table missing required columns: {toString(setdiff(req_art, names(cat$artifacts)))}"
      )
    }
    if (!all(req_ver %in% names(cat$versions))) {
      cli::cli_abort(
        "Catalog versions table missing required columns: {toString(setdiff(req_ver, names(cat$versions)))}"
      )
    }
    if (!nrow(cat$versions)) {
      cli::cli_inform(c("v" = "No versions recorded; nothing to prune."))
      return(data.frame())
    }

    # Optional path filter → restrict to those artifacts
    if (!is.null(path)) {
      want <- .st_norm_path(path)
      a_keep <- cat$artifacts$path %in% want
      cat$artifacts <- cat$artifacts[a_keep]
      if (!nrow(cat$artifacts)) {
        cli::cli_inform(c(
          "v" = "No catalog artifacts matched the provided path filter; nothing to prune."
        ))
        return(data.frame())
      }
      cat$versions <- cat$versions[artifact_id %in% cat$artifacts$artifact_id]
      if (!nrow(cat$versions)) {
        cli::cli_inform(c(
          "v" = "No versions exist for the provided path filter; nothing to prune."
        ))
        return(data.frame())
      }
    }

    # Attach artifact paths to versions (data.table safe subset)
    arts <- cat$artifacts[, .(artifact_id, path)]
    vers <- merge(
      cat$versions,
      arts,
      by = "artifact_id",
      all.x = TRUE,
      sort = FALSE
    )

    # For safety, ensure creation ordering newest -> oldest with deterministic tie-breaker.
    # Use version_id as secondary key (descending) to avoid flakiness when multiple versions
    # share the identical created_at second.
    ord <- order(vers$created_at, vers$version_id, decreasing = TRUE)
    vers <- vers[ord]

    # Group by artifact and choose which versions to KEEP under policy
    split_idx <- split(seq_len(nrow(vers)), vers$artifact_id)
    keep_ids <- character(0)

    # Always keep at least 1 newest per artifact (conservative default)
    min_keep <- 1L

    for (aid in names(split_idx)) {
      idx <- split_idx[[aid]]
      block <- vers[idx]

      # newest -> oldest (deterministic tie-breaker on version_id)
      bord <- order(block$created_at, block$version_id, decreasing = TRUE)
      block <- block[bord]

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
      .(artifact_id, artifact_path = path, version_id, created_at, size_bytes)
    ]
    setorder(candidates, artifact_path, created_at)

    if (!nrow(candidates)) {
      cli::cli_inform(c(
        "v" = "Retention policy matched zero versions; nothing to prune."
      ))
      return(candidates)
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
      return(candidates)
    }

    # ---- destructive path (delete snapshots + update catalog) -------------------
    # Delete version snapshot dirs
    for (i in seq_len(nrow(candidates))) {
      a_path <- candidates$artifact_path[[i]]
      vid <- candidates$version_id[[i]]
      vdir <- .st_version_dir(a_path, vid, alias = alias)
      .st_delete_version_dir_safe(vdir)
    }

    # Remove version rows from catalog
    keep_mask <- !(cat$versions$version_id %in% candidates$version_id)
    cat$versions <- cat$versions[keep_mask]

    # Recompute artifacts table (n_versions & latest_version_id)
    for (aid in unique(candidates$artifact_id)) {
      v_rows <- cat$versions[artifact_id == aid]
      a_idx <- which(cat$artifacts$artifact_id == aid)
      if (!nrow(v_rows)) {
        # No versions left → drop the artifact row
        cat$artifacts <- cat$artifacts[-a_idx]
      } else {
        ord <- order(v_rows$created_at, decreasing = TRUE)
        latest_vid <- v_rows$version_id[[ord[1L]]]
        cat$artifacts$latest_version_id[a_idx] <- latest_vid
        cat$artifacts$n_versions[a_idx] <- nrow(v_rows)
      }
    }

    # Optionally convert back to data.table for persistence consistency
    # Already data.table invariant
    .st_catalog_write(cat, alias)
    candidates
  })

  invisible(result)
}

# ---- Internals ---------------------------------------------------------------

# Normalize retention policy object (internal)
#  - Inf                -> kind="all"
#  - numeric scalar n   -> kind="n"
#  - list(n=?, days=?)  -> kind="combo"
#  - character like "2 7" -> parsed as list(n=2, days=7) or "2" -> n=2
.st_normalize_policy <- function(policy) {
  if (is.character(policy)) {
    nums <- suppressWarnings(as.numeric(strsplit(
      paste(policy, collapse = " "),
      "\\s+"
    )[[1]]))
    nums <- nums[!is.na(nums)]
    if (length(nums) == 1L) {
      policy <- as.integer(nums[1L])
    } else if (length(nums) >= 2L) {
      policy <- list(n = as.integer(nums[1L]), days = as.numeric(nums[2L]))
    }
  }

  if (identical(policy, Inf)) {
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


# Optionally invoked after st_save() to apply retention for a single artifact
# (safe: no is.infinite() on lists; normalize first)
.st_apply_retention <- function(artifact_path, alias = NULL) {
  pol_raw <- st_opts("retain_versions", .get = TRUE) %||% Inf
  pol <- .st_normalize_policy(pol_raw)
  if (identical(pol$kind, "all")) {
    return(invisible(NULL)) # keep-everything → no-op
  }
  # Apply to just this artifact; st_prune_versions will also normalize internally
  st_prune_versions(
    path = artifact_path,
    policy = pol_raw,
    dry_run = FALSE,
    alias = alias
  )
  invisible(NULL)
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
  suppressWarnings(as.POSIXct(
    chr,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  ))
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
