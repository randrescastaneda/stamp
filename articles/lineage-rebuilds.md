# Lineage and Rebuilds

``` r
# Use development build when interactive *and* explicitly enabled via env var.
dev_mode <- (Sys.getenv("DEV_VIGNETTES", "false") == "true")

if (dev_mode && requireNamespace("pkgload", quietly = TRUE)) {
  cli::cli_inform("loading with {.pkg pkgload}")
  pkgload::load_all()
} else {
  # fall back to the installed package (the path CRAN, CI, and pkgdown take)
  cli::cli_inform("loading with {.pkg library}")
  library(stamp)
}
```

    ## loading with library

This vignette shows how **stamp** captures **lineage** (parents →
children), how to detect **staleness**, and how to **plan & rebuild**
downstream artifacts in level order.

You’ll use:

- Lineage:
  [`st_children()`](https://randrescastaneda.github.io/stamp/reference/st_children.md),
  [`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md)
- Staleness:
  [`st_is_stale()`](https://randrescastaneda.github.io/stamp/reference/st_is_stale.md)
- Planning:
  [`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
  (returns a plan data.frame)
- Rebuilding:
  [`st_register_builder()`](https://randrescastaneda.github.io/stamp/reference/st_register_builder.md),
  [`st_clear_builders()`](https://randrescastaneda.github.io/stamp/reference/st_clear_builders.md),
  [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)

> **Strict vs. Propagate** *Strict* checks actual mismatch vs the
> parents’ **current** latest versions. *Propagate* simulates change
> pushing downstream (A changes ⇒ schedule B ⇒ schedule C, etc.).

A few implementation notes that clarify behavior used by the examples
below:

- Committed parents (the `parents.json` file inside a version snapshot)
  are the authoritative record for lineage when present. They are
  captured at commit time and are used for reproducible, recursive
  lineage walking.
- Sidecar parents (the `parents` field in the sidecar metadata written
  next to the artifact file) are a lightweight convenience that let you
  inspect first-level lineage before a snapshot is committed.
  [`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md)
  falls back to sidecar parents only for the immediate parent level when
  no snapshot is available; recursive walking beyond level 1 requires
  snapshot-backed parents.

This design keeps interactive workflows fast (sidecars are quick) while
preserving reproducible history once snapshots are written.

## Setup a tiny graph A → B(A) → C(B)

``` r
st_opts_reset()
st_opts(
  versioning = "content",
  code_hash = TRUE,
  store_file_hash = TRUE,
  verify_on_load = TRUE,
  meta_format = "both"
)
```

    ## ✔ stamp options updated
    ##   versioning = "content", code_hash = "TRUE", store_file_hash = "TRUE",
    ##   verify_on_load = "TRUE", meta_format = "both"

``` r
root <- tempdir()
st_init(root)
```

    ## ✔ stamp initialized
    ##   root: /tmp/RtmpZpEwUd
    ##   state: /tmp/RtmpZpEwUd/.stamp

``` r
# A
pA <- fs::path(root, "A.qs")
xA <- data.frame(a = 1:3)
st_save(xA, pA, code = function(z) z)
```

    ## ✔ Saved [qs2] → /tmp/RtmpZpEwUd/A.qs @ version
    ## 8e5d89ec98834bc6

``` r
# B depends on A
pB <- fs::path(root, "B.qs")
xB <- transform(xA, b = a * 2)
st_save(
  xB,
  pB,
  code = function(z) z,
  parents = list(list(path = pA, version_id = st_latest(pA)))
)
```

    ## ✔ Saved [qs2] → /tmp/RtmpZpEwUd/B.qs @ version
    ## 56d7811703b4bcac

``` r
# C depends on B
pC <- fs::path(root, "C.qs")
xC <- transform(xB, c = b + 1L)
st_save(
  xC,
  pC,
  code = function(z) z,
  parents = list(list(path = pB, version_id = st_latest(pB)))
)
```

    ## ✔ Saved [qs2] → /tmp/RtmpZpEwUd/C.qs @ version
    ## 0a16926167850d2a

Note: after these saves each artifact has a sidecar (in `stmeta/`) and
snapshots under `.stamp/versions/`.

Committed parents vs sidecar example

This short interactive example shows the difference between committed
parents (stored inside the version snapshot) and the light-weight
sidecar parents next to the artifact file. We deliberately remove the
committed snapshot for `B` to simulate a case where only the sidecar
remains;
[`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md)
will still return immediate parents (level 1) by reading the sidecar,
but recursive walking beyond level 1 only uses snapshot-backed parents.

``` r
# Remove committed snapshot for B to simulate a no-snapshot state
vdir_b <- stamp:::.st_version_dir(pB, st_latest(pB))
if (fs::dir_exists(vdir_b)) {
  fs::dir_delete(vdir_b)
}

# Now st_info will show snapshot_dir = NA but sidecar present
st_info(pB)
```

    ## $sidecar
    ## $sidecar$path
    ## [1] "/tmp/RtmpZpEwUd/B.qs"
    ## 
    ## $sidecar$format
    ## [1] "qs2"
    ## 
    ## $sidecar$created_at
    ## [1] "2025-11-10T22:05:04Z"
    ## 
    ## $sidecar$size_bytes
    ## [1] 216
    ## 
    ## $sidecar$content_hash
    ## [1] "57992c880141b360"
    ## 
    ## $sidecar$code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $sidecar$file_hash
    ## [1] "3de32a31f5476755"
    ## 
    ## $sidecar$code_label
    ## NULL
    ## 
    ## $sidecar$parents
    ##                   path       version_id
    ## 1 /tmp/RtmpZpEwUd/A.qs 8e5d89ec98834bc6
    ## 
    ## $sidecar$attrs
    ## list()
    ## 
    ## 
    ## $catalog
    ## $catalog$latest_version_id
    ## [1] NA
    ## 
    ## $catalog$n_versions
    ## [1] 1
    ## 
    ## 
    ## $snapshot_dir
    ## [1] NA
    ## 
    ## $parents
    ##                   path       version_id
    ## 1 /tmp/RtmpZpEwUd/A.qs 8e5d89ec98834bc6

``` r
# st_lineage will fall back to the sidecar for immediate parents (level 1)
st_lineage(pB, depth = 1)
```

    ## [1] level          child_path     child_version  parent_path    parent_version
    ## <0 rows> (or 0-length row.names)

``` r
# But recursive lineage (depth > 1) will only follow snapshot-backed parents
# (no recursive walk available once snapshots are missing)
st_lineage(pB, depth = 2)
```

    ## [1] level          child_path     child_version  parent_path    parent_version
    ## <0 rows> (or 0-length row.names)

## Inspect lineage

``` r
# Immediate children of A (depth 1)
st_children(pA, depth = 1)
```

    ##             child_path    child_version          parent_path   parent_version
    ## 1 /tmp/RtmpZpEwUd/B.qs 56d7811703b4bcac /tmp/RtmpZpEwUd/A.qs 8e5d89ec98834bc6
    ##   level
    ## 1     1

``` r
# Full lineage (parents of an artifact)
st_lineage(pC, depth = Inf)
```

    ## [1] level          child_path     child_version  parent_path    parent_version
    ## <0 rows> (or 0-length row.names)

## Make a change upstream & detect staleness

``` r
# Change A → new version
xA2 <- transform(xA, a = a + 10L)
st_save(xA2, pA, code = function(z) z)
```

    ## ✔ Saved [qs2] → /tmp/RtmpZpEwUd/A.qs @ version
    ## d480b72653fee0ea

``` r
# Strict staleness
st_is_stale(pB) # TRUE (B's recorded A version is now old)
```

    ## [1] FALSE

``` r
st_is_stale(pC) # FALSE (C points to B, which hasn't changed yet)
```

    ## [1] FALSE

## Plan rebuilds

Two strategies:

- **strict**: only items whose *recorded* parent IDs differ from
  parents’ *current latest*.
- **propagate**: assume targets will change and plan descendants in BFS
  layers.

``` r
# Strict: only B right now
plan_strict <- st_plan_rebuild(pA, depth = Inf, mode = "strict")
plan_strict
```

    ## [1] level                 path                  reason               
    ## [4] latest_version_before
    ## <0 rows> (or 0-length row.names)

``` r
# Propagate: includes B (level 1) and C (level 2)
plan <- st_plan_rebuild(pA, depth = Inf, mode = "propagate")
plan
```

    ##   level                 path           reason latest_version_before
    ## 1     1 /tmp/RtmpZpEwUd/B.qs upstream_changed                  <NA>

## Register builders and rebuild in level order

Builders are tiny functions that **produce** an artifact from its
parents. They receive `(path, parents)` and return a list with at least
`x = <object>`.

``` r
# Clear any previous registry
st_clear_builders()
```

    ## ✔ Cleared all registered builders

``` r
# Register a builder for B: rebuild from A's committed version
st_register_builder(pB, function(path, parents) {
  # parents is list(list(path=..., version_id=...))
  A <- st_load_version(parents[[1]]$path, parents[[1]]$version_id)
  list(
    x = transform(A, b = a * 2),
    code = function(z) z,
    code_label = "B <- A * 2"
  )
})
```

    ## ✔ Registered builder for /tmp/RtmpZpEwUd/B.qs
    ## (default)

``` r
# Register a builder for C: rebuild from B's committed version
st_register_builder(pC, function(path, parents) {
  B <- st_load_version(parents[[1]]$path, parents[[1]]$version_id)
  list(
    x = transform(B, c = b + 1L),
    code = function(z) z,
    code_label = "C <- B + 1"
  )
})
```

    ## ✔ Registered builder for /tmp/RtmpZpEwUd/C.qs
    ## (default)

``` r
# Dry run first (uses registered builders found by st_rebuild when rebuild_fun is NULL)
st_rebuild(plan, dry_run = TRUE)
```

    ## ✔ Rebuild level 1: 1 artifact
    ##   • /tmp/RtmpZpEwUd/B.qs (upstream_changed)
    ##   DRY RUN
    ## ✔ Rebuild summary
    ##   dry_run 1

``` r
# Now actually rebuild (will use registered builders)
res <- st_rebuild(plan, dry_run = FALSE)
```

    ## ✔ Rebuild level 1: 1 artifact
    ##   • /tmp/RtmpZpEwUd/B.qs (upstream_changed)
    ## ✔ Loaded ← /tmp/RtmpZpEwUd/A.qs @ d480b72653fee0ea [qs2]
    ## ✔ Saved [qs2] → /tmp/RtmpZpEwUd/B.qs @ version 855233f69ea30ded
    ## OK @ version 855233f69ea30ded
    ## ✔ Rebuild summary
    ##   built 1

``` r
res
```

    ##   level                 path           reason status       version_id msg
    ## 1     1 /tmp/RtmpZpEwUd/B.qs upstream_changed  built 855233f69ea30ded

After rebuilding B, **C** becomes strictly stale if **B** changes again
later. You can re-plan from B to keep propagating:

``` r
st_is_stale(pB)
```

    ## [1] FALSE

``` r
st_is_stale(pC)
```

    ## [1] FALSE

``` r
st_plan_rebuild(pB, depth = Inf, mode = "propagate")
```

    ##   level                 path           reason latest_version_before
    ## 1     1 /tmp/RtmpZpEwUd/C.qs upstream_changed                  <NA>

## Inspect snapshots on disk

``` r
vroot <- stamp:::.st_versions_root()
fs::dir_tree(vroot, recurse = TRUE, all = TRUE)
```

    ## /tmp/RtmpZpEwUd/.stamp/versions
    ## ├── A.qs
    ## │   ├── 8e5d89ec98834bc6
    ## │   │   ├── artifact
    ## │   │   ├── sidecar.json
    ## │   │   └── sidecar.qs2
    ## │   └── d480b72653fee0ea
    ## │       ├── artifact
    ## │       ├── sidecar.json
    ## │       └── sidecar.qs2
    ## ├── B.qs
    ## │   ├── 56d7811703b4bcac
    ## │   │   ├── artifact
    ## │   │   ├── parents.json
    ## │   │   ├── sidecar.json
    ## │   │   └── sidecar.qs2
    ## │   └── 855233f69ea30ded
    ## │       ├── artifact
    ## │       ├── parents.json
    ## │       ├── sidecar.json
    ## │       └── sidecar.qs2
    ## └── C.qs
    ##     └── 0a16926167850d2a
    ##         ├── artifact
    ##         ├── parents.json
    ##         ├── sidecar.json
    ##         └── sidecar.qs2

**Tip:** `st_info(path)` summarizes sidecar, catalog status, and the
latest snapshot dir, plus parsed `parents.json` from the committed
snapshot (if present).

``` r
st_info(pC)
```

    ## $sidecar
    ## $sidecar$path
    ## [1] "/tmp/RtmpZpEwUd/C.qs"
    ## 
    ## $sidecar$format
    ## [1] "qs2"
    ## 
    ## $sidecar$created_at
    ## [1] "2025-11-10T22:05:04Z"
    ## 
    ## $sidecar$size_bytes
    ## [1] 229
    ## 
    ## $sidecar$content_hash
    ## [1] "502fb8918e46e3de"
    ## 
    ## $sidecar$code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $sidecar$file_hash
    ## [1] "385e81fdcbfab7ed"
    ## 
    ## $sidecar$code_label
    ## NULL
    ## 
    ## $sidecar$parents
    ##                   path       version_id
    ## 1 /tmp/RtmpZpEwUd/B.qs 8e5d89ec98834bc6
    ## 
    ## $sidecar$attrs
    ## list()
    ## 
    ## 
    ## $catalog
    ## $catalog$latest_version_id
    ## [1] NA
    ## 
    ## $catalog$n_versions
    ## [1] 1
    ## 
    ## 
    ## $snapshot_dir
    ## [1] NA
    ## 
    ## $parents
    ##                   path       version_id
    ## 1 /tmp/RtmpZpEwUd/B.qs 8e5d89ec98834bc6

### Takeaways

- Use **strict** staleness to detect objective mismatches.
- Use **propagate** planning to build a full downstream schedule.
- Keep builders small, pure, and deterministic; they make rebuilds
  trivial.
