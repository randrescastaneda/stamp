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
    ##   root: /tmp/RtmpvmY1Tt
    ##   state: /tmp/RtmpvmY1Tt/.stamp

``` r
# A
pA <- fs::path(root, "A.qs")
xA <- data.frame(a = 1:3)
st_save(xA, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/RtmpvmY1Tt/A.qs @ version
    ## 01633c3be58d0b83

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

    ## ✔ Saved [qs] → /tmp/RtmpvmY1Tt/B.qs @ version
    ## 11cc462e2afeda05

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

    ## ✔ Saved [qs] → /tmp/RtmpvmY1Tt/C.qs @ version
    ## 3c08595c1ed36ba4

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
    ## [1] "/tmp/RtmpvmY1Tt/B.qs"
    ## 
    ## $sidecar$format
    ## [1] "qs"
    ## 
    ## $sidecar$created_at
    ## [1] "2026-01-15T22:48:31.475074Z"
    ## 
    ## $sidecar$size_bytes
    ## [1] 148
    ## 
    ## $sidecar$content_hash
    ## [1] "bba6fe40c1133df8"
    ## 
    ## $sidecar$code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $sidecar$file_hash
    ## [1] "aedd22253abcd70c"
    ## 
    ## $sidecar$code_label
    ## NULL
    ## 
    ## $sidecar$parents
    ##                   path       version_id
    ## 1 /tmp/RtmpvmY1Tt/A.qs 01633c3be58d0b83
    ## 
    ## $sidecar$attrs
    ## list()
    ## 
    ## 
    ## $catalog
    ## $catalog$latest_version_id
    ## [1] "11cc462e2afeda05"
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
    ## 1 /tmp/RtmpvmY1Tt/A.qs 01633c3be58d0b83

``` r
# st_lineage will fall back to the sidecar for immediate parents (level 1)
st_lineage(pB, depth = 1)
```

    ##   level           child_path    child_version          parent_path
    ## 1     1 /tmp/RtmpvmY1Tt/B.qs 11cc462e2afeda05 /tmp/RtmpvmY1Tt/A.qs
    ##     parent_version
    ## 1 01633c3be58d0b83

``` r
# But recursive lineage (depth > 1) will only follow snapshot-backed parents
# (no recursive walk available once snapshots are missing)
st_lineage(pB, depth = 2)
```

    ##   level           child_path    child_version          parent_path
    ## 1     1 /tmp/RtmpvmY1Tt/B.qs 11cc462e2afeda05 /tmp/RtmpvmY1Tt/A.qs
    ##     parent_version
    ## 1 01633c3be58d0b83

## Inspect lineage

``` r
# Immediate children of A (depth 1)
st_children(pA, depth = 1)
```

    ## [1] level          child_path     child_version  parent_path    parent_version
    ## <0 rows> (or 0-length row.names)

``` r
# Full lineage (parents of an artifact)
st_lineage(pC, depth = Inf)
```

    ##   level           child_path    child_version          parent_path
    ## 1     1 /tmp/RtmpvmY1Tt/C.qs 3c08595c1ed36ba4 /tmp/RtmpvmY1Tt/B.qs
    ##     parent_version
    ## 1 11cc462e2afeda05

## Make a change upstream & detect staleness

``` r
# Change A → new version
xA2 <- transform(xA, a = a + 10L)
st_save(xA2, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/RtmpvmY1Tt/A.qs @ version
    ## 87f8ad57df65bf88

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

    ## [1] level                 path                  reason               
    ## [4] latest_version_before
    ## <0 rows> (or 0-length row.names)

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

    ## ✔ Registered builder for /tmp/RtmpvmY1Tt/B.qs
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

    ## ✔ Registered builder for /tmp/RtmpvmY1Tt/C.qs
    ## (default)

``` r
# Dry run first (uses registered builders found by st_rebuild when rebuild_fun is NULL)
st_rebuild(plan, dry_run = TRUE)
```

    ## ✔ Nothing to rebuild (empty plan).

``` r
# Now actually rebuild (will use registered builders)
res <- st_rebuild(plan, dry_run = FALSE)
```

    ## ✔ Nothing to rebuild (empty plan).

``` r
res
```

    ## [1] level                 path                  reason               
    ## [4] latest_version_before status                version_id           
    ## [7] msg                  
    ## <0 rows> (or 0-length row.names)

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
    ## 1     1 /tmp/RtmpvmY1Tt/C.qs upstream_changed      3c08595c1ed36ba4

## Inspect snapshots on disk

``` r
vroot <- stamp:::.st_versions_root()
fs::dir_tree(vroot, recurse = TRUE, all = TRUE)
```

    ## /tmp/RtmpvmY1Tt/.stamp/versions
    ## ├── A.qs
    ## │   ├── 01633c3be58d0b83
    ## │   │   ├── artifact
    ## │   │   ├── sidecar.json
    ## │   │   └── sidecar.qs2
    ## │   └── 87f8ad57df65bf88
    ## │       ├── artifact
    ## │       ├── sidecar.json
    ## │       └── sidecar.qs2
    ## ├── B.qs
    ## └── C.qs
    ##     └── 3c08595c1ed36ba4
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
    ## [1] "/tmp/RtmpvmY1Tt/C.qs"
    ## 
    ## $sidecar$format
    ## [1] "qs"
    ## 
    ## $sidecar$created_at
    ## [1] "2026-01-15T22:48:31.531796Z"
    ## 
    ## $sidecar$size_bytes
    ## [1] 159
    ## 
    ## $sidecar$content_hash
    ## [1] "28e3e19ddcccd8c6"
    ## 
    ## $sidecar$code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $sidecar$file_hash
    ## [1] "4286965c99aa6527"
    ## 
    ## $sidecar$code_label
    ## NULL
    ## 
    ## $sidecar$parents
    ##                   path       version_id
    ## 1 /tmp/RtmpvmY1Tt/B.qs 11cc462e2afeda05
    ## 
    ## $sidecar$attrs
    ## list()
    ## 
    ## 
    ## $catalog
    ## $catalog$latest_version_id
    ## [1] "3c08595c1ed36ba4"
    ## 
    ## $catalog$n_versions
    ## [1] 1
    ## 
    ## 
    ## $snapshot_dir
    ## /tmp/RtmpvmY1Tt/.stamp/versions/C.qs/3c08595c1ed36ba4
    ## 
    ## $parents
    ## $parents[[1]]
    ## $parents[[1]]$path
    ## [1] "/tmp/RtmpvmY1Tt/B.qs"
    ## 
    ## $parents[[1]]$version_id
    ## [1] "11cc462e2afeda05"

### Takeaways

- Use **strict** staleness to detect objective mismatches.
- Use **propagate** planning to build a full downstream schedule.
- Keep builders small, pure, and deterministic; they make rebuilds
  trivial.
