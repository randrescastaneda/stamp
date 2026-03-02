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
    ##   alias: default
    ##   root: /tmp/RtmpFH84w3
    ##   state: /tmp/RtmpFH84w3/.stamp

``` r
# A
pA <- "A.qs"
xA <- data.frame(a = 1:3)
st_save(xA, pA, code = function(z) z, alias = NULL)
```

    ## ✔ Saved [qs2] → /tmp/RtmpFH84w3/A.qs @ version
    ## 14dddf583a9b0581

``` r
# B depends on A
pB <- "B.qs"
xB <- transform(xA, b = a * 2)
st_save(
  xB,
  pB,
  code = function(z) z,
  parents = list(list(path = pA, version_id = st_latest(pA, alias = NULL))),
  alias = NULL
)
```

    ## ✔ Saved [qs2] → /tmp/RtmpFH84w3/B.qs @ version
    ## 7f0c28920348b40d

``` r
# C depends on B
pC <- "C.qs"
xC <- transform(xB, c = b + 1L)
st_save(
  xC,
  pC,
  code = function(z) z,
  parents = list(list(path = pB, version_id = st_latest(pB, alias = NULL))),
  alias = NULL
)
```

    ## ✔ Saved [qs2] → /tmp/RtmpFH84w3/C.qs @ version
    ## 27e91c523291711c

Note: after these saves each artifact has a sidecar (in `stmeta/` next
to the artifact) and snapshots in its own `versions/` directory
(per-artifact storage, not centralized).

## Inspect lineage

``` r
# Immediate children of A (depth 1)
st_children(pA, depth = 1, alias = NULL)
```

    ##             child_path    child_version
    ## 1 /tmp/RtmpFH84w3/B.qs 7f0c28920348b40d
    ##                                    parent_path   parent_version level
    ## 1 /home/runner/work/stamp/stamp/vignettes/A.qs 14dddf583a9b0581     1

``` r
# Full lineage (parents of an artifact)
st_lineage(pC, depth = Inf, alias = NULL)
```

    ## [1] level          child_path     child_version  parent_path    parent_version
    ## <0 rows> (or 0-length row.names)

## Make a change upstream & detect staleness

``` r
# Change A → new version
xA2 <- transform(xA, a = a + 10L)
st_save(xA2, pA, code = function(z) z, alias = NULL)
```

    ## ✔ Saved [qs2] → /tmp/RtmpFH84w3/A.qs @ version
    ## bbc0d98563d1eb86

``` r
# Strict staleness
st_is_stale(pB) # TRUE (B's recorded A version is now old)
```

    ## [1] TRUE

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

    ##   level                 path         reason latest_version_before
    ## 1     1 /tmp/RtmpFH84w3/B.qs parent_changed      7f0c28920348b40d

``` r
# Propagate: includes B (level 1) and C (level 2)
plan <- st_plan_rebuild(pA, depth = Inf, mode = "propagate")
plan
```

    ##   level                 path           reason latest_version_before
    ## 1     1 /tmp/RtmpFH84w3/B.qs upstream_changed      7f0c28920348b40d

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
  A <- st_load_version(parents[[1]]$path, parents[[1]]$version_id, alias = NULL)
  list(
    x = transform(A, b = a * 2),
    code = function(z) z,
    code_label = "B <- A * 2"
  )
})
```

    ## ✔ Registered builder for B.qs (default)

``` r
# Register a builder for C: rebuild from B's committed version
st_register_builder(pC, function(path, parents) {
  B <- st_load_version(parents[[1]]$path, parents[[1]]$version_id, alias = NULL)
  list(
    x = transform(B, c = b + 1L),
    code = function(z) z,
    code_label = "C <- B + 1"
  )
})
```

    ## ✔ Registered builder for C.qs (default)

``` r
# Dry run first (uses registered builders found by st_rebuild when rebuild_fun is NULL)
st_rebuild(plan, dry_run = TRUE)
```

    ## ✔ Rebuild level 1: 1 artifact
    ##   • /tmp/RtmpFH84w3/B.qs (upstream_changed)
    ##   DRY RUN
    ## ✔ Rebuild summary
    ##   dry_run 1

``` r
# Now actually rebuild (will use registered builders)
res <- st_rebuild(plan, dry_run = FALSE)
```

    ## ✔ Rebuild level 1: 1 artifact
    ##   • /tmp/RtmpFH84w3/B.qs (upstream_changed)

    ## Warning: FAILED: No builder registered for path: /tmp/RtmpFH84w3/B.qs and no rebuild_fun
    ## provided.

    ## ✔ Rebuild summary
    ##   failed 1

``` r
res
```

    ##   level                 path           reason status version_id
    ## 1     1 /tmp/RtmpFH84w3/B.qs upstream_changed failed       <NA>
    ##                                                                                 msg
    ## 1 No builder registered for path: /tmp/RtmpFH84w3/B.qs and no rebuild_fun provided.

After rebuilding B, **C** becomes strictly stale if **B** changes again
later. You can re-plan from B to keep propagating:

``` r
st_is_stale(pB)
```

    ## [1] TRUE

``` r
st_is_stale(pC)
```

    ## [1] FALSE

``` r
st_plan_rebuild(pB, depth = Inf, mode = "propagate")
```

    ##   level                 path           reason latest_version_before
    ## 1     1 /tmp/RtmpFH84w3/C.qs upstream_changed      27e91c523291711c

## Inspect snapshots on disk

``` r
vroot <- fs::path_dir(st_info(pA, alias = NULL)$sidecar$path)
vroot <- fs::path(vroot, "versions")
if (fs::dir_exists(vroot)) {
  fs::dir_tree(vroot, recurse = TRUE, all = TRUE)
}
```

**Tip:** `st_info(path)` summarizes sidecar, catalog status, and the
latest snapshot dir, plus parsed `parents.json` from the committed
snapshot (if present).

``` r
st_info(pC, alias = NULL)
```

    ## $sidecar
    ## $sidecar$path
    ## [1] "/tmp/RtmpFH84w3/C.qs"
    ## 
    ## $sidecar$format
    ## [1] "qs2"
    ## 
    ## $sidecar$created_at
    ## [1] "2026-03-02T21:47:14.965438Z"
    ## 
    ## $sidecar$size_bytes
    ## [1] 266
    ## 
    ## $sidecar$content_hash
    ## [1] "28e3e19ddcccd8c6"
    ## 
    ## $sidecar$code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $sidecar$file_hash
    ## [1] "fefe26c9df86a402"
    ## 
    ## $sidecar$code_label
    ## NULL
    ## 
    ## $sidecar$parents
    ##   path       version_id
    ## 1 B.qs 7f0c28920348b40d
    ## 
    ## $sidecar$attrs
    ## list()
    ## 
    ## 
    ## $catalog
    ## $catalog$latest_version_id
    ## [1] "27e91c523291711c"
    ## 
    ## $catalog$n_versions
    ## [1] 1
    ## 
    ## 
    ## $snapshot_dir
    ## /tmp/RtmpFH84w3/C.qs/versions/27e91c523291711c
    ## 
    ## $parents
    ## $parents[[1]]
    ## $parents[[1]]$path
    ## [1] "B.qs"
    ## 
    ## $parents[[1]]$version_id
    ## [1] "7f0c28920348b40d"

### Takeaways

- Use **strict** staleness to detect objective mismatches.
- Use **propagate** planning to build a full downstream schedule.
- Keep builders small, pure, and deterministic; they make rebuilds
  trivial.
