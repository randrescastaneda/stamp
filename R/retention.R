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

  # Normalize the path to get logical_path that matches what's in the catalog
  want_logical_path <- NULL
  if (!is.null(path)) {
    norm <- .st_normalize_user_path(
      path,
      alias = alias,
      must_exist = FALSE,
      auto_switch = FALSE
    )
    want_logical_path <- norm$logical_path
    # Use the detected alias if no explicit alias was provided
    if (is.null(alias)) {
      alias <- norm$alias
    }
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
    if (!is.null(want_logical_path)) {
      a_keep <- cat$artifacts$path == want_logical_path
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
    # Sort ONCE with artifact_id as primary key to enable efficient grouping
    setorder(vers, artifact_id, -created_at, -version_id)

    # Group by artifact and choose which versions to KEEP under policy
    split_idx <- split(seq_len(nrow(vers)), vers$artifact_id)
    keep_ids <- character(0)

    # Always keep at least 1 newest per artifact (conservative default)
    min_keep <- 1L

    for (aid in names(split_idx)) {
      idx <- split_idx[[aid]]
      block <- vers[idx]
      # No need to re-sort: data is already sorted by artifact_id, -created_at, -version_id
      # from the single setorder() call above

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
    # Delete version snapshot dirs, tracking successes and failures
    # Pre-allocate vectors to avoid repeated memory reallocation during loop
    successfully_deleted <- character(nrow(candidates))
    deleted_idx <- 0L # Track actual number of successful deletions
    failed_count <- 0L

    # Resolve alias config once before loop to avoid redundant lookups
    # (avoid calling .st_alias_get() 750+ times in loop)
    cfg <- .st_alias_get(alias)
    if (is.null(cfg)) {
      cli::cli_abort(c(
        "x" = "Cannot proceed with deletion: alias configuration not found.",
        "i" = "Alias: {.val {alias %||% 'default'}}"
      ))
    }
    root_abs <- .st_normalize_path(cfg$root)
    root_abs_slash <- if (endsWith(root_abs, "/")) {
      root_abs
    } else {
      paste0(root_abs, "/")
    }

    for (i in seq_len(nrow(candidates))) {
      a_path <- candidates$artifact_path[[i]]
      vid <- candidates$version_id[[i]]

      # Inline path extraction logic using pre-computed root
      # Avoids repeated .st_alias_get() calls and path normalization
      path_norm <- .st_normalize_path(a_path)

      # Validate path is under root
      if (
        !identical(path_norm, root_abs) &&
          !startsWith(path_norm, root_abs_slash)
      ) {
        cli::cli_warn(c(
          "!" = "Failed to extract path for version {.val {vid}}.",
          "i" = "Storage path: {.file {a_path}}"
        ))
        failed_count <- failed_count + 1L
        next
      }

      # Extract relative path from absolute path
      rel_path <- if (identical(path_norm, root_abs)) {
        fs::path_file(a_path)
      } else {
        remainder <- substring(path_norm, nchar(root_abs_slash) + 1L)
        parts <- strsplit(remainder, "/")[[1]]
        if (!length(parts)) {
          NULL
        } else {
          special_dirs <- c("stmeta", "versions")
          storage_path_parts <- character()
          for (j in seq_along(parts)) {
            if (parts[j] %in% special_dirs) {
              break
            }
            if (
              j > 1 &&
                parts[j] == parts[length(parts)] &&
                j == length(parts) - 1
            ) {
              storage_path_parts <- c(storage_path_parts, parts[j])
              break
            }
            storage_path_parts <- c(storage_path_parts, parts[j])
          }
          if (length(storage_path_parts)) {
            paste(storage_path_parts, collapse = "/")
          } else {
            remainder
          }
        }
      }

      # Validate that path extraction succeeded
      if (is.null(rel_path) || is.na(rel_path) || !nzchar(rel_path)) {
        cli::cli_warn(c(
          "!" = "Failed to extract path for version {.val {vid}}.",
          "i" = "Storage path: {.file {a_path}}"
        ))
        failed_count <- failed_count + 1L
        next
      }

      vdir <- .st_version_dir(rel_path, vid, alias = alias)

      # Attempt deletion with error handling
      tryCatch(
        {
          .st_delete_version_dir_safe(vdir)
          # Track successful deletion in pre-allocated vector
          deleted_idx <- deleted_idx + 1L
          successfully_deleted[deleted_idx] <- vid
        },
        error = function(e) {
          cli::cli_warn(c(
            "!" = "Failed to delete version directory {.val {vid}}.",
            "i" = "Version dir: {.file {vdir}}",
            "x" = "Error: {e$message}"
          ))
          failed_count <<- failed_count + 1L
        }
      )
    }

    # Trim pre-allocated vector to actual number of successful deletions
    successfully_deleted <- successfully_deleted[seq_len(deleted_idx)]

    # Report on deletion results
    if (failed_count > 0L) {
      cli::cli_alert_warning(
        "{failed_count} out of {nrow(candidates)} version{?s} failed to delete. Catalog will be updated only for successfully deleted versions."
      )
    }

    # Remove only successfully deleted version rows from catalog
    keep_mask <- !(cat$versions$version_id %in% successfully_deleted)
    cat$versions <- cat$versions[keep_mask]

    # Recompute artifacts table (n_versions & latest_version_id)
    # Use vectorized data.table operations instead of row-by-row updates
    # Get unique affected artifact IDs (those with deletions or no remaining versions)
    affected_artifacts <- unique(candidates$artifact_id)

    # For each affected artifact, compute updated stats from remaining versions
    artifact_updates <- cat$versions[
      artifact_id %in% affected_artifacts,
      {
        if (.N == 0L) {
          # No versions remain for this artifact - will be deleted below
          data.table(
            artifact_id = artifact_id[1L],
            n_versions = 0L,
            latest_version_id = NA_character_
          )
        } else {
          # Find newest version (already ordered by created_at desc from merge)
          ord <- order(created_at, decreasing = TRUE)
          list(
            artifact_id = artifact_id[1L],
            n_versions = .N,
            latest_version_id = version_id[ord[1L]]
          )
        }
      },
      by = artifact_id
    ]

    # Update artifacts with new stats (by-reference update)
    for (i in seq_len(nrow(artifact_updates))) {
      aid <- artifact_updates$artifact_id[i]
      if (artifact_updates$n_versions[i] == 0L) {
        # Remove artifacts with no remaining versions
        cat$artifacts <- cat$artifacts[artifact_id != aid]
      } else {
        # Update n_versions and latest_version_id for this artifact
        a_idx <- which(cat$artifacts$artifact_id == aid)
        if (length(a_idx) > 0L) {
          cat$artifacts$latest_version_id[
            a_idx
          ] <- artifact_updates$latest_version_id[i]
          cat$artifacts$n_versions[a_idx] <- artifact_updates$n_versions[i]
        }
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
