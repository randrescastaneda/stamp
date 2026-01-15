# Setup and Basics

``` r
# ---- setup, include=FALSE ----------------------------------------------------

if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".")
} else {
  library(stamp)
}
```

    ## ℹ Loading stamp

Let’s initialize a lightweight project and walk through the most common
workflows: formats, saving/loading, sidecars, versions/lineage,
primary-key helpers, and retention. The examples use temporary
directories so you can run them locally without touching your real
project.

## 1. Initialize a project

[`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md)
prepares a small internal state directory (by default `.stamp/`) to hold
temporary files, logs, sidecars, and version snapshots. Use a temporary
directory for vignette examples so saves and snapshots are isolated.

``` r
# Use a private temp dir so the vignette is reproducible locally
tdir <- fs::path_temp("stamp-vignette")
fs::dir_create(tdir)
st_init(tdir)
```

    ## ✔ stamp initialized
    ##   root: /tmp/RtmppjgeV2/stamp-vignette
    ##   state: /tmp/RtmppjgeV2/stamp-vignette/.stamp

``` r
# Inspect created structure
fs::path(tdir, ".stamp") |>
  fs::dir_tree(recurse = TRUE, all = TRUE)
```

    ## /tmp/RtmppjgeV2/stamp-vignette/.stamp
    ## ├── logs
    ## └── temp

Notes - Default state dir: `.stamp/` (you can override via
`st_init(state_dir = "_stamp")`).

## 2. Options (`st_opts()`)

Global behavior is controlled via
[`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md).
Typical options you will use:

- `meta_format`: how sidecars are written. Allowed: `"json"`, `"qs2"`,
  or `"both"`.
- `default_format`: which format to use when none is inferred from a
  path.
- `versioning`: controls whether saves create version snapshots
  (`"content"` vs `"timestamp"` vs \`“off”).

Example:

``` r
# show defaults
st_opts(.get = TRUE)
```

    ## $force_on_code_change
    ## [1] TRUE
    ## 
    ## $retain_versions
    ## [1] Inf
    ## 
    ## $versioning
    ## [1] "content"
    ## 
    ## $meta_format
    ## [1] "json"
    ## 
    ## $usetz
    ## [1] FALSE
    ## 
    ## $timeformat
    ## [1] "%Y%m%d%H%M%S"
    ## 
    ## $code_hash
    ## [1] TRUE
    ## 
    ## $default_format
    ## [1] "qs2"
    ## 
    ## $verify_on_load
    ## [1] FALSE
    ## 
    ## $store_file_hash
    ## [1] FALSE
    ## 
    ## $verbose
    ## [1] TRUE
    ## 
    ## $timezone
    ## [1] "UTC"
    ## 
    ## $require_pk_on_load
    ## [1] FALSE
    ## 
    ## $warn_missing_pk_on_load
    ## [1] TRUE

``` r
# write both JSON and QS2 sidecars
st_opts(meta_format = "both")
```

    ## ✔ stamp options updated
    ##   meta_format = "both"

``` r
st_opts("meta_format", .get = TRUE)
```

    ## [1] "both"

Use `versioning` to control when a version snapshot is recorded. The
default `"content"` mode records a new version only when content/code
changed; `"timestamp"` forces a version on every save (useful for audit
trails).

## 3. Paths and format registry

[`st_path()`](https://randrescastaneda.github.io/stamp/reference/st_path.md)
wraps a path string and optionally carries an explicit `format` hint.
Format inference also maps known extensions (via an internal registry).

``` r
p1 <- st_path("data/iris.qs2")
p2 <- st_path("data/mtcars.fst", format = "fst")
p1
```

    ## <st_path> data/iris.qs2 [format=qs2]

``` r
st_formats()  # built-in handlers: qs2, rds, csv, fst, json
```

    ## [1] "csv"     "fst"     "json"    "parquet" "qs"      "qs2"     "rds"

You can extend the registry with
[`st_register_format()`](https://randrescastaneda.github.io/stamp/reference/st_register_format.md)
to add a new format (e.g. Parquet). The registry will also map file
extensions if you provide them.

## 4. Save & load (atomic, with sidecar metadata)

Use
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
and
[`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
for robust writes.
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
performs an atomic write (temp file then move), writes sidecar metadata,
and — depending on `versioning` — records a version snapshot.

``` r
x <- data.frame(a = 1:3, b = letters[1:3])
outdir <- fs::path_temp("stamp-output")
fs::dir_create(outdir)

res <- st_save(x, fs::path(outdir, "example.qs2"), metadata = list(description = "toy"))
```

    ## ✔ Saved [qs2] → /tmp/RtmppjgeV2/stamp-output/example.qs2 @ version
    ##   6292eb7ca0dde8b7

``` r
res$path
```

    ## /tmp/RtmppjgeV2/stamp-output/example.qs2

``` r
# load back (format auto-detected)
y <- st_load(res$path)
```

    ## Warning: No primary key recorded for /tmp/RtmppjgeV2/stamp-output/example.qs2.
    ## ℹ You can add one with `st_add_pk()`.

    ## ✔ Loaded [qs2] ←
    ## /tmp/RtmppjgeV2/stamp-output/example.qs2

``` r
identical(x, y)
```

    ## [1] TRUE

[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
accepts additional arguments useful for provenance:

- `code`: a function/expression whose hash is recorded (via
  `st_hash_code`).
- `parents`: optional list of parent descriptors (list(list(path=…,
  version_id=…), …)) to record provenance.
- `code_label`: a short human label for the producing code.

### 4.1 Loading specific versions

The `version` argument in
[`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
allows you to load historical versions of artifacts. This is useful for
comparing changes over time or recovering from mistakes.

``` r
# Create multiple versions by modifying and saving
v_path <- fs::path(outdir, "versioned.qs2")

# Version 1
v1 <- data.frame(x = 1:3, y = c("a", "b", "c"))
st_save(v1, v_path, code_label = "initial")
```

    ## ✔ Saved [qs2] → /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @ version
    ##   5d2ed2542e7dfd53

``` r
Sys.sleep(0.15)  # ensure distinct timestamps

# Version 2
v2 <- data.frame(x = 1:5, y = c("a", "b", "c", "d", "e"))
st_save(v2, v_path, code_label = "added rows")
```

    ## ✔ Saved [qs2] → /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @ version
    ##   090b4b384827db4f

``` r
Sys.sleep(0.15)

# Version 3
v3 <- data.frame(x = 1:5, y = c("a", "b", "c", "d", "e"), z = 10:14)
st_save(v3, v_path, code_label = "added column z")
```

    ## ✔ Saved [qs2] → /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @ version
    ##   8696ba3158f1b6ad

``` r
# Check available versions
versions <- st_versions(v_path)
print(versions[, .(version_id, created_at, size_bytes)])
```

    ##          version_id                  created_at size_bytes
    ##              <char>                      <char>      <num>
    ## 1: 8696ba3158f1b6ad 2026-01-15T22:48:54.003835Z        287
    ## 2: 090b4b384827db4f 2026-01-15T22:48:53.781500Z        262
    ## 3: 5d2ed2542e7dfd53 2026-01-15T22:48:53.485910Z        261

``` r
# Load latest (default)
current <- st_load(v_path)
```

    ## Warning: No primary key recorded for /tmp/RtmppjgeV2/stamp-output/versioned.qs2.
    ## ℹ You can add one with `st_add_pk()`.

    ## ✔ Loaded [qs2] ←
    ## /tmp/RtmppjgeV2/stamp-output/versioned.qs2

``` r
nrow(current)  # 5 rows, 3 columns
```

    ## [1] 5

``` r
# Load previous version (version = -1)
previous <- st_load(v_path, version = -1)
```

    ## ✔ Loaded ← /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @
    ## 090b4b384827db4f [qs2]

``` r
nrow(previous)  # 5 rows, 2 columns (before adding z)
```

    ## [1] 5

``` r
# Load two versions back (version = -2)
older <- st_load(v_path, version = -2)
```

    ## ✔ Loaded ← /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @
    ## 5d2ed2542e7dfd53 [qs2]

``` r
nrow(older)  # 3 rows, 2 columns (original)
```

    ## [1] 3

``` r
# Load specific version by ID
vid <- versions$version_id[1]  # oldest version
specific <- st_load(v_path, version = vid)
```

    ## ✔ Loaded ← /tmp/RtmppjgeV2/stamp-output/versioned.qs2 @
    ## 8696ba3158f1b6ad [qs2]

``` r
identical(specific, older)
```

    ## [1] FALSE

The `version` argument supports several modes:

- `NULL` (default): loads the current artifact file
- `0`: same as NULL, loads latest version
- Negative integers (`-1`, `-2`, etc.): load versions relative to latest
- Character string: specific version ID (from
  [`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md))
- `"select"`, `"pick"`, or `"choose"`: interactive menu (in interactive
  sessions)

``` r
# Interactive menu to choose a version (only works in interactive R sessions)
# This will display a menu with formatted timestamps and file sizes
selected <- st_load(v_path, version = "select")

# The menu looks like:
# ℹ Select a version to load from versioned.qs2:
#   Latest version is [1]
# 
# Available versions:
# 
# 1: [1] 2025-11-26 10:30:15 (0.12 MB) - 20251126T103015Z
# 2: [2] 2025-11-26 10:30:10 (0.10 MB) - 20251126T103010Z
# 3: [3] 2025-11-26 10:30:05 (0.08 MB) - 20251126T103005Z
# 
# Selection: _
```

## 5. Sidecars (quick metadata)

Sidecars live in an `stmeta/` sibling directory next to the artifact and
contain metadata such as `path`, `format`, `created_at` (UTC),
`size_bytes`, `content_hash`, `code_hash`, `code_label`, and `parents`
(a quick view).

``` r
sc <- st_read_sidecar(res$path)
str(sc)
```

    ## List of 11
    ##  $ path        : chr "/tmp/RtmppjgeV2/stamp-output/example.qs2"
    ##  $ format      : chr "qs2"
    ##  $ created_at  : chr "2026-01-15T22:48:53.257448Z"
    ##  $ size_bytes  : int 256
    ##  $ content_hash: chr "99235ac79dea7ab0"
    ##  $ code_hash   : NULL
    ##  $ file_hash   : NULL
    ##  $ code_label  : NULL
    ##  $ parents     : list()
    ##  $ attrs       : list()
    ##  $ description : chr "toy"

The sidecar is intended for quick inspection and for storing metadata
even when a version snapshot may not be recorded (e.g., when
`versioning = "content"` and nothing changed). For reproducible lineage
and rebuilds,
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
writes a snapshot under `.stamp/versions/` that includes committed
copies of the artifact and its parents.json.

## 6. Versions, lineage, and inspection

The package maintains a simple catalog of versions. Useful functions:

- `st_versions(path)` — list recorded versions for an artifact.
- `st_latest(path)` — get the latest version id.
- `st_load_version(path, version_id)` — load a specific recorded
  version.
- `st_info(path)` — quick inspection: returns current sidecar, catalog
  info, snapshot dir (if present), and parents (from snapshot or sidecar
  fallback).
- `st_lineage(path, depth=1)` — walk immediate or recursive parents.

Example that demonstrates parents and lineage (parents passed to
`st_save`):

``` r
# upstream artifact
in_path <- fs::path(outdir, "upstream.qs")
st_save(data.frame(id=1:3), in_path)
```

    ## ✔ Saved [qs] → /tmp/RtmppjgeV2/stamp-output/upstream.qs @ version
    ##   720f8ee224d56044

``` r
in_vid <- st_latest(in_path)

# derived artifact recording parent info
out_path <- fs::path(outdir, "derived.qs")
parents <- list(list(path = in_path, version_id = in_vid))
st_save(data.frame(id=1:3, v=10), out_path, parents = parents, code_label = "multiply")
```

    ## ✔ Saved [qs] → /tmp/RtmppjgeV2/stamp-output/derived.qs @ version
    ##   4da08b74396a9e82

``` r
st_info(out_path)$sidecar
```

    ## $path
    ## [1] "/tmp/RtmppjgeV2/stamp-output/derived.qs"
    ## 
    ## $format
    ## [1] "qs"
    ## 
    ## $created_at
    ## [1] "2026-01-15T22:48:54.521163Z"
    ## 
    ## $size_bytes
    ## [1] 150
    ## 
    ## $content_hash
    ## [1] "a6f9da7f2b465601"
    ## 
    ## $code_hash
    ## NULL
    ## 
    ## $file_hash
    ## NULL
    ## 
    ## $code_label
    ## [1] "multiply"
    ## 
    ## $parents
    ##                                       path       version_id
    ## 1 /tmp/RtmppjgeV2/stamp-output/upstream.qs 720f8ee224d56044
    ## 
    ## $attrs
    ## list()

``` r
st_lineage(out_path, depth = 1)
```

    ##   level                              child_path    child_version
    ## 1     1 /tmp/RtmppjgeV2/stamp-output/derived.qs 4da08b74396a9e82
    ##                                parent_path   parent_version
    ## 1 /tmp/RtmppjgeV2/stamp-output/upstream.qs 720f8ee224d56044

Notes on behavior - The sidecar always contains `parents` for quick
inspection. However, in the default `versioning = "content"` mode a new
committed snapshot (and its `parents.json`) will only be created when
content or code changed. The vignette code above deliberately saves
upstream and derived artifacts so a snapshot is recorded.

## 7. Primary-key helpers (optional)

You can record a primary-key (pk) for an artifact in its sidecar to make
it easier to identify rows later. Helpers:

- [`st_pk()`](https://randrescastaneda.github.io/stamp/reference/st_pk.md)
  — normalize/validate a pk spec.
- `st_add_pk(path, keys)` — record a pk in the artifact sidecar
  (optionally validate against on-disk content).
- `st_inspect_pk(path)` — read pk from sidecar.
- `st_with_pk(df, keys)` and
  [`st_get_pk()`](https://randrescastaneda.github.io/stamp/reference/st_get_pk.md)
  — in-memory helpers.

Example:

``` r
st_add_pk(out_path, keys = c("id"))
```

    ## ✔ stamp options updated
    ##   require_pk_on_load = "FALSE"

    ## Warning: No primary key recorded for /tmp/RtmppjgeV2/stamp-output/derived.qs.
    ## ℹ You can add one with `st_add_pk()`.

    ## ✔ Loaded [qs] ← /tmp/RtmppjgeV2/stamp-output/derived.qs
    ## ✔ Recorded primary key for /tmp/RtmppjgeV2/stamp-output/derived.qs --> id
    ## ✔ stamp options updated
    ##   require_pk_on_load = "FALSE"

``` r
st_inspect_pk(out_path)
```

    ## [1] "id"

``` r
# load and filter by pk using st_filter
df <- st_load(out_path)
```

    ## ✔ Loaded [qs] ←
    ## /tmp/RtmppjgeV2/stamp-output/derived.qs

``` r
st_filter(df, list(id = 1))
```

    ##   id  v
    ## 1  1 10

## 8. Retention / pruning

To control disk usage,
[`st_prune_versions()`](https://randrescastaneda.github.io/stamp/reference/st_prune_versions.md)
prunes older version snapshots according to a retention policy. The
simplest call applies the default project policy; you can also pass
`policy` or use `dry_run = TRUE` to preview.

``` r
# dry-run to preview deletions for this artifact
st_prune_versions(path = out_path, policy = 5, dry_run = TRUE)

# apply retention (non-dry)
st_prune_versions(path = out_path, policy = list(n = 5, days = 30), dry_run = FALSE)
```

## 9. Tips and conventions

- Prefer `qs2` for artifact storage for speed/space, use JSON sidecars
  for readability during development.
- Use
  [`st_path()`](https://randrescastaneda.github.io/stamp/reference/st_path.md)
  when you want explicit format hints in code.
- Use
  [`st_info()`](https://randrescastaneda.github.io/stamp/reference/st_info.md)
  and
  [`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md)
  to inspect provenance; use
  [`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md)
  and
  [`st_load_version()`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md)
  to access historical snapshots.
