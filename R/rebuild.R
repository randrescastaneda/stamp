# ---- Builders registry helpers ----------------------------------------------

# Stable, short key for builder registry (uses secretbase only)
.st_builder_key <- function(path, name = NULL) {
  base <- paste0(.st_norm_path(path), "|", if (is.null(name)) "default" else as.character(name))
  secretbase::siphash13(base)  # 16-hex, fast, stable
}

#' Register a builder for an artifact path
#'
#' A "builder" knows how to (re)create an artifact. It will be called by
#' \code{st_rebuild()} as \code{fun(path, parents)} and must return a list:
#' \preformatted{
#'   list(
#'     x = <object to save>,           # required
#'     format = NULL,                  # optional ("qs2", "rds", ...)
#'     metadata = list(),              # optional, merged into sidecar
#'     code = NULL,                    # optional (function/expr/character)
#'     code_label = NULL               # optional (short description)
#'   )
#' }
#' @param path Character path this builder produces (exact match).
#' @param fun  Function with signature \code{function(path, parents)}.
#' @param name Optional label so you can register multiple builders per path.
#' @return Invisibly TRUE.
#' @export
st_register_builder <- function(path, fun, name = NULL) {
  stopifnot(is.character(path), length(path) == 1L, is.function(fun))
  key <- .st_builder_key(path, name)
  rlang::env_poke(
    .st_builders_env,
    key,
    list(path = .st_norm_path(path), name = if (is.null(name)) "default" else as.character(name), fun = fun)
  )
  cli::cli_inform(c("v" = "Registered builder for {.field {path}} ({.field {if (is.null(name)) 'default' else name}})"))
  invisible(TRUE)
}

#' List registered builders
#' @return data.frame with columns: path, name
#' @export
st_builders <- function() {
  ee <- as.list(.st_builders_env)
  if (!length(ee)) {
    return(data.frame(path = character(), name = character(), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, lapply(ee, function(rec) {
    data.frame(path = rec$path, name = rec$name, stringsAsFactors = FALSE)
  }))
  out[order(out$path, out$name), , drop = FALSE]
}

#' Clear all builders (or only those for a given path)
#' @param path Optional character path; if provided, only builders for that path are removed.
#' @export
st_clear_builders <- function(path = NULL) {
  if (is.null(path)) {
    # Clear whole env safely
    for (nm in names(as.list(.st_builders_env))) {
      rlang::env_unbind(.st_builders_env, nm)
    }
    cli::cli_inform(c("v" = "Cleared all registered builders"))
    return(invisible(TRUE))
  }
  target <- .st_norm_path(path)
  for (nm in names(as.list(.st_builders_env))) {
    rec <- rlang::env_get(.st_builders_env, nm)
    if (identical(rec$path, target)) rlang::env_unbind(.st_builders_env, nm)
  }
  cli::cli_inform(c("v" = "Cleared builders for {.field {path}}"))
  invisible(TRUE)
}

# ---- Internal helpers --------------------------------------------------------

# Read committed parents for the latest version dir; if missing and this is
# a first-level convenience, caller may choose to fall back to sidecar parents.
.st_committed_parents_latest <- function(path) {
  vdir <- .st_version_dir_latest(path)
  if (is.na(vdir) || !nzchar(vdir)) return(list())
  pars <- .st_version_read_parents(vdir)
  # normalize data.frame -> list(list(path=..., version_id=...))
  if (is.data.frame(pars) && nrow(pars) > 0L) {
    pars <- lapply(seq_len(nrow(pars)), function(i) as.list(pars[i, , drop = FALSE]))
  }
  pars
}

# Sidecar parents (quick, non-committed), normalized to list(list(...))
.st_sidecar_parents <- function(path) {
  sc <- tryCatch(st_read_sidecar(path), error = function(e) NULL)
  if (!is.list(sc) || !length(sc$parents)) return(list())
  pars <- sc$parents
  if (is.data.frame(pars) && nrow(pars) > 0L) {
    pars <- lapply(seq_len(nrow(pars)), function(i) as.list(pars[i, , drop = FALSE]))
  }
  pars
}

# Get immediate children from committed lineage
.children_of <- function(p) {
  ch <- tryCatch(st_children(p, depth = 1L), error = function(e) NULL)
  if (is.null(ch) || !nrow(ch)) character(0) else unique(as.character(ch$child_path))
}

# ---- Rebuild -----------------------------------------------------------------

#' Rebuild artifacts from a plan (level order)
#'
#' @param plan A data.frame from \code{st_plan_rebuild(...)} with columns:
#'   \code{level, path, reason, latest_version_before}.
#' @param rebuild_fun Optional function called as:
#'   \code{rebuild_fun(path, parents) -> list(x=..., format=?, metadata=?, code=?, code_label=?)}.
#'   If omitted (NULL), \code{st_rebuild()} will look up a registered builder
#'   for \code{path} (by \code{st_register_builder()}).
#' @param dry_run If TRUE, do not write anything; just report what would happen.
#' @return Invisibly, a data.frame with the build results (status, version_id, msg).
#' @export
st_rebuild <- function(plan, rebuild_fun = NULL, dry_run = FALSE) {
  stopifnot(is.data.frame(plan))
  if (!nrow(plan)) {
    cli::cli_inform(c("v" = "Nothing to rebuild (empty plan)."))
    return(invisible(transform(plan, status = character(), version_id = character(), msg = character())))
  }

  # deterministic order
  plan <- plan[order(plan$level, plan$path), , drop = FALSE]

  # Helper: committed parents; if empty, for level-1 convenience we may use sidecar
  get_parents_for <- function(path, allow_sidecar_fallback = TRUE) {
    pars <- .st_committed_parents_latest(path)
    if (!length(pars) && isTRUE(allow_sidecar_fallback)) {
      pars <- .st_sidecar_parents(path)
    }
    if (!length(pars)) return(list())
    # normalize & refresh version ids to latest of those parents
    lapply(pars, function(p) {
      list(path = .st_norm_path(p$path), version_id = st_latest(p$path))
    })
  }

  # Try to resolve a builder for a given path when rebuild_fun is not provided
  resolve_builder <- function(p) {
    if (is.function(rebuild_fun)) return(rebuild_fun)
    # Search any registered key with exact path
    env_list <- as.list(.st_builders_env)
    for (nm in names(env_list)) {
      rec <- env_list[[nm]]
      if (identical(rec$path, .st_norm_path(p))) return(rec$fun)
    }
    stop(sprintf("No builder registered for path: %s and no rebuild_fun provided.", p), call. = FALSE)
  }

  results <- vector("list", nrow(plan))
  by_level <- split(seq_len(nrow(plan)), plan$level)

  for (lvl in sort(as.integer(names(by_level)))) {
    idxs <- by_level[[as.character(lvl)]]
    cli::cli_inform(c("v" = "Rebuild level {.field {lvl}}: {length(idxs)} artifact{?s}"))

    for (i in idxs) {
      p <- plan$path[[i]]
      reason <- plan$reason[[i]]
      cli::cli_inform(c(" " = "• {.field {p}} ({.field {reason}})"))

      pars <- get_parents_for(p, allow_sidecar_fallback = (lvl == 1L))

      if (isTRUE(dry_run)) {
        cli::cli_inform(c(" " = "  ↳ DRY RUN"))
        results[[i]] <- data.frame(
          level = plan$level[[i]], path = p, reason = reason,
          status = "dry_run", version_id = NA_character_, msg = "",
          stringsAsFactors = FALSE
        )
        next
      }

      fun <- NULL
      err <- NULL
      built <- NULL
      vid <- NA_character_

      # Resolve builder function
      fun <- tryCatch(resolve_builder(p), error = function(e) { err <<- e; NULL })
      if (is.null(fun)) {
        msg <- if (is.null(err)) "No builder available" else conditionMessage(err)
        cli::cli_warn("  ↳ FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]], path = p, reason = reason,
          status = "failed", version_id = NA_character_, msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      # Execute builder
      built <- tryCatch(fun(p, pars), error = function(e) { err <<- e; NULL })
      if (is.null(built) || !is.list(built) || is.null(built$x)) {
        msg <- if (is.null(err)) "builder must return list(x=..., ...)" else conditionMessage(err)
        cli::cli_warn("  ↳ FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]], path = p, reason = reason,
          status = "failed", version_id = NA_character_, msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      # Assemble st_save() args without relying on %||%
      save_args <- list(x = built$x, file = p, parents = pars)
      if (!is.null(built$format))     save_args$format     <- built$format
      if (!is.null(built$metadata))   save_args$metadata   <- built$metadata
      if (!is.null(built$code))       save_args$code       <- built$code
      if (!is.null(built$code_label)) save_args$code_label <- built$code_label

      res <- tryCatch(do.call(st_save, save_args), error = function(e) { err <<- e; NULL })
      if (is.null(res) || is.null(res$version_id)) {
        msg <- if (is.null(err)) "st_save() failed" else conditionMessage(err)
        cli::cli_warn("  ↳ FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]], path = p, reason = reason,
          status = "failed", version_id = NA_character_, msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      vid <- res$version_id
      cli::cli_inform("  ↳ OK @ version {.field {vid}}")
      results[[i]] <- data.frame(
        level = plan$level[[i]], path = p, reason = reason,
        status = "built", version_id = vid, msg = "",
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, results)
  # Summary
  if (nrow(out)) {
    tb <- table(out$status)
    cli::cli_inform(c("v" = "Rebuild summary", " " = paste(names(tb), unname(tb), collapse = " | ")))
  }
  invisible(out)
}

# ---- Plan --------------------------------------------------------------------

#' Plan a rebuild of descendants when parents changed
#'
#' Returns the set of *stale descendants* of \code{targets}.
#' Two modes:
#' \itemize{
#'   \item \code{"propagate"} (default): treat each \code{target} as "will change",
#'         then breadth-first schedule children whose parents intersect the set of nodes
#'         marked "will change". Newly scheduled nodes are also marked "will change"
#'         so their children are considered at the next level.
#'   \item \code{"strict"}: only include nodes already stale against their parents'
#'         \emph{current} latest versions (no propagation).
#' }
#'
#' @param targets Character vector of artifact paths.
#' @param depth Integer depth >= 1, or Inf.
#' @param include_targets Logical; if TRUE and a target is stale, include it at level 0.
#' @param mode "propagate" (default) or "strict".
#' @return data.frame with columns:
#'   level, path, reason, latest_version_before
#' @export
st_plan_rebuild <- function(targets, depth = Inf, include_targets = FALSE,
                            mode = c("propagate", "strict")) {
  mode <- match.arg(mode)
  stopifnot(length(targets) >= 1L, is.numeric(depth), (depth >= 1) || is.infinite(depth))
  targets <- unique(as.character(targets))

  norm <- function(p) .st_norm_path(p)

  planned_paths <- character(0)
  planned_rows  <- list()

  # Seed for propagate mode: targets are considered "will change"
  will_change <- if (mode == "propagate") norm(targets) else character(0)

  # Optionally include targets at level 0
  if (isTRUE(include_targets)) {
    for (p in targets) {
      add_it <- if (mode == "propagate") TRUE else st_is_stale(p)
      if (add_it) {
        planned_paths <- c(planned_paths, p)
        planned_rows[[length(planned_rows) + 1L]] <- data.frame(
          level = 0L,
          path  = p,
          reason = if (mode == "propagate") "upstream_changed" else "parent_changed",
          latest_version_before = st_latest(p),
          stringsAsFactors = FALSE
        )
      }
    }
  }

  frontier <- unique(targets)
  level <- 1L

  while (length(frontier) && (is.infinite(depth) || level <= depth)) {
    # Collect unique immediate children of all frontier nodes
    next_candidates <- unique(unlist(lapply(frontier, .children_of), use.names = FALSE))
    if (!length(next_candidates)) break

    if (mode == "strict") {
      new_stale <- setdiff(next_candidates, planned_paths)
      new_stale <- new_stale[vapply(new_stale, st_is_stale, logical(1))]
      if (length(new_stale)) {
        for (p in new_stale) {
          planned_paths <- c(planned_paths, p)
          planned_rows[[length(planned_rows) + 1L]] <- data.frame(
            level = level,
            path  = p,
            reason = "parent_changed",
            latest_version_before = st_latest(p),
            stringsAsFactors = FALSE
          )
        }
      }
      frontier <- unique(next_candidates)
      level <- level + 1L
      next
    }

    # mode == "propagate"
    to_consider <- setdiff(next_candidates, planned_paths)
    if (length(to_consider)) {
      keep <- vapply(to_consider, function(child) {
        vdir <- .st_version_dir_latest(child)
        pars <- if (!is.na(vdir) && nzchar(vdir)) .st_version_read_parents(vdir) else list()
        if (!length(pars)) pars <- .st_sidecar_parents(child)  # first-level convenience
        if (!length(pars)) return(FALSE)
        if (is.data.frame(pars) && nrow(pars) > 0L) {
          pars <- lapply(seq_len(nrow(pars)), function(i) as.list(pars[i, , drop = FALSE]))
        }
        any(vapply(pars, function(pp) norm(pp$path) %in% will_change, logical(1)))
      }, logical(1))

      new_take <- to_consider[keep]
      if (length(new_take)) {
        for (p in new_take) {
          planned_paths <- c(planned_paths, p)
          planned_rows[[length(planned_rows) + 1L]] <- data.frame(
            level = level,
            path  = p,
            reason = "upstream_changed",
            latest_version_before = st_latest(p),
            stringsAsFactors = FALSE
          )
        }
        # Newly scheduled children are assumed to change → seed their children next
        will_change <- unique(c(will_change, norm(new_take)))
      }
    }

    frontier <- unique(next_candidates)
    level <- level + 1L
  }

  if (!length(planned_rows)) {
    return(data.frame(
      level = integer(), path = character(), reason = character(),
      latest_version_before = character(), stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, planned_rows)
}
