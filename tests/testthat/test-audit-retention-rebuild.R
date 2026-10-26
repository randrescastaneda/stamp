test_that("builder registration, replacement, listing and clearing are exact", {
  local_stamp_state()
  local_st_opts()
  st_clear_builders()
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  p <- file.path(root, "a.rds")
  q <- file.path(root, "b.rds")
  expect_identical(
    st_builders(),
    data.frame(path = character(), name = character())
  )
  fun <- function(path, parents) list(x = 1L)
  expect_true(st_register_builder(p, fun))
  expect_true(st_register_builder(p, fun, name = "other"))
  expect_true(st_register_builder(q, fun))
  expect_true(st_register_builder(p, function(path, parents) list(x = 2L)))
  builders <- st_builders()
  expect_equal(builders$path, stamp:::.st_norm_path(c(p, p, q)))
  expect_equal(builders$name, c("default", "other", "default"))
  expect_identical(
    stamp:::.st_builder_key(p),
    stamp:::.st_builder_key(p, "default")
  )
  expect_false(identical(
    stamp:::.st_builder_key(p),
    stamp:::.st_builder_key(p, "other")
  ))
  expect_true(st_clear_builders(p))
  expect_equal(st_builders()$path, stamp:::.st_norm_path(q))
  expect_true(st_clear_builders())
  expect_equal(nrow(st_builders()), 0L)
  expect_error(st_register_builder(character(), fun))
  expect_error(st_register_builder(c(p, q), fun))
  expect_error(st_register_builder(p, 1))
})

test_that("rebuild plans cover chains, diamonds, unequal depths and roots", {
  local_stamp_state()
  local_st_opts()
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  paths <- setNames(
    stamp:::.st_rebuild_path(file.path(root, paste0(letters[1:6], ".rds"))),
    LETTERS[1:6]
  )
  # A-B-D and A-C-E-D: D must wait for E, not its shortest path from A.
  graph <- list(
    A = c("B", "C"),
    B = "D",
    C = "E",
    E = "D",
    D = character(),
    F = "C"
  )
  parents <- function(path, ...) {
    node <- names(paths)[match(path, paths)]
    incoming <- names(graph)[vapply(graph, function(x) node %in% x, logical(1))]
    lapply(unname(paths[incoming]), function(p) {
      list(path = p, version_id = "v")
    })
  }
  visits <- 0L
  audit_local_bindings(
    .children_of = function(p) {
      visits <<- visits + 1L
      if (visits > 50L) {
        stop("cycle traversal revisits nodes")
      }
      unname(paths[graph[[names(paths)[match(p, paths)]]]])
    },
    .st_normalize_user_path = function(path, ...) {
      list(rel_path = path, alias = NULL)
    },
    .st_version_dir_latest = function(path, ...) path,
    .st_version_read_parents = parents,
    .st_committed_parents_latest = parents,
    st_latest = function(...) "v",
    st_is_stale = function(path, ...) path == paths[["B"]]
  )
  plan <- st_plan_rebuild(paths[["A"]])
  expect_equal(plan$path, unname(paths[c("B", "C", "E", "D")]))
  expect_equal(plan$level, c(1L, 1L, 2L, 3L))
  expect_equal(plan$reason, rep("upstream_changed", 4L))
  expect_equal(plan$latest_version_before, rep("v", 4L))
  expect_equal(
    st_plan_rebuild(paths[["A"]], depth = 1)$path,
    unname(paths[c("B", "C")])
  )
  expect_equal(
    st_plan_rebuild(paths[["A"]], mode = "strict")$path,
    paths[["B"]]
  )
  included <- st_plan_rebuild(paths[["A"]], include_targets = TRUE)
  expect_equal(included$path[1], paths[["A"]])
  expect_equal(included$level[1], 0L)
  multiple <- st_plan_rebuild(unname(paths[c("A", "F")]))
  expect_setequal(multiple$path, unname(paths[c("B", "C", "D", "E")]))
  expect_equal(anyDuplicated(multiple$path), 0L)
  expect_equal(nrow(st_plan_rebuild(paths[["D"]])), 0L)
  expect_error(st_plan_rebuild(paths[["A"]], mode = "bad"))
  expect_error(st_plan_rebuild(paths[["A"]], depth = 0))
  expect_error(st_plan_rebuild(paths[["A"]], depth = -Inf))
  expect_error(st_plan_rebuild(paths[["A"]], depth = NA_real_))
  expect_error(st_plan_rebuild(paths[["A"]], depth = c(1, 2)))
  expect_error(st_plan_rebuild(paths[["A"]], depth = 1.5))
  # Symmetric diamond and chain are independent graph shapes.
  graph$C <- "D"
  graph$E <- character()
  diamond <- st_plan_rebuild(paths[["A"]])
  expect_equal(diamond$path, unname(paths[c("B", "C", "D")]))
  expect_equal(diamond$level, c(1L, 1L, 2L))
  graph$A <- "B"
  graph$B <- "C"
  graph$C <- character()
  expect_equal(st_plan_rebuild(paths[["A"]])$path, unname(paths[c("B", "C")]))
  # A cycle has no topological order; traversal must still terminate uniquely.
  graph$C <- "A"
  for (mode in c("strict", "propagate")) {
    visits <- 0L
    cyclic <- st_plan_rebuild(paths[["A"]], mode = mode)
    expect_equal(anyDuplicated(cyclic$path), 0L)
    expect_true(nrow(cyclic) <= 3L)
    expect_true(paths[["B"]] %in% cyclic$path)
  }
})

test_that("parent readers normalize tables and handle missing lineage", {
  local_stamp_state()
  local_st_opts()
  root <- withr::local_tempdir()
  st_init(root)
  p <- file.path(root, "a.rds")
  expect_equal(stamp:::.st_committed_parents_latest(p), list())
  expect_equal(stamp:::.st_sidecar_parents(p), list())
  expect_equal(stamp:::.children_of(p), character())
  tab <- data.frame(path = "parent", version_id = "v1")
  audit_local_bindings(
    .st_version_dir_latest = function(...) "snapshot",
    .st_version_read_parents = function(...) tab,
    st_read_sidecar = function(...) list(parents = tab),
    st_children = function(...) stop("unreadable catalog")
  )
  expected <- list(list(path = "parent", version_id = "v1"))
  expect_equal(stamp:::.st_committed_parents_latest(p), expected)
  expect_equal(stamp:::.st_sidecar_parents(p), expected)
  expect_equal(stamp:::.children_of(p), character())
  tab <- tab[FALSE, ]
  expect_equal(stamp:::.st_committed_parents_latest(p), list())
  expect_equal(stamp:::.st_sidecar_parents(p), list())
  audit_local_bindings(st_children = function(...) {
    data.frame(child_path = c("b", "b", "c"))
  })
  expect_equal(stamp:::.children_of(p), c("b", "c"))
  audit_local_bindings(st_read_sidecar = function(...) stop("bad sidecar"))
  expect_equal(stamp:::.st_sidecar_parents(p), list())
})

test_that("planner uses sidecar fallback and excludes children with no parents", {
  local_stamp_state()
  local_st_opts()
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  paths <- setNames(
    stamp:::.st_rebuild_path(file.path(root, letters[1:4])),
    LETTERS[1:4]
  )
  graph <- list(A = c("B", "C"), B = "D", C = character(), D = character())
  audit_local_bindings(
    .children_of = function(p) {
      unname(paths[graph[[names(paths)[match(p, paths)]]]])
    },
    .st_normalize_user_path = function(path, ...) {
      list(rel_path = path, alias = NULL)
    },
    .st_version_dir_latest = function(...) NA_character_,
    .st_committed_parents_latest = function(...) list(),
    .st_sidecar_parents = function(path, ...) {
      if (path == paths[["B"]]) {
        return(list(list(path = paths[["A"]])))
      }
      if (path == paths[["D"]]) {
        return(list(list(path = paths[["B"]])))
      }
      list()
    },
    st_latest = function(...) "v1"
  )
  plan <- st_plan_rebuild(paths[["A"]])
  expect_equal(plan$path, unname(paths[c("B", "D")]))
  expect_equal(plan$level, c(1L, 2L))
  audit_local_bindings(
    .st_version_dir_latest = function(path, ...) path,
    .st_version_read_parents = function(path, ...) {
      if (path == paths[["B"]]) {
        return(data.frame(path = paths[["A"]]))
      }
      if (path == paths[["D"]]) {
        return(data.frame(path = paths[["B"]]))
      }
      list()
    }
  )
  expect_equal(st_plan_rebuild(paths[["A"]]), plan)
})

test_that("rebuild sidecar fallback and optional arguments reach the save boundary", {
  local_stamp_state()
  local_st_opts()
  root <- withr::local_tempdir()
  paths <- stamp:::.st_norm_path(file.path(root, c("a.rds", "b.rds")))
  plan <- data.frame(
    level = c(1L, 2L),
    path = paths,
    reason = "audit",
    latest_version_before = "old"
  )
  calls <- list()
  audit_local_bindings(
    .st_committed_parents_latest = function(...) list(),
    .st_sidecar_parents = function(...) {
      list(list(path = "parent", version_id = "old"))
    },
    st_latest = function(...) "fresh",
    st_save = function(...) {
      calls[[length(calls) + 1L]] <<- list(...)
      list(version_id = "new")
    }
  )
  out <- st_rebuild(plan, function(path, parents) {
    list(
      x = 42L,
      format = "rds",
      metadata = list(tag = 1L),
      code = "42L",
      code_label = "audit"
    )
  })
  expect_equal(out$status, c("built", "built"))
  expect_equal(
    calls[[1]]$parents,
    list(list(path = stamp:::.st_norm_path("parent"), version_id = "fresh"))
  )
  expect_equal(calls[[2]]$parents, list())
  expect_equal(
    calls[[1]][c("x", "format", "metadata", "code", "code_label")],
    list(
      x = 42L,
      format = "rds",
      metadata = list(tag = 1L),
      code = "42L",
      code_label = "audit"
    )
  )
  audit_local_bindings(st_save = function(...) list(version_id = NULL))
  expect_warning(
    failed <- st_rebuild(plan[1, ], function(...) list(x = 1L)),
    "st_save\\(\\) failed"
  )
  expect_equal(failed$status, "failed")
})

test_that("unequal-depth DAG rebuilds exact outputs after all scheduled parents", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  p <- setNames(file.path(root, paste0(letters[1:5], ".rds")), LETTERS[1:5])
  graph <- list(A = character(), B = "A", C = "A", E = "C", D = c("B", "E"))
  for (node in names(graph)) {
    pars <- lapply(unname(p[graph[[node]]]), function(path) {
      list(path = path, version_id = st_latest(path))
    })
    st_save(0L, p[[node]], parents = pars)
  }
  st_save(10L, p[["A"]])
  builder <- function(path, parents) {
    values <- vapply(
      parents,
      function(parent) {
        st_load(parent$path, verbose = FALSE)
      },
      integer(1)
    )
    node <- names(p)[match(stamp:::.st_normalize_path(path), p)]
    list(
      x = as.integer(
        sum(values) +
          if (node == "C") {
            2L
          } else if (node == "D") {
            0L
          } else {
            1L
          }
      )
    )
  }
  plan <- st_plan_rebuild(p[["A"]])
  out <- st_rebuild(plan, builder)
  expect_equal(out$status, rep("built", 4))
  actual <- vapply(
    p[c("B", "C", "E", "D")],
    st_load,
    integer(1),
    verbose = FALSE
  )
  expect_equal(unname(actual), c(11L, 12L, 13L, 24L))
  expect_equal(plan$level[match(p[["D"]], plan$path)], 3L)
})

test_that("registered builders rebuild exact chained values and latest parents", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  st_clear_builders()
  a <- file.path(root, "a.rds")
  b <- file.path(root, "b.rds")
  c <- file.path(root, "c.rds")
  st_save(1L, a)
  st_save(2L, b, parents = list(list(path = a, version_id = st_latest(a))))
  st_save(3L, c, parents = list(list(path = b, version_id = st_latest(b))))
  before <- stamp:::.st_catalog_read()
  expect_equal(stamp:::.children_of(a), stamp:::.st_normalize_path(b))
  expect_equal(
    stamp:::.st_committed_parents_latest(b)[[1]]$version_id,
    st_latest(a)
  )
  expect_equal(stamp:::.st_sidecar_parents(b)[[1]]$version_id, st_latest(a))
  st_register_builder(b, function(path, parents) {
    expect_equal(parents[[1]]$version_id, st_latest(a))
    list(
      x = st_load(a, verbose = FALSE) + 1L,
      format = "rds",
      metadata = list(audit = TRUE),
      code = "a + 1",
      code_label = "audit-b"
    )
  })
  st_register_builder(c, function(path, parents) {
    expect_equal(parents[[1]]$version_id, st_latest(b))
    list(x = st_load(b, verbose = FALSE) + 1L)
  })
  plan <- st_plan_rebuild(a)
  dry <- st_rebuild(plan, dry_run = TRUE)
  expect_equal(dry$status, c("dry_run", "dry_run"))
  expect_true(all(is.na(dry$version_id)))
  expect_equal(stamp:::.st_catalog_read(), before)
  st_save(10L, a)
  out <- st_rebuild(plan[nrow(plan):1L, ])
  expect_equal(out$path, stamp:::.st_normalize_path(c(b, c)))
  expect_equal(out$status, c("built", "built"))
  expect_equal(out$version_id, c(st_latest(b), st_latest(c)))
  expect_identical(st_load(b, verbose = FALSE), 11L)
  expect_identical(st_load(c, verbose = FALSE), 12L)
  expect_equal(
    stamp:::.st_committed_parents_latest(c)[[1]]$version_id,
    st_latest(b)
  )
  expect_equal(st_read_sidecar(b)$code_label, "audit-b")
  # An unchanged save returns a validated retained pin, not a failed rebuild.
  # The actual builder may run without creating another catalog version.
  unchanged <- stamp:::.st_catalog_read()
  expect_warning(repeated <- st_rebuild(plan[1, ]), NA)
  expect_identical(repeated$status, "built")
  expect_identical(repeated$version_id, st_latest(b))
  expect_equal(stamp:::.st_catalog_read(), unchanged)
  empty <- st_rebuild(plan[FALSE, ])
  expect_equal(nrow(empty), 0L)
  expect_named(empty, c(names(plan), "status", "version_id", "msg"))
})

test_that("legacy rebuild failures block dependent publication but not independent work", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  for (failure in c("missing", "error", "invalid", "save")) {
    root <- stamp:::.st_normalize_path(withr::local_tempdir())
    st_init(root)
    st_clear_builders()
    paths <- setNames(
      file.path(root, paste0(letters[1:5], ".rds")),
      LETTERS[1:5]
    )
    graph <- list(A = character(), B = "A", C = c("A", "B"), D = "C", E = "A")
    initial <- c(A = 1L, B = 2L, C = 3L, D = 4L, E = 11L)
    for (node in names(graph)) {
      parents <- lapply(unname(paths[graph[[node]]]), function(path) {
        list(path = path, version_id = st_latest(path))
      })
      st_save(initial[[node]], paths[[node]], parents = parents)
    }
    protected <- paths[c("B", "C", "D")]
    before <- vapply(protected, st_latest, character(1))
    calls <- character()
    if (failure != "missing") {
      st_register_builder(paths[["B"]], function(path, parents) {
        calls <<- c(calls, basename(path))
        switch(
          failure,
          error = stop("intentional builder failure"),
          invalid = list(other = 20L),
          save = list(x = 20L, format = "not-a-format")
        )
      })
    }
    downstream <- function(path, parents) {
      calls <<- c(calls, basename(path))
      values <- vapply(
        parents,
        function(parent) {
          st_load_version(parent$path, parent$version_id, verbose = FALSE)
        },
        integer(1)
      )
      extra <- if (basename(path) == "e.rds") {
        10L
      } else if (basename(path) == "d.rds") {
        1L
      } else {
        0L
      }
      list(x = as.integer(sum(values) + extra))
    }
    for (node in c("C", "D", "E")) {
      st_register_builder(paths[[node]], downstream)
    }
    st_save(10L, paths[["A"]])
    out <- suppressWarnings(st_rebuild(st_plan_rebuild(paths[["A"]])))
    selected <- out[match(paths[c("B", "C", "D", "E")], out$path), ]
    expect_identical(
      selected$status,
      c("failed", "blocked", "blocked", "built")
    )
    expect_identical(selected$msg[2:3], rep("failed_parent", 2L))
    expect_identical(selected$version_id[1:3], rep(NA_character_, 3L))
    expect_identical(
      calls,
      if (failure == "missing") "e.rds" else c("b.rds", "e.rds")
    )
    expect_identical(vapply(protected, st_latest, character(1)), before)
    expect_identical(
      unname(vapply(protected, st_load, integer(1), verbose = FALSE)),
      c(2L, 3L, 4L)
    )
    expect_identical(
      unname(vapply(
        protected,
        function(path) nrow(st_versions(path)),
        integer(1)
      )),
      rep(1L, 3L)
    )
    expect_identical(st_load(paths[["E"]], verbose = FALSE), 20L)
    expect_identical(selected$version_id[[4]], st_latest(paths[["E"]]))
  }
})

test_that("relative included targets block descendants using alias-root identity", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- normalizePath(withr::local_tempdir(), winslash = "/", mustWork = TRUE)
  outside <- withr::local_tempdir()
  withr::local_dir(outside)
  st_init(root)
  st_clear_builders()
  paths <- setNames(file.path(root, paste0(letters[1:4], ".rds")), LETTERS[1:4])
  graph <- list(A = character(), B = "A", C = c("A", "B"), D = "C")
  for (node in names(graph)) {
    parents <- lapply(unname(paths[graph[[node]]]), function(path) {
      list(path = path, version_id = st_latest(path))
    })
    st_save(match(node, names(graph)), paths[[node]], parents = parents)
  }
  protected <- paths[c("B", "C", "D")]
  before <- vapply(protected, st_latest, character(1))
  calls <- character()
  st_register_builder(paths[["B"]], function(path, parents) {
    calls <<- c(calls, basename(path))
    stop("included parent failed")
  })
  for (node in c("C", "D")) {
    st_register_builder(paths[[node]], function(path, parents) {
      calls <<- c(calls, basename(path))
      values <- vapply(
        parents,
        function(parent) {
          st_load_version(parent$path, parent$version_id, verbose = FALSE)
        },
        integer(1)
      )
      list(x = as.integer(sum(values)))
    })
  }
  st_save(10L, paths[["A"]])
  plan <- st_plan_rebuild("b.rds", include_targets = TRUE)
  expect_identical(plan$path[[1]], "b.rds")
  out <- suppressWarnings(st_rebuild(plan))
  expect_identical(out$status, c("failed", "blocked", "blocked"))
  expect_identical(out$msg[2:3], rep("failed_parent", 2L))
  expect_identical(out$version_id, rep(NA_character_, 3L))
  expect_identical(calls, "b.rds")
  expect_identical(vapply(protected, st_latest, character(1)), before)
  expect_identical(
    unname(vapply(protected, st_load, integer(1), verbose = FALSE)),
    c(2L, 3L, 4L)
  )
  expect_identical(
    unname(vapply(
      protected,
      function(path) nrow(st_versions(path)),
      integer(1)
    )),
    rep(1L, 3L)
  )
})

test_that("rebuild failures report exact causes without changing default policy", {
  local_stamp_state()
  local_st_opts(default_format = "rds", meta_format = "json")
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  st_clear_builders()
  p <- stamp:::.st_norm_path(file.path(root, "new.rds"))
  plan <- data.frame(
    level = 1L,
    path = p,
    reason = "test",
    latest_version_before = NA_character_
  )
  expect_warning(missing <- st_rebuild(plan), "No builder registered")
  expect_equal(missing$status, "failed")
  expect_true(is.na(missing$version_id))
  expect_warning(
    bad <- st_rebuild(plan, function(...) list(y = 1)),
    "builder must return"
  )
  expect_equal(bad$status, "failed")
  expect_warning(
    thrown <- st_rebuild(plan, function(...) stop("builder fault")),
    "builder fault"
  )
  expect_equal(thrown$msg, "builder fault")
  audit_local_bindings(st_save = function(...) stop("save fault"))
  expect_warning(
    save <- st_rebuild(plan, function(...) list(x = 1L)),
    "save fault"
  )
  expect_equal(save$status, "failed")
  expect_equal(save$msg, "save fault")
})

test_that("builder lookup survives alias changes and filesystem path spelling", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- withr::local_tempdir()
  other <- withr::local_tempdir()
  st_init(root, alias = "builder-audit")
  p <- file.path(root, "Artifact.rds")
  st_register_builder(p, function(path, parents) list(x = 42L))
  st_init(other, alias = "other-audit")
  plan <- data.frame(
    level = 1L,
    path = stamp:::.st_normalize_path(p),
    reason = "audit",
    latest_version_before = NA_character_
  )
  out <- st_rebuild(plan)
  expect_equal(out$status, "built")
  expect_identical(st_load(p, alias = "builder-audit", verbose = FALSE), 42L)
  expect_true(st_clear_builders(stamp:::.st_normalize_path(p)))
  expect_false(any(
    stamp:::.st_normalize_path(st_builders()$path) ==
      stamp:::.st_normalize_path(p)
  ))
})

test_that("retention normalization rejects invalid counts and day vectors", {
  local_stamp_state()
  local_st_opts()
  normalize <- stamp:::.st_normalize_policy
  expect_identical(normalize(Inf), list(kind = "all"))
  expect_identical(normalize("2"), list(kind = "n", n = 2L))
  expect_identical(normalize("Inf"), list(kind = "all"))
  expect_identical(normalize("2 7"), list(kind = "combo", n = 2L, days = 7))
  expect_identical(
    normalize("  2  7\t "),
    list(kind = "combo", n = 2L, days = 7)
  )
  expect_identical(
    normalize(list(days = 0.5)),
    list(kind = "combo", n = NULL, days = 0.5)
  )
  expect_identical(
    normalize(list(days = Inf)),
    list(kind = "combo", n = NULL, days = Inf)
  )
  for (bad in list(
    -1,
    NA_real_,
    NaN,
    -Inf,
    1.5,
    .Machine$integer.max + 1,
    "1.5",
    "bad 2",
    "1 2 3",
    "",
    NA_character_,
    c(1, 2),
    NULL,
    TRUE,
    list(),
    list(n = c(1, 2)),
    list(n = NA),
    list(n = Inf),
    list(n = 0.5),
    list(days = c(1, 2)),
    list(days = NA),
    list(days = -1),
    list(n = "bad"),
    list(days = "bad")
  )) {
    expect_error(normalize(bad))
  }
})

test_that("retention count and age policies union with an inclusive UTC cutoff", {
  local_stamp_state()
  local_st_opts()
  now <- as.POSIXct(
    "2026-10-15T12:00:00Z",
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  )
  # Inject the clock in a local copy, without changing base Sys.time globally.
  keep <- stamp:::.st_policy_keep_ids
  environment(keep) <- list2env(
    list(Sys.time = function() now),
    parent = environment(keep)
  )
  tab <- data.frame(
    version_id = c("latest", "boundary", "old", "invalid"),
    created_at = c(
      "2026-10-15T12:00:00Z",
      "2026-10-14T12:00:00Z",
      "2026-10-14T11:59:59Z",
      "bad"
    )
  )
  expect_equal(keep(tab, list(kind = "n", n = 0L)), character())
  expect_equal(keep(tab[FALSE, ], list(kind = "n", n = 5L)), character())
  expect_equal(keep(tab, list(kind = "n", n = 2L)), c("latest", "boundary"))
  expect_equal(
    keep(tab, list(kind = "combo", n = NULL, days = 1)),
    c("latest", "boundary")
  )
  expect_equal(
    keep(tab, list(kind = "combo", n = 3L, days = 1)),
    c("latest", "boundary", "old")
  )
  parsed <- stamp:::.st_parse_utc_times(tab$created_at)
  expect_equal(as.numeric(parsed[1:3]) - as.numeric(now), c(0, -86400, -86401))
  expect_true(is.na(parsed[4]))
  fractional <- stamp:::.st_parse_utc_times("2026-10-15T12:00:00.125000Z")
  expect_equal(as.numeric(fractional) - as.numeric(now), 0.125)
})

test_that("scoped prune preserves unrelated records, lineage, snapshots and live data", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  a <- file.path(root, "a.rds")
  b <- file.path(root, "b.rds")
  st_save(0L, b)
  for (i in 1:3) {
    st_save(i, a, parents = list(list(path = b, version_id = st_latest(b))))
  }
  for (i in 4:5) {
    st_save(i, b, parents = list(list(path = a, version_id = st_latest(a))))
  }
  before <- stamp:::.st_catalog_read()
  expect_error(st_prune_versions(a, 1, dry_run = NA))
  bid <- before$artifacts$artifact_id[
    before$artifacts$path == stamp:::.st_normalize_path(b)
  ]
  b_versions <- before$versions[artifact_id == bid]
  b_files <- fs::dir_ls(file.path(root, "b.rds"), recurse = TRUE, type = "file")
  hashes <- tools::md5sum(b_files)
  latest <- st_latest(a)
  dry <- st_prune_versions(a, 1, dry_run = TRUE)
  expect_setequal(dry$version_id, setdiff(st_versions(a)$version_id, latest))
  expect_equal(stamp:::.st_catalog_read(), before)
  expect_identical(tools::md5sum(b_files), hashes)
  removed <- st_prune_versions(a, 1, dry_run = FALSE)
  expect_setequal(removed$version_id, dry$version_id)
  after <- stamp:::.st_catalog_read()
  expect_equal(
    after$artifacts[artifact_id == bid],
    before$artifacts[artifact_id == bid]
  )
  expect_equal(after$versions[artifact_id == bid], b_versions)
  expect_equal(
    after$parents_index[child_artifact_id == bid],
    before$parents_index[child_artifact_id == bid]
  )
  expect_false(any(
    after$parents_index$child_version_id %in% removed$version_id
  ))
  expect_identical(tools::md5sum(b_files), hashes)
  expect_identical(st_load(a, verbose = FALSE), 3L)
  expect_identical(st_load(b, verbose = FALSE), 5L)
  expect_equal(st_versions(a)$version_id, latest)
  expect_equal(nrow(st_versions(b)), 3L)
  # Automatic post-save retention must preserve B by the same invariant.
  st_opts(retain_versions = 1)
  st_save(9L, a)
  expect_equal(nrow(st_versions(a)), 1L)
  expect_equal(
    stamp:::.st_catalog_read()$versions[artifact_id == bid],
    b_versions
  )
  expect_identical(tools::md5sum(b_files), hashes)
  expect_identical(st_load(a, verbose = FALSE), 9L)
  expect_identical(st_load(b, verbose = FALSE), 5L)
})

test_that("multiple scoped paths prune only the selected alias catalog", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- withr::local_tempdir()
  other <- withr::local_tempdir()
  st_init(root, alias = "selected")
  paths <- file.path(root, c("a.rds", "b.rds"))
  for (p in paths) {
    for (i in 1:2) {
      st_save(i, p, alias = "selected")
    }
  }
  st_init(other, alias = "untouched")
  q <- file.path(other, "c.rds")
  for (i in 1:2) {
    st_save(i, q, alias = "untouched")
  }
  before <- stamp:::.st_catalog_read("untouched")
  result <- st_prune_versions(paths, 1, dry_run = FALSE, alias = "selected")
  expect_equal(nrow(result), 2L)
  expect_setequal(result$artifact_path, stamp:::.st_normalize_path(paths))
  expect_equal(
    vapply(
      paths,
      function(p) nrow(st_versions(p, alias = "selected")),
      integer(1),
      USE.NAMES = FALSE
    ),
    c(1L, 1L)
  )
  expect_equal(stamp:::.st_catalog_read("untouched"), before)
  expect_identical(st_load(q, alias = "untouched", verbose = FALSE), 2L)
})

test_that("partial snapshot deletion changes only successfully deleted catalog entries", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  p <- file.path(root, "a.rds")
  for (i in 1:3) {
    st_save(i, p)
  }
  candidates <- st_prune_versions(p, 1)
  failed <- candidates$version_id[1]
  deleted <- candidates$version_id[2]
  original_delete <- stamp:::.st_delete_version_dir_safe
  audit_local_bindings(.st_delete_version_dir_safe = function(vdir) {
    if (basename(vdir) == failed) {
      stop("injected deletion fault")
    }
    original_delete(vdir)
  })
  expect_warning(st_prune_versions(p, 1, dry_run = FALSE), "Failed to delete")
  expect_true(failed %in% st_versions(p)$version_id)
  expect_false(deleted %in% st_versions(p)$version_id)
  expect_true(fs::dir_exists(stamp:::.st_version_dir("a.rds", failed)))
  expect_false(fs::dir_exists(stamp:::.st_version_dir("a.rds", deleted)))
  expect_identical(st_load(p, verbose = FALSE), 3L)
})

test_that("pruning honors timestamp ties and minimum preservation", {
  local_stamp_state()
  local_st_opts(
    default_format = "rds",
    meta_format = "json",
    versioning = "content",
    retain_versions = Inf
  )
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  st_init(root)
  p <- file.path(root, "a.rds")
  for (i in 1:3) {
    st_save(i, p)
  }
  cat <- stamp:::.st_catalog_read()
  cat$versions$created_at <- rep("2020-01-01T00:00:00Z", 3)
  data.table::setorder(cat$versions, version_id)
  stamp:::.st_catalog_write(cat)
  expected <- sort(cat$versions$version_id, decreasing = TRUE)[1]
  expect_setequal(
    st_prune_versions(p, list(n = 0, days = 0))$version_id,
    setdiff(cat$versions$version_id, expected)
  )
  st_prune_versions(p, 2, dry_run = FALSE)
  expect_equal(stamp:::.st_catalog_read()$artifacts$latest_version_id, expected)
  expect_setequal(
    st_versions(p)$version_id,
    sort(cat$versions$version_id, decreasing = TRUE)[1:2]
  )
  st_prune_versions(p, 0, dry_run = FALSE)
  expect_equal(st_versions(p)$version_id, expected)
  expect_equal(stamp:::.st_catalog_read()$artifacts$latest_version_id, expected)
  expect_identical(st_load(p, verbose = FALSE), 3L)
  expect_equal(nrow(st_prune_versions(p, Inf)), 0L)
  expect_equal(nrow(st_prune_versions(file.path(root, "missing.rds"), 1)), 0L)
})

test_that("pruning rejects malformed catalogs and handles an empty store", {
  local_stamp_state()
  local_st_opts()
  root <- withr::local_tempdir()
  st_init(root)
  expect_identical(st_prune_versions(policy = 1), data.frame())
  cat <- stamp:::.st_catalog_empty()
  audit_local_bindings(.st_catalog_read = function(...) cat)
  cat$artifacts$path <- NULL
  expect_error(st_prune_versions(policy = 1), "artifacts table missing")
  cat <- stamp:::.st_catalog_empty()
  cat$versions$created_at <- NULL
  expect_error(st_prune_versions(policy = 1), "versions table missing")
})

test_that("safe version deletion warns on missing directories and removes existing ones", {
  local_stamp_state()
  local_st_opts()
  root <- stamp:::.st_normalize_path(withr::local_tempdir())
  p <- file.path(root, "version")
  fs::dir_create(p)
  stamp:::.st_delete_version_dir_safe(p)
  expect_false(fs::dir_exists(p))
  expect_warning(stamp:::.st_delete_version_dir_safe(p), "Version dir missing")
})
