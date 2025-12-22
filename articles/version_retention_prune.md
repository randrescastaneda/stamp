# Version Retention, Pruning, and Table Metadata

``` r
# Use development build when interactive *and* explicitly enabled via env var.
dev_mode <- (Sys.getenv("DEV_VIGNETTES", "false") == "true")

if (dev_mode && requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(
    export_all = FALSE,
    helpers = FALSE,
    attach_testthat = FALSE
  )
} else {
  # fall back to the installed package (the path CRAN, CI, and pkgdown take)
  library(stamp)
}
```

This vignette shows how to keep your **versions store** lean and your
**tables self-describing**:

- **Retention & pruning**: keep only the versions you need, either
  **automatically after each save** or **on demand**.
- **Table metadata**: record **primary keys (PKs)** and sidecar metadata
  so downstream code understands the **grain** and integrity of each
  table.
- **Partitioned datasets**: read/write tidy “Hive-style” layouts (e.g.,
  `country=PER/year=2023/part.qs2`) and bind them efficiently.

Key APIs:

- Global retention: `st_opts(retain_versions = policy)`
- Ad-hoc pruning:
  `st_prune_versions(path = NULL, policy = ..., dry_run = FALSE)`
- PK metadata: `st_save(..., pk = c(...))`,
  [`st_add_pk()`](https://randrescastaneda.github.io/stamp/reference/st_add_pk.md),
  [`st_inspect_pk()`](https://randrescastaneda.github.io/stamp/reference/st_inspect_pk.md)
- Partition helpers:
  [`st_part_path()`](https://randrescastaneda.github.io/stamp/reference/st_part_path.md),
  [`st_save_part()`](https://randrescastaneda.github.io/stamp/reference/st_save_part.md),
  [`st_list_parts()`](https://randrescastaneda.github.io/stamp/reference/st_list_parts.md),
  [`st_load_parts()`](https://randrescastaneda.github.io/stamp/reference/st_load_parts.md)

**Policy syntax** (for `retain_versions` or
`st_prune_versions(policy=...)`):

- `Inf` (default): keep everything.
- Integer `n`: keep the **n latest** versions per artifact.
- List union: `list(n = 5, days = 14)` keeps the **5 latest** **or**
  anything from the **last 14 days** (latest is *always* protected).

> Implementation note: we recommend your package initializes
> `retain_versions = Inf` via
> [`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md)
> defaults. If you wire `.st_apply_retention()` at the end of
> [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md),
> retention will be enforced automatically after each write. Otherwise,
> use
> [`st_prune_versions()`](https://randrescastaneda.github.io/stamp/reference/st_prune_versions.md)
> explicitly.

------------------------------------------------------------------------

## Minimal project scaffold (temp)

``` r
root <- fs::path(tempdir(), "stamp-retention-example")
if (fs::dir_exists(root)) {
  fs::dir_delete(root)
}
st_init(root)
```

    ## ✔ stamp initialized
    ##   root: /tmp/Rtmptt4cHP/stamp-retention-example
    ##   state: /tmp/Rtmptt4cHP/stamp-retention-example/.stamp

We’ll create a few artifacts and multiple versions to demonstrate
pruning:

``` r
pA <- fs::path(root, "A.qs")
pB <- fs::path(root, "B.qs")
pC <- fs::path(root, "C.qs")

xA1 <- data.frame(a = 1:3)
xA2 <- data.frame(a = 2:4)
xA3 <- data.frame(a = 3:5)

xB1 <- data.frame(b = letters[1:3])
xB2 <- data.frame(b = letters[2:4])

xC1 <- data.frame(c = 10:12)

# Keep retention OFF initially so we can create multiple versions
st_opts(retain_versions = Inf)
```

    ## ✔ stamp options updated
    ##   retain_versions = "Inf"

``` r
st_save(xA1, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/A.qs @ version
    ##   bc784010ff6f932a

``` r
st_save(xA2, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/A.qs @ version
    ##   504e63f1c081532c

``` r
st_save(xA3, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/A.qs @ version
    ##   4d65fae9bcf5794c

``` r
st_save(xB1, pB, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/B.qs @ version
    ##   2d113d9213ff7961

``` r
st_save(xB2, pB, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/B.qs @ version
    ##   04131fd06a58fbd8

``` r
st_save(xC1, pC, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/C.qs @ version
    ##   50fdaa4d57130485

Inspect store & catalog:

``` r
vroot <- stamp:::.st_versions_root()
fs::dir_tree(vroot, recurse = FALSE, all = TRUE)
```

    ## /tmp/Rtmptt4cHP/stamp-retention-example/.stamp/versions
    ## ├── A.qs
    ## ├── B.qs
    ## └── C.qs

``` r
st_versions(pA)
st_versions(pB)
st_versions(pC)
```

------------------------------------------------------------------------

## Ad-hoc pruning (explicit runs)

Use this when you want **full control** (e.g., pre-release cleanup,
occasional housekeeping, or when you don’t wire auto-retention into
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)).

### Keep the **n latest** for a specific artifact

``` r
# Dry run (safe preview)
st_prune_versions(path = pA, policy = 2, dry_run = TRUE)
```

    ## ✔ DRY RUN: 1 version would be pruned across 1 artifact.
    ##   Estimated space reclaimed: ~137 bytes

``` r
# Apply pruning
repA <- st_prune_versions(path = pA, policy = 2, dry_run = FALSE)
repA
```

    ##         artifact_id                                artifact_path
    ##              <char>                                       <char>
    ## 1: 63e45c63cc8f01d1 /tmp/Rtmptt4cHP/stamp-retention-example/A.qs
    ##          version_id                  created_at size_bytes
    ##              <char>                      <char>      <num>
    ## 1: bc784010ff6f932a 2025-12-22T11:01:33.860502Z        137

``` r
nrow(st_versions(pA)) # <= 2; latest always protected
```

    ## [1] 2

Practical tip: always run the `dry_run = TRUE` preview and inspect
`repA` before calling with `dry_run = FALSE`. The returned table
indicates which snapshots would be removed and allows you to store that
plan in CI logs for audit.

### Keep by **recency window** across the entire catalog

``` r
# Keep anything from the last 14 days; preview first
st_prune_versions(policy = list(days = 14), dry_run = TRUE)
```

    ## ✔ DRY RUN: 1 version would be pruned across 1 artifact.
    ##   Estimated space reclaimed: ~137 bytes

``` r
# Apply
repAll <- st_prune_versions(policy = list(days = 14))
```

    ## ✔ DRY RUN: 1 version would be pruned across 1 artifact.
    ##   Estimated space reclaimed: ~137 bytes

``` r
head(repAll)
```

    ##         artifact_id                                artifact_path
    ##              <char>                                       <char>
    ## 1: 63e45c63cc8f01d1 /tmp/Rtmptt4cHP/stamp-retention-example/A.qs
    ##          version_id                  created_at size_bytes
    ##              <char>                      <char>      <num>
    ## 1: 504e63f1c081532c 2025-12-22T11:01:33.929365Z        137

### Combine **count + recency** (union semantics)

``` r
# Keep last 2 versions OR any version created within 7 days
st_prune_versions(policy = list(n = 2, days = 7))
```

    ## ✔ Retention policy matched zero versions; nothing to prune.

**What the report returns**

A data frame with `artifact_path`, `version_id`, `created_at`, and
`action` (`keep`/`delete`). Use `dry_run = TRUE` to log/approve a plan
before destructive actions (recommended on shared infra/CI).

**Edge cases & guarantees**

- **Latest version is always protected** (even if it falls outside your
  policy window).
- Time windows are computed from each version’s `created_at` in the
  catalog.
- Pruning is **idempotent**: re-running with the same policy won’t
  remove more once the policy is satisfied.

------------------------------------------------------------------------

## Automatic pruning (on every `st_save()`)

If you call an internal `.st_apply_retention()` at the end of
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md),
you can choose a global policy and stop thinking about it:

``` r
# Keep only the latest 2 versions per artifact going forward
st_opts(retain_versions = 2)
```

    ## ✔ stamp options updated
    ##   retain_versions = "2"

``` r
# New save writes + immediate prune
xA4 <- data.frame(a = 4:6)
st_save(xA4, pA, code = function(z) z)
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/A.qs @ version
    ##   2f53f752ca705878

``` r
nrow(st_versions(pA)) # <= 2
```

    ## [1] 2

If you enable automatic pruning via
`st_opts(retain_versions = <policy>)`, `.st_apply_retention()` will be
invoked after each
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
and prune according to the policy for the just-written artifact. This
keeps your versions directory compact without extra housekeeping steps.

Be cautious when enabling aggressive retention (small `n` or short
`days`) in shared or collaborative projects: set `dry_run = TRUE` in CI
or have an approval step before destructive pruning.

Disable auto-pruning:

``` r
st_opts(retain_versions = Inf) # keep all versions
```

    ## ✔ stamp options updated
    ##   retain_versions = "Inf"

**Where to set this** For project-wide behavior, set
`options(stamp.retain_versions = ...)` in your project `.Rprofile`. At
runtime, `st_opts(retain_versions = ...)` takes precedence.

------------------------------------------------------------------------

## Primary-key metadata & load-time checks

Milestone 4 adds **PK metadata** so each table carries its **identity**.
This improves join safety, reproducibility, and downstream tooling
(e.g., merge validation).

### Record PK at save time (recommended)

``` r
pop <- data.frame(
  country = c("PER", "PER", "COL"),
  year = c(2023, 2024, 2023),
  reporting_level = c("national", "urban", "national"),
  pop = c(34e6, 12e6, 52e6)
)

p_pop <- fs::path(root, "inputs/population.qs")

# Validates uniqueness by default and writes PK to sidecar
# Note: `st_save(..., pk = ...)` validates the keys against the provided data
# and persists the `pk` element into the artifact's sidecar (stmeta/).
st_save(pop, p_pop, pk = c("country", "year", "reporting_level"))
```

    ## ✔ Saved [qs] → /tmp/Rtmptt4cHP/stamp-retention-example/inputs/population.qs @
    ##   version 8690a33643ea3c60

**Effects**

- Validates that PK columns exist and are unique (unless you disable
  uniqueness).
- Persists `pk` into the artifact **sidecar**.
- Attaches `attr(x, "stamp_pk")` in memory on subsequent
  [`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md).

### Inspect / repair PK later

``` r
st_inspect_pk(p_pop) # read PK from sidecar
```

    ## [1] "country"         "year"            "reporting_level"

``` r
# If an older artifact lacks PK or you need to repair metadata, use:
st_add_pk(p_pop, keys = c("country", "year", "reporting_level"))
```

    ## ✔ stamp options updated
    ##   require_pk_on_load = "FALSE"
    ## ✔ Loaded [qs] ← /tmp/Rtmptt4cHP/stamp-retention-example/inputs/population.qs
    ## ✔ Recorded primary key for
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/population.qs --> country,
    ##   year, reporting_level
    ## ✔ stamp options updated
    ##   require_pk_on_load = "FALSE"

### Load-time behavior & options

``` r
obj <- st_load(p_pop)
```

    ## ✔ Loaded [qs] ←
    ## /tmp/Rtmptt4cHP/stamp-retention-example/inputs/population.qs

``` r
attr(obj, "stamp_pk") # keys attached on load
```

    ## $keys
    ## [1] "country"         "year"            "reporting_level"

Missing PK policy:

``` r
st_opts("require_pk_on_load", .get = TRUE) # default FALSE
```

    ## [1] FALSE

``` r
st_opts("warn_missing_pk_on_load", .get = TRUE) # default TRUE
```

    ## [1] TRUE

``` r
# CI: make PK presence a hard requirement
st_opts(require_pk_on_load = TRUE, warn_missing_pk_on_load = FALSE)
```

    ## ✔ stamp options updated
    ##   require_pk_on_load = "TRUE", warn_missing_pk_on_load = "FALSE"

### Why PKs matter (joins & merges)

``` r
pop <- data.frame(
  country = c("PER", "MEX"),
  year = c(2023, 2022),
  pop = c(34.5, 126.7)
)
pop <- st_with_pk(pop, c("country", "year"))

gdp <- data.frame(
  country = c("PER", "MEX"),
  year = c(2023, 2022),
  gdp = c(0.27, 1.26)
)
gdp <- st_with_pk(gdp, c("country", "year"))

merged <- merge(pop, gdp, by = c("country", "year"))
attr(merged, "stamp_pk") <- list(keys = c("country", "year")) # preserve grain
merged
```

    ##   country year   pop  gdp
    ## 1     MEX 2022 126.7 1.26
    ## 2     PER 2023  34.5 0.27

### Catalog corruption & safety

On rare occasions a catalog file can become unreadable (disk issues,
manual edit, or process crash). The package is conservative:

- [`.st_catalog_read()`](https://randrescastaneda.github.io/stamp/reference/dot-st_catalog_read.md)
  will error if the catalog cannot be parsed. You can recover by
  removing the corrupted catalog file (it lives under
  `<root>/<state_dir>/catalog.qs2`) and re-running
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md);
  the catalog will be recreated from the remaining snapshot directories.
- Always back up the `catalog.qs2` (and `.stamp/versions/`) before
  running destructive operations in production.

Example recovery steps (manual):

1.  Move the corrupted catalog:
    `mv <state>/catalog.qs2 <state>/catalog.qs2.bak`
2.  Re-run
    [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
    on a representative artifact to recreate the catalog.

These steps are safe because pruning and catalog operations never touch
the live artifact files — only the committed snapshots and the catalog.

**Tips**

- Include **all identifier columns** in the PK (`country`, `year`,
  `reporting_level`, …). Measures are *not* part of the PK.
- Prefer recording PKs at write time. Post-hoc repairs are supported but
  easier to forget.

------------------------------------------------------------------------

## Sidecar metadata (quick reference)

Every artifact has a JSON sidecar under sibling `stmeta/` with:

- Core: `format`, `created_at`, `size_bytes`
- Integrity: `content_hash`, `code_hash`, optional `file_hash`
- Lineage: `parents`, `code_label`
- Tabular: `pk`, optional `domain`

Inspect:

``` r
side <- st_read_sidecar(p_pop)
names(side)
```

    ##  [1] "path"         "format"       "created_at"   "size_bytes"   "content_hash"
    ##  [6] "code_hash"    "file_hash"    "code_label"   "parents"      "attrs"       
    ## [11] "pk"

``` r
side$pk
```

    ## $keys
    ## [1] "country"         "year"            "reporting_level"

Integrity checks on load (if enabled via
`st_opts(verify_on_load = TRUE)`):

- Warn on mismatched `content_hash` (object changed).
- Warn on mismatched `file_hash` (file bytes changed), when recorded.

------------------------------------------------------------------------

## Partitioned datasets (Hive-style)

When you need **one file per key combo** (e.g., per country/year), use
the partition helpers. Layout:

    <base>/<k1>=<v1>/<k2>=<v2>/part.<ext>

### Create partitions & save parts

``` r
base <- fs::path(root, "inputs", "country_year")

# Paths (order of keys doesn't matter; normalized internally)
p_per_2023 <- st_part_path(
  base,
  key = list(country = "PER", year = 2023),
  format = "qs2"
)
p_mex_2022 <- st_part_path(base, key = list(country = "MEX", year = 2022))

per_tbl <- data.frame(country = "PER", year = 2023, pop = 34.5)
mex_tbl <- data.frame(country = "MEX", year = 2022, pop = 126.7)

# Save; PK recorded in each partition's sidecar
st_save_part(
  per_tbl,
  base,
  key = list(country = "PER", year = 2023),
  pk = c("country", "year")
)
```

    ## ✔ Saved [qs2] →
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=PER/year=2023/part.qs2
    ##   @ version 625eeee9cf0bd3a3

``` r
st_save_part(
  mex_tbl,
  base,
  key = list(country = "MEX", year = 2022),
  pk = c("country", "year")
)
```

    ## ✔ Saved [qs2] →
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=MEX/year=2022/part.qs2
    ##   @ version 30dbe0a5f6f67aa2

> [`st_save_part()`](https://randrescastaneda.github.io/stamp/reference/st_save_part.md)
> uses
> [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
> under the hood and writes sidecars in a local `stmeta/` directory
> inside each partition.

### Discover & load

``` r
# List artifacts (sidecars under stmeta/ are ignored)
st_list_parts(base)
```

    ##                                                                                         path
    ## 1 /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=MEX/year=2022/part.qs2
    ## 2 /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=PER/year=2023/part.qs2
    ##   country year
    ## 1     MEX 2022
    ## 2     PER 2023

``` r
st_list_parts(base, filter = list(country = "PER"))
```

    ##                                                                                         path
    ## 1 /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=PER/year=2023/part.qs2
    ##   country year
    ## 1     PER 2023

``` r
# Bind rows (adds key columns as ordinary columns)
all_parts <- st_load_parts(base, as = "rbind")
```

    ## ✔ Loaded [qs2] ←
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=MEX/year=2022/part.qs2
    ## ✔ Loaded [qs2] ←
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=PER/year=2023/part.qs2

``` r
all_parts
```

    ##   country year   pop
    ## 1     MEX 2022 126.7
    ## 2     PER 2023  34.5

``` r
# data.table option (if installed)
if (requireNamespace("data.table", quietly = TRUE)) {
  dt <- st_load_parts(base, as = "dt")
  dt[]
}
```

    ## ✔ Loaded [qs2] ←
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=MEX/year=2022/part.qs2
    ## ✔ Loaded [qs2] ←
    ##   /tmp/Rtmptt4cHP/stamp-retention-example/inputs/country_year/country=PER/year=2023/part.qs2

    ##    country   year   pop
    ##     <char> <char> <num>
    ## 1:     MEX   2022 126.7
    ## 2:     PER   2023  34.5

**Notes**

- If a partition artifact is **not** a `data.frame`,
  [`st_load_parts()`](https://randrescastaneda.github.io/stamp/reference/st_load_parts.md)
  returns a one-row table with a `.object` list-column and still appends
  the key columns.
- Folder keys (e.g., `country=PER/year=2023`) should **agree** with the
  partition table’s PK columns.

------------------------------------------------------------------------

## Recommendations & Recipes

- **Safety first**: always `dry_run = TRUE` on large catalogs; store the
  plan for auditability.
- **Auto vs. manual**: prefer **auto retention** for day-to-day saves;
  add a **manual prune** step in release or housekeeping jobs.
- **Project defaults**: set `options(stamp.retain_versions = ...)` in
  `.Rprofile`; override at runtime with
  [`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md).
- **CI**: enforce `require_pk_on_load = TRUE` and run
  `st_prune_versions(..., dry_run = TRUE)` to produce a log before
  destructive steps.
- **Time windows**: retention windows are based on `created_at` recorded
  at version creation; keep machine clocks sane on shared hosts.

------------------------------------------------------------------------

## FAQ

**Does pruning ever delete the latest version?** No. The latest version
per artifact is **always** protected.

**What’s the union semantics of `list(n, days)`?** A version is kept if
it is among the **n most recent** *or* if its `created_at` falls within
the **days** window.

**Where are PKs stored?** In each artifact’s sidecar JSON under sibling
`stmeta/`.
[`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
re-attaches them as `attr(x, "stamp_pk")`.

**Do partition helpers change how retention works?** No. Each partition
artifact is versioned/pruned independently, inheriting the same
retention policies.
