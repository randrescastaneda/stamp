# ---- Builders registry helpers ----------------------------------------------

# Stable, short key for builder registry (uses secretbase only)
.st_builder_key <- function(path, name = NULL) {
  base <- paste0(
    .st_norm_path(path),
    "|",
    if (is.null(name)) "default" else as.character(name)
  )
  secretbase::siphash13(base) # 16-hex, fast, stable
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
    list(
      path = .st_norm_path(path),
      registration_path = path,
      name = if (is.null(name)) "default" else as.character(name),
      fun = fun
    )
  )
  cli::cli_inform(c(
    "v" = "Registered builder for {.field {path}} ({.field {if (is.null(name)) 'default' else name}})"
  ))
  invisible(TRUE)
}

#' List registered builders
#' @return data.frame with columns: path, name
#' @export
st_builders <- function() {
  ee <- as.list(.st_builders_env)
  if (!length(ee)) {
    return(data.frame(
      path = character(),
      name = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(
    rbind,
    lapply(ee, function(rec) {
      data.frame(path = rec$path, name = rec$name, stringsAsFactors = FALSE)
    })
  )
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
.st_committed_parents_latest <- function(path, alias = NULL) {
  # Normalize path to get rel_path for version operations
  norm <- .st_normalize_user_path(path, alias = alias, must_exist = FALSE)
  rel_path <- norm$rel_path
  versioning_alias <- norm$alias

  vdir <- .st_version_dir_latest(rel_path, alias = versioning_alias)
  if (is.na(vdir) || !nzchar(vdir)) {
    return(list())
  }
  pars <- .st_version_read_parents(vdir)
  # normalize data.frame -> list(list(path=..., version_id=...))
  if (is.data.frame(pars) && nrow(pars) > 0L) {
    pars <- lapply(seq_len(nrow(pars)), function(i) {
      as.list(pars[i, , drop = FALSE])
    })
  }
  pars
}

# Sidecar parents (quick, non-committed), normalized to list(list(...))
.st_sidecar_parents <- function(path, alias = NULL) {
  # Normalize path to get rel_path for sidecar operations
  norm <- .st_normalize_user_path(path, alias = alias, must_exist = FALSE)
  rel_path <- norm$rel_path
  versioning_alias <- norm$alias

  sc <- tryCatch(
    st_read_sidecar(rel_path, alias = versioning_alias),
    error = function(e) NULL
  )
  if (!is.list(sc) || !length(sc$parents)) {
    return(list())
  }
  pars <- sc$parents
  if (is.data.frame(pars) && nrow(pars) > 0L) {
    pars <- lapply(seq_len(nrow(pars)), function(i) {
      as.list(pars[i, , drop = FALSE])
    })
  }
  pars
}

# Get immediate children from committed lineage
.children_of <- function(p) {
  ch <- tryCatch(st_children(p, depth = 1L), error = function(e) NULL)
  if (is.null(ch) || !nrow(ch)) {
    character(0)
  } else {
    unique(as.character(ch$child_path))
  }
}

# ---- Rebuild -----------------------------------------------------------------

#' Rebuild planned artifacts in dependency order
#'
#' @param plan A data.frame from \code{st_plan_rebuild(...)} with columns:
#'   \code{level, path, reason, latest_version_before}.
#'   Request-bearing plans additionally contain a request list-column and
#'   decision, request_id and receipt_id. Every selected row is revalidated,
#'   including preview skips, after its selected prerequisites finish.
#' @param rebuild_fun Optional function called as:
#'   \code{rebuild_fun(path, parents) -> list(x=..., format=?, metadata=?, code=?, code_label=?)}.
#'   If omitted (NULL), \code{st_rebuild()} will look up a registered builder
#'   for \code{path} (by \code{st_register_builder()}).
#'   On the request route the builder must return exactly one non-NULL `x` field;
#'   optional format must equal the request's registered identifier, and semantic
#'   metadata must match it. The builder receives fully resolved exact parents.
#' @param dry_run If TRUE, invoke no builders and write no outcomes/receipts.
#'   Reports a preview, not successful execution evidence.
#' @return Invisibly, a data.frame with level, path, reason, status, version_id
#'   and msg.
#'   Request-aware results also include request_id, receipt_id and outcome_id.
#'   Their statuses are built, unchanged, skipped, blocked, failed and dry_run.
#'   Only validated successful or reused outputs have a usable version_id.
#' @details
#' Request-aware execution revalidates each candidate after actual upstream
#' results. A changed parent alone can require an actual builder call while
#' retaining equal output and publishing a new receipt; original snapshot
#' provenance is not rewritten. A satisfied repeat writes neither a receipt nor
#' a version. Missing builder configuration is recoverable blocked work, not an
#' actual unknown execution failure. Invoked builder errors inheriting
#' `stamp_deterministic_failure` or `stamp_external_failure` retain that class;
#' other actual failures are unknown and block further execution.
#'
#' Deterministic recovery requires both changed input/component proof and
#' `request$review$outcome_id` naming the governing deterministic failure.
#' Intervening blocked observations do not replace that failure. External
#' failures permit one attempt on the next analyst-started rebuild with valid
#' prerequisites; no automatic retry is scheduled. There is no Force interface.
#' @export
st_rebuild <- function(plan, rebuild_fun = NULL, dry_run = FALSE) {
  stopifnot(is.data.frame(plan))
  if ("request" %in% names(plan)) {
    return(invisible(.st_rebuild_requests(plan, rebuild_fun, dry_run)))
  }
  if (!nrow(plan)) {
    cli::cli_inform(c("v" = "Nothing to rebuild (empty plan)."))
    return(invisible(transform(
      plan,
      status = character(),
      version_id = character(),
      msg = character()
    )))
  }

  # deterministic order
  plan <- plan[order(plan$level, plan$path), , drop = FALSE]

  # Helper: committed parents; if empty, for level-1 convenience we may use sidecar
  get_parents_for <- function(path, allow_sidecar_fallback = TRUE) {
    pars <- .st_committed_parents_latest(path)
    if (!length(pars) && isTRUE(allow_sidecar_fallback)) {
      pars <- .st_sidecar_parents(path)
    }
    if (!length(pars)) {
      return(list())
    }
    # normalize & refresh version ids to latest of those parents
    lapply(pars, function(p) {
      list(path = .st_norm_path(p$path), version_id = st_latest(p$path))
    })
  }

  # Try to resolve a builder for a given path when rebuild_fun is not provided
  resolve_builder <- function(p) {
    if (is.function(rebuild_fun)) {
      return(rebuild_fun)
    }
    # Search any registered key with exact path
    env_list <- as.list(.st_builders_env)
    for (nm in names(env_list)) {
      rec <- env_list[[nm]]
      if (identical(rec$path, .st_norm_path(p))) return(rec$fun)
    }
    stop(
      sprintf(
        "No builder registered for path: %s and no rebuild_fun provided.",
        p
      ),
      call. = FALSE
    )
  }

  results <- vector("list", nrow(plan))
  by_level <- split(seq_len(nrow(plan)), plan$level)

  for (lvl in sort(as.integer(names(by_level)))) {
    idxs <- by_level[[as.character(lvl)]]
    cli::cli_inform(c(
      "v" = "Rebuild level {.field {lvl}}: {length(idxs)} artifact{?s}"
    ))

    for (i in idxs) {
      p <- plan$path[[i]]
      reason <- plan$reason[[i]]
      cli::cli_inform(c(
        " " = "{cli:::symbol$bullet} {.field {p}} ({.field {reason}})"
      ))

      pars <- get_parents_for(p, allow_sidecar_fallback = (lvl == 1L))

      if (isTRUE(dry_run)) {
        cli::cli_inform(c(" " = "  DRY RUN"))
        results[[i]] <- data.frame(
          level = plan$level[[i]],
          path = p,
          reason = reason,
          status = "dry_run",
          version_id = NA_character_,
          msg = "",
          stringsAsFactors = FALSE
        )
        next
      }

      fun <- NULL
      err <- NULL
      built <- NULL
      vid <- NA_character_

      # Resolve builder function
      fun <- tryCatch(resolve_builder(p), error = function(e) {
        err <<- e
        NULL
      })
      if (is.null(fun)) {
        msg <- if (is.null(err)) {
          "No builder available"
        } else {
          conditionMessage(err)
        }
        cli::cli_warn("   FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]],
          path = p,
          reason = reason,
          status = "failed",
          version_id = NA_character_,
          msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      # Execute builder
      built <- tryCatch(fun(p, pars), error = function(e) {
        err <<- e
        NULL
      })
      if (is.null(built) || !is.list(built) || is.null(built$x)) {
        msg <- if (is.null(err)) {
          "builder must return list(x=..., ...)"
        } else {
          conditionMessage(err)
        }
        cli::cli_warn("   FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]],
          path = p,
          reason = reason,
          status = "failed",
          version_id = NA_character_,
          msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      # Assemble st_save() args without relying on %||%
      save_args <- list(x = built$x, file = p, parents = pars)
      if (!is.null(built$format)) {
        save_args$format <- built$format
      }
      if (!is.null(built$metadata)) {
        save_args$metadata <- built$metadata
      }
      if (!is.null(built$code)) {
        save_args$code <- built$code
      }
      if (!is.null(built$code_label)) {
        save_args$code_label <- built$code_label
      }

      res <- tryCatch(do.call(st_save, save_args), error = function(e) {
        err <<- e
        NULL
      })
      if (is.null(res) || is.null(res$version_id)) {
        msg <- if (is.null(err)) "st_save() failed" else conditionMessage(err)
        cli::cli_warn("   FAILED: {msg}")
        results[[i]] <- data.frame(
          level = plan$level[[i]],
          path = p,
          reason = reason,
          status = "failed",
          version_id = NA_character_,
          msg = msg,
          stringsAsFactors = FALSE
        )
        next
      }

      vid <- res$version_id
      cli::cli_inform("   OK @ version {.field {vid}}")
      results[[i]] <- data.frame(
        level = plan$level[[i]],
        path = p,
        reason = reason,
        status = "built",
        version_id = vid,
        msg = "",
        stringsAsFactors = FALSE
      )
    }
  }

  out <- do.call(rbind, results)
  # Summary
  if (nrow(out)) {
    tb <- table(out$status)
    cli::cli_inform(c(
      "v" = "Rebuild summary",
      " " = paste(names(tb), unname(tb), collapse = " | ")
    ))
  }
  invisible(out)
}

# ---- Plan --------------------------------------------------------------------

#' Plan a rebuild of descendants when parents changed
#'
#' With \code{requests = NULL}, returns the set of *stale descendants* of
#' \code{targets}. Two legacy modes:
#' \itemize{
#'   \item \code{"propagate"} (default): treat each \code{target} as "will change",
#'         then breadth-first schedule children whose parents intersect the set of nodes
#'         marked "will change". Newly scheduled nodes are also marked "will change"
#'         so their children are considered at the next level.
#'   \item \code{"strict"}: only include nodes already stale against their parents'
#'         \emph{current} latest versions (no propagation).
#' }
#' With explicit requests, uses their current dependency graph and retains every
#' selected run, skip and blocked candidate. The mode does not change this
#' selection. Rebuild re-evaluates every selected candidate after actual upstream
#' outcomes, including candidates that were current in the preview.
#'
#' @param targets Character vector of artifact paths.
#' @param depth Integer depth >= 1, or Inf.
#' @param include_targets Logical; on the legacy route, include a target at level
#'   0 when stale (or assumed to change in propagate mode). With requests, include
#'   every target at level 0 and require an explicit normalized recipe for each.
#' @param mode "propagate" (default) or "strict". Controls only legacy planning
#'   when requests is NULL; explicit requests determine their own currentness.
#' @param requests Optional unnamed list of explicit calculation requests.
#'   NULL preserves legacy planning. Requests define current graph edges and
#'   include recipes for missing outputs. Selected deferred parents are resolved
#'   to validated output pins before execution. Planning never writes state.
#' @details
#' Each request is a named list with exactly these required fields:
#' \itemize{
#'   \item `schema`: integer `1L`; `path`: artifact logical path within its alias.
#'   \item `root`: logical scalar; `parents`: unnamed list of records containing
#'     `path` and exact `version_id`. Empty parents require root TRUE. In a
#'     preview only, NULL pins may name explicit selected recipes that will run.
#'   \item `required_components`: unique character IDs including `calculation`;
#'     `components`: named list with exactly those IDs. Each descriptor contains
#'     nonempty `hash`, `algorithm` and caller canonicalization `schema` strings.
#'     Algorithms are `siphash13` (16 lowercase hex characters) or `sha256` (64).
#'   \item `semantic_schema` and `semantic`: descriptors as in [st_save()] and a
#'     uniquely named list of their typed values, with no undeclared fields.
#'     With no semantic fields, use NULL schema and `list()` values.
#'   \item `format`: exact case-sensitive registered [st_formats()] identifier.
#' }
#' Optional `audit` is a named list of scalar source-identity strings. Optional
#' `review` is `list(outcome_id = <governing failure ID>)`. Neither enters request
#' equality. Unknown/duplicated fields are invalid. Paths and parent/component
#' ordering are canonicalized; semantic types and declared shapes are retained.
#'
#' Callers must cover all known result-affecting helpers, constants and rules,
#' not just a source label. Stamp validates declared proof; it does not discover
#' hidden closure dependencies. Valid complete requests can recover absent
#' legacy proof, but legacy parent-only inspection is not complete currentness.
#' Contradictory committed modern proof blocks rather than silently recovering.
#' Serial isolated publication is supported, not SMB or multiwriter guarantees.
#' @return data.frame with columns:
#'   level, path, reason, latest_version_before
#'   With requests, adds request (list-column), decision (run, skip, blocked),
#'   request_id and receipt_id; includes current skips and blocked candidates.
#' @export
st_plan_rebuild <- function(
  targets,
  depth = Inf,
  include_targets = FALSE,
  mode = c("propagate", "strict"),
  requests = NULL
) {
  mode <- match.arg(mode)
  if (!is.null(requests)) {
    return(.st_plan_requests(targets, depth, include_targets, requests))
  }
  stopifnot(
    length(targets) >= 1L,
    is.numeric(depth),
    (depth >= 1) || is.infinite(depth)
  )
  targets <- unique(as.character(targets))

  norm <- function(p) .st_norm_path(p)

  planned_paths <- character(0)
  planned_rows <- list()

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
          path = p,
          reason = if (mode == "propagate") {
            "upstream_changed"
          } else {
            "parent_changed"
          },
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
    next_candidates <- unique(unlist(
      lapply(frontier, .children_of),
      use.names = FALSE
    ))
    if (!length(next_candidates)) {
      break
    }

    if (mode == "strict") {
      new_stale <- setdiff(next_candidates, planned_paths)
      new_stale <- new_stale[vapply(new_stale, st_is_stale, logical(1))]
      if (length(new_stale)) {
        for (p in new_stale) {
          planned_paths <- c(planned_paths, p)
          planned_rows[[length(planned_rows) + 1L]] <- data.frame(
            level = level,
            path = p,
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
      keep <- vapply(
        to_consider,
        function(child) {
          # Normalize child path to get rel_path for version operations
          norm_child <- .st_normalize_user_path(
            child,
            alias = NULL,
            must_exist = FALSE
          )
          child_rel_path <- norm_child$rel_path
          child_alias <- norm_child$alias

          vdir <- .st_version_dir_latest(child_rel_path, alias = child_alias)
          pars <- if (!is.na(vdir) && nzchar(vdir)) {
            .st_version_read_parents(vdir)
          } else {
            list()
          }
          if (!length(pars)) {
            pars <- .st_sidecar_parents(child, alias = child_alias)
          } # first-level convenience
          if (!length(pars)) {
            return(FALSE)
          }
          if (is.data.frame(pars) && nrow(pars) > 0L) {
            pars <- lapply(seq_len(nrow(pars)), function(i) {
              as.list(pars[i, , drop = FALSE])
            })
          }
          any(vapply(
            pars,
            function(pp) norm(pp$path) %in% will_change,
            logical(1)
          ))
        },
        logical(1)
      )

      new_take <- to_consider[keep]
      if (length(new_take)) {
        for (p in new_take) {
          planned_paths <- c(planned_paths, p)
          planned_rows[[length(planned_rows) + 1L]] <- data.frame(
            level = level,
            path = p,
            reason = "upstream_changed",
            latest_version_before = st_latest(p),
            stringsAsFactors = FALSE
          )
        }
        # Newly scheduled children are assumed to change --> seed their children next
        will_change <- unique(c(will_change, norm(new_take)))
      }
    }

    new_frontier <- setdiff(unique(next_candidates), planned_paths)
    if (length(new_frontier) == 0L) {
      break
    }
    frontier <- new_frontier
    level <- level + 1L
  }

  if (!length(planned_rows)) {
    return(data.frame(
      level = integer(),
      path = character(),
      reason = character(),
      latest_version_before = character(),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, planned_rows)
}

# Validate identities and cycles before selection, execution or any write.
.st_rebuild_graph <- function(requests) {
  if (!is.list(requests) || is.object(requests) ||
      !is.null(names(requests))) {
    .st_request_abort("invalid_request", "Requests must be an unnamed list.")
  }
  norms <- lapply(requests, function(request) {
    if (!is.list(request)) {
      .st_request_abort("invalid_request", "A recipe must be a request list.")
    }
    norm <- .st_normalize_user_path(request$path,
      must_exist = FALSE, verbose = FALSE)
    .st_execution_path(request$path, norm$alias)
  })
  paths <- vapply(norms, `[[`, character(1L), "logical_path")
  if (anyDuplicated(paths)) {
    .st_request_abort("invalid_request", "Duplicate normalized recipe identity.")
  }
  parents <- lapply(seq_along(requests), function(i) {
    raw <- requests[[i]]$parents
    if (!is.list(raw)) return(character())
    unique(unlist(lapply(raw, function(parent) {
      if (!is.list(parent) || !.st_proof_string(parent$path)) return(NULL)
      .st_execution_path(parent$path, norms[[i]]$alias)$logical_path
    }), use.names = FALSE))
  })
  remaining <- seq_along(paths)
  ordered <- integer()
  while (length(remaining)) {
    ready <- remaining[vapply(remaining, function(i) {
      !any(parents[[i]] %in% paths[remaining])
    }, logical(1L))]
    if (!length(ready)) .st_request_abort("cycle", "Cyclic request graph.")
    take <- ready[order(paths[ready], method = "radix")][[1L]]
    ordered <- c(ordered, take)
    remaining <- setdiff(remaining, take)
  }
  return(list(norms = norms, paths = paths, parents = parents,
    order = ordered))
}

.st_plan_requests <- function(targets, depth, include_targets, requests) {
  stopifnot(is.character(targets), length(targets) >= 1L,
    is.numeric(depth), length(depth) == 1L, !is.na(depth), depth >= 1,
    is.logical(include_targets), length(include_targets) == 1L,
    !is.na(include_targets))
  graph <- .st_rebuild_graph(requests)
  targets <- unique(vapply(targets, function(path) {
    norm <- .st_normalize_user_path(path, must_exist = FALSE, verbose = FALSE)
    .st_execution_path(path, norm$alias)$logical_path
  }, character(1L)))
  if (include_targets && any(!targets %in% graph$paths)) {
    .st_request_abort("invalid_request", "Every included target needs a recipe.")
  }
  levels <- rep(Inf, length(requests))
  levels[graph$paths %in% targets] <- 0
  frontier <- targets
  visited <- targets
  level <- 1L
  while (length(frontier) && level <= depth) {
    children <- which(vapply(graph$parents, function(parents) {
      any(parents %in% frontier)
    }, logical(1L)) & !graph$paths %in% visited)
    levels[children] <- level
    frontier <- graph$paths[children]
    visited <- c(visited, frontier)
    level <- level + 1L
  }
  selected <- graph$order[is.finite(levels[graph$order]) &
    (include_targets | levels[graph$order] > 0)]
  out <- data.frame(level = integer(), path = character(), reason = character(),
    latest_version_before = character(), decision = character(),
    request_id = character(), receipt_id = character(),
    stringsAsFactors = FALSE)
  out$request <- I(list())
  decisions <- vector("list", length(requests))
  parent_versions <- list()
  for (i in selected) {
    request <- requests[[i]]
    failed <- FALSE
    pending <- character()
    if (is.list(request$parents)) {
      for (j in seq_along(request$parents)) {
        parent <- request$parents[[j]]
        if (!is.list(parent) || !.st_proof_string(parent$path)) next
        path <- .st_execution_path(parent$path, graph$norms[[i]]$alias)$logical_path
        index <- match(path, graph$paths)
        if (!is.na(index) && index %in% selected) {
          prior <- decisions[[index]]
          if (prior$decision == "blocked") failed <- TRUE
          if (prior$decision == "run") pending <- c(pending, path)
          if (is.null(parent$version_id) && prior$decision == "skip") {
            request$parents[[j]]$version_id <- prior$version_id
          }
        }
      }
    }
    decision <- .st_execution_decide(request, graph$norms[[i]]$alias, pending)
    if (failed && !decision$reason %in% c("invalid_request",
        "missing_requested_proof", "incomparable_proof", "invalid_state")) {
      decision$decision <- "blocked"
      decision$reason <- "failed_parent"
    }
    decisions[[i]] <- decision
    row <- data.frame(level = as.integer(levels[[i]]), path = graph$paths[[i]],
      reason = decision$reason,
      latest_version_before = decision$latest_version_before,
      decision = decision$decision, request_id = decision$request_id,
      receipt_id = decision$receipt_id, stringsAsFactors = FALSE)
    row$request <- I(list(decision$request))
    out <- rbind(out, row)
    for (path in graph$parents[[i]]) {
      parent_versions[[path]] <- tryCatch(
        st_latest(path, alias = graph$norms[[i]]$alias),
        error = function(e) NA_character_)
    }
  }
  # The preview baseline is not the requested pin: historical inputs are valid.
  attr(out, "stamp_parent_versions") <- parent_versions
  return(out)
}

.st_rebuild_requests <- function(plan, rebuild_fun, dry_run) {
  stopifnot(all(c("level", "path", "reason", "request") %in% names(plan)),
    is.logical(dry_run), length(dry_run) == 1L, !is.na(dry_run))
  if (!is.null(rebuild_fun) && !is.function(rebuild_fun)) {
    .st_request_abort("invalid_request", "rebuild_fun must be a function.")
  }
  requests <- lapply(seq_len(nrow(plan)), function(i) plan$request[[i]])
  graph <- .st_rebuild_graph(requests)
  if (!identical(as.character(plan$path), graph$paths)) {
    .st_request_abort("invalid_request", "Plan paths and recipe identities differ.")
  }
  out <- data.frame(level = plan$level, path = plan$path, reason = plan$reason,
    status = rep("dry_run", nrow(plan)), version_id = rep(NA_character_, nrow(plan)),
    msg = rep("", nrow(plan)), request_id = rep(NA_character_, nrow(plan)),
    receipt_id = rep(NA_character_, nrow(plan)),
    outcome_id = rep(NA_character_, nrow(plan)), stringsAsFactors = FALSE)
  if (dry_run || !nrow(plan)) return(out)
  parent_versions <- attr(plan, "stamp_parent_versions", exact = TRUE)
  if (!is.list(parent_versions)) {
    .st_request_abort("invalid_request", "Plan parent preview baseline is missing.")
  }
  for (i in graph$order) {
    request <- requests[[i]]
    alias <- graph$norms[[i]]$alias
    failed <- FALSE
    changed <- FALSE
    if (is.list(request$parents)) {
      for (j in seq_along(request$parents)) {
        parent <- request$parents[[j]]
        if (!is.list(parent) || !.st_proof_string(parent$path)) next
        path <- .st_execution_path(parent$path, alias)$logical_path
        index <- match(path, graph$paths)
        if (!is.na(index)) {
          if (out$status[[index]] %in% c("built", "unchanged", "skipped")) {
            if (is.null(parent$version_id) || out$status[[index]] != "skipped") {
              request$parents[[j]]$version_id <- out$version_id[[index]]
            }
            latest <- tryCatch(st_latest(path, alias), error = identity)
            if (!inherits(latest, "error") &&
                !identical(latest, out$version_id[[index]])) changed <- TRUE
          } else failed <- TRUE
        } else if (!is.null(parent$version_id)) {
          latest <- tryCatch(st_latest(path, alias), error = identity)
          if (!inherits(latest, "error") &&
              !identical(latest, parent_versions[[path]])) changed <- TRUE
        }
      }
    }
    decision <- .st_execution_decide(request, alias)
    if ((failed || changed) && !decision$reason %in% c("invalid_request",
        "missing_requested_proof", "incomparable_proof", "invalid_state")) {
      decision$decision <- "blocked"
      decision$reason <- if (failed) "failed_parent" else "inputs_changed"
    }
    request <- decision$request
    configuration_error <- FALSE
    fun <- rebuild_fun
    if (decision$decision == "run") {
      if (is.null(fun)) {
        matches <- Filter(function(rec) {
          registered <- tryCatch(
            .st_execution_path(rec$registration_path, alias)$logical_path,
            error = function(e) NULL)
          identical(registered, graph$paths[[i]])
        }, as.list(.st_builders_env))
        if (length(matches)) fun <- matches[[1L]]$fun
      }
      if (!is.function(fun)) {
        configuration_error <- TRUE
        decision$decision <- "blocked"
        decision$reason <- "invalid_request"
        decision$msg <- "No valid builder registered for artifact."
      }
    }
    out$reason[[i]] <- decision$reason
    out$request_id[[i]] <- decision$request_id
    out$msg[[i]] <- decision$msg
    if (decision$decision == "skip") {
      out$status[[i]] <- "skipped"
      out$version_id[[i]] <- decision$version_id
      out$receipt_id[[i]] <- decision$receipt_id
      out$outcome_id[[i]] <- decision$outcome_id
      next
    }
    if (decision$decision == "blocked") {
      out$status[[i]] <- "blocked"
      # Invalid templates/chains cannot receive a structurally valid record.
      if (configuration_error || !decision$reason %in%
          c("invalid_request", "missing_requested_proof", "invalid_state")) {
        recorded <- tryCatch(.st_execution_append(graph$paths[[i]], "blocked",
          request, failure = list(class = "unknown", message = decision$reason),
          alias = alias, allow_deferred = TRUE), error = identity)
        if (inherits(recorded, "error")) {
          out$status[[i]] <- "failed"
          out$reason[[i]] <- "publication_failed"
          out$msg[[i]] <- conditionMessage(recorded)
        } else out$outcome_id[[i]] <- recorded$id
      }
      next
    }
    # The selector's validation context is gone before invoking user code.
    built <- tryCatch({
      value <- fun(graph$paths[[i]], request$parents)
      if (!is.list(value) || sum(names(value) == "x", na.rm = TRUE) != 1L ||
          is.null(value[["x", exact = TRUE]])) {
        rlang::abort("Builder must return exactly one named x field.")
      }
      value
    }, error = identity)
    if (inherits(built, "error")) {
      class <- if (inherits(built, "stamp_deterministic_failure")) {
        "deterministic"
      } else if (inherits(built, "stamp_external_failure")) "external" else "unknown"
      failure <- list(class = class, message = conditionMessage(built))
      out$status[[i]] <- "failed"
      out$msg[[i]] <- failure$message
      recorded <- tryCatch(.st_execution_append(graph$paths[[i]],
        paste0("failed_", class), request, failure = failure, alias = alias),
        error = identity)
      if (inherits(recorded, "error")) {
        out$reason[[i]] <- "publication_failed"
        out$msg[[i]] <- conditionMessage(recorded)
      } else out$outcome_id[[i]] <- recorded$id
      next
    }
    published <- tryCatch({
      args <- list(x = built[["x", exact = TRUE]],
        file = graph$paths[[i]], alias = alias,
        parents = request$parents, request = request, verbose = FALSE)
      for (field in c("format", "metadata", "code", "code_label")) {
        if (!is.null(built[[field, exact = TRUE]])) {
          args[[field]] <- built[[field, exact = TRUE]]
        }
      }
      saved <- do.call(st_save, args)
      .st_execution_success(graph$paths[[i]], request, saved, alias)
    }, error = identity)
    if (inherits(published, "error")) {
      out$status[[i]] <- "failed"
      out$reason[[i]] <- "publication_failed"
      out$msg[[i]] <- conditionMessage(published)
      recorded <- tryCatch(.st_execution_append(graph$paths[[i]],
        "failed_unknown", request, failure = list(class = "unknown",
          message = conditionMessage(published)), alias = alias), error = identity)
      if (!inherits(recorded, "error")) out$outcome_id[[i]] <- recorded$id
      next
    }
    out$status[[i]] <- if (published$outcome == "success_unchanged") {
      "unchanged"
    } else "built"
    out$version_id[[i]] <- published$output$version_id
    out$receipt_id[[i]] <- published$id
    out$outcome_id[[i]] <- published$id
  }
  return(out[graph$order, , drop = FALSE])
}
