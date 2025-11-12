# Prune stored versions according to a retention policy

Prune stored versions according to a retention policy

## Usage

``` r
st_prune_versions(path = NULL, policy = Inf, dry_run = TRUE)
```

## Arguments

- path:

  Optional character vector of artifact paths to restrict pruning. If
  NULL (default), applies the policy to all artifacts in the catalog.

- policy:

  One of:

  - `Inf` (keep everything)

  - numeric scalar `n` (keep the *n* most recent per artifact)

  - `list(n = <int>, days = <num>)` (keep most recent *n* and/or those
    newer than *days*; union of the two conditions)

- dry_run:

  logical; if TRUE, only report what would be pruned.

## Value

Invisibly, a data.frame of pruned (or would-prune) versions with
columns: artifact_path, version_id, created_at, size_bytes.

## Details

**Retention policy semantics**

- `policy = Inf` — keep *all* versions (no pruning).

- `policy = <numeric>` — interpreted as “keep the **n** most recent
  versions per artifact.” For example, `policy = 2` keeps the latest two
  and prunes older ones.

- `policy = list(...)` — a combined policy where multiple conditions are
  UNIONed (kept if **any** condition keeps it):

  - `n`: keep the latest **n** per artifact.

  - `days`: keep versions whose `created_at` is within the last **days**
    days.

  - `keep_latest` / `min_keep` (internal fields in some flows) ensure at
    least a floor of versions are preserved; typical use is covered by
    `n` + `days`.

**Grouping & order.** Pruning decisions are made per artifact, after
sorting each artifact’s versions by `created_at` (newest → oldest). The
“latest n” condition is applied on this order.

**Dry runs vs destructive mode.** With `dry_run = TRUE`, the function
only reports what *would* be pruned (and estimates reclaimed space).
With `dry_run = FALSE`, it deletes the snapshot directories under
`<state_dir>/versions/...` and updates the catalog accordingly:

- removes rows from the `versions` table,

- adjusts each artifact’s `n_versions` and `latest_version_id` (to the
  newest remaining version), or drops the artifact row if none remain.

**Scope.** You can restrict pruning to specific artifacts by supplying
their paths via the `path` argument. By default (`path = NULL`), pruning
considers all artifacts recorded in the catalog. If you provide one or
more artifact paths, only versions associated with those artifacts are
considered for pruning.

**Integration with writes.** If you set a default policy via
`st_opts(retain_versions = <policy>)`, internal helpers may apply
pruning right after
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
for the just-written artifact (keep-all is the default).

**Safety notes.**

- Pruning never touches the **live artifact files** (`A.qs`, etc.) —
  only the stored version snapshots and catalog entries.

- Use `dry_run = TRUE` first to verify what would be removed.

## Examples

``` r
# \donttest{
# Minimal setup: temp project with three artifacts and multiple versions
st_opts_reset()
st_opts(versioning = "content", meta_format = "json")
#> ✔ stamp options updated
#>   versioning = "content", meta_format = "json"

root <- tempdir()
st_init(root)
#> ✔ stamp initialized
#>   root: /tmp/Rtmp8HeKbU
#>   state: /tmp/Rtmp8HeKbU/.stamp

# A, B, C
pA <- fs::path(root, "A.qs"); xA <- data.frame(a = 1:3)
pB <- fs::path(root, "B.qs"); pC <- fs::path(root, "C.qs")

# First versions
st_save(xA, pA, code = function(z) z)
#> ✔ Saved [qs2] → /tmp/Rtmp8HeKbU/A.qs @ version f96db86af708eb58
st_save(transform(xA, b = a * 2), pB, code = function(z) z,
        parents = list(list(path = pA, version_id = st_latest(pA))))
#> ✔ Saved [qs2] → /tmp/Rtmp8HeKbU/B.qs @ version c814e68fa7df0277
st_save(transform(st_load(pB), c = b + 1L), pC, code = function(z) z,
        parents = list(list(path = pB, version_id = st_latest(pB))))
#> Warning: No primary key recorded for /tmp/Rtmp8HeKbU/B.qs.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [qs2] ← /tmp/Rtmp8HeKbU/B.qs
#> ✔ Saved [qs2] → /tmp/Rtmp8HeKbU/C.qs @ version 17500e97c24cf74e

# Create a couple of extra versions for A to have data to prune
st_save(transform(xA, a = a + 10L), pA, code = function(z) z)
#> ✔ Saved [qs2] → /tmp/Rtmp8HeKbU/A.qs @ version d9c5fbd64734c859
st_save(transform(xA, a = a + 20L), pA, code = function(z) z)
#> ✔ Saved [qs2] → /tmp/Rtmp8HeKbU/A.qs @ version 47c5a50f3040a64f

# Inspect versions for A
st_versions(pA)
#>          version_id      artifact_id     content_hash        code_hash
#>              <char>           <char>           <char>           <char>
#> 1: d9c5fbd64734c859 2f65f379419ca335 f61c312c86365348 488e8fa49c740261
#> 2: 47c5a50f3040a64f 2f65f379419ca335 abf956f7a95c9738 488e8fa49c740261
#> 3: f96db86af708eb58 2f65f379419ca335 d73e0bf1cb9d8dc5 488e8fa49c740261
#>    size_bytes           created_at sidecar_format
#>         <num>               <char>         <char>
#> 1:        155 2025-11-12T22:40:46Z           json
#> 2:        155 2025-11-12T22:40:46Z           json
#> 3:        201 2025-11-12T22:40:45Z           json

# 1) Keep everything (no-op)
st_prune_versions(policy = Inf, dry_run = TRUE)
#> ✔ Retention policy is Inf: no pruning performed.

# 2) Keep only the latest 1 per artifact (dry run)
st_prune_versions(policy = 1, dry_run = TRUE)
#> ✔ DRY RUN: 2 versions would be pruned across 1 artifact.
#>   Estimated space reclaimed: ~356 bytes

# 3) Combined policy:
#    - keep the latest 2 per artifact
#    - and also keep any versions newer than 7 days (union of both)
st_prune_versions(policy = list(n = 2, days = 7), dry_run = TRUE)
#> ✔ Retention policy matched zero versions; nothing to prune.

# 4) Restrict pruning to a single artifact path
st_prune_versions(path = pA, policy = 1, dry_run = TRUE)
#> ✔ DRY RUN: 2 versions would be pruned across 1 artifact.
#>   Estimated space reclaimed: ~356 bytes

# 5) Apply pruning (destructive): keep latest 1 everywhere
#    (Uncomment to run for real)
# st_prune_versions(policy = 1, dry_run = FALSE)

# Optional: set a default retention policy and have st_save() apply it
# after each write via .st_apply_retention() (internal helper).
# For example, keep last 2 versions going forward:
st_opts(retain_versions = 2)
#> ✔ stamp options updated
#>   retain_versions = "2"
# Next saves will write a new version and then prune older ones for that artifact.
# }
```
