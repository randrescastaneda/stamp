# Hashing, Change Detection and Versions

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

This article explains how stamp detects changes and records versions.
We’ll cover:

- Stable object hashing
  ([`st_hash_obj()`](https://randrescastaneda.github.io/stamp/reference/st_hash_obj.md)),
- Code hashing / provenance
  ([`st_hash_code()`](https://randrescastaneda.github.io/stamp/reference/st_hash_code.md)),
- Optional file hashing
  ([`st_hash_file()`](https://randrescastaneda.github.io/stamp/reference/st_hash_file.md)),
- Change-detection helpers
  ([`st_changed()`](https://randrescastaneda.github.io/stamp/reference/st_changed.md),
  [`st_changed_reason()`](https://randrescastaneda.github.io/stamp/reference/st_changed_reason.md),
  [`st_should_save()`](https://randrescastaneda.github.io/stamp/reference/st_should_save.md)),
  and
- The lightweight versions catalog
  ([`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md),
  [`st_latest()`](https://randrescastaneda.github.io/stamp/reference/st_latest.md),
  [`st_load_version()`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md)).

The core idea: stamp computes stable, reproducible hashes for objects
and (optionally) the user-supplied code. When you call
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md),
stamp compares the new hashes with stored metadata (sidecars or
committed snapshots) and decides whether to write a new version. This
allows cheap “skip-on-equal” behavior for expensive workflows.

## Recommended options

``` r
st_opts_reset()
st_opts(
  versioning = "content", # skip write when content unchanged
  code_hash = TRUE, # store code hash when 'code=' is provided to st_save()
  store_file_hash = TRUE, # compute & store file hash after write
  verify_on_load = TRUE, # verify content on load (warn on mismatch)
  meta_format = "both" # write JSON + QS2 sidecars
)
```

    ## ✔ stamp options updated
    ##   versioning = "content", code_hash = "TRUE", store_file_hash = "TRUE",
    ##   verify_on_load = "TRUE", meta_format = "both"

## Save with hashes (and skip if content identical)

``` r
root <- tempdir()
st_init(root)
```

    ## ✔ stamp initialized
    ##   root: /tmp/RtmpMHf1Qq
    ##   state: /tmp/RtmpMHf1Qq/.stamp

``` r
p <- fs::path(root, "demo.qs")
x <- data.frame(a = 1:3)

# First write: creates artifact + sidecars + catalog entry
st_save(x, p, code = function(z) z)
```

    ## ✔ Saved [qs2] → /tmp/RtmpMHf1Qq/demo.qs @
    ## version e383acdf1d5a7a85

``` r
# Second write, same content & same code: skipped (no new version)
st_save(x, p, code = function(z) z)
```

    ## ✔ Skip save (reason: no_change_policy) for
    ## /tmp/RtmpMHf1Qq/demo.qs

``` r
nrow(st_versions(p)) # should be 1
```

    ## [1] 1

In the snippet above stamp serializes `x` in a deterministic way and
computes a content hash. If both the content hash and (when provided)
the code hash match the stored metadata, no new version is created when
`versioning = "content"`.

Note: the first write will always create the artifact and its
sidecar(s). If you see the first write skipped, check that the path you
passed to
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
exactly matches subsequent calls.

If you **change content** (or **change the code**), a new version is
recorded:

``` r
x2 <- transform(x, a = a + 1L)
st_save(x2, p, code = function(z) z)
```

    ## ✔ Saved [qs2] → /tmp/RtmpMHf1Qq/demo.qs @
    ## version bce83fd704228312

``` r
nrow(st_versions(p)) # now 2
```

    ## [1] 2

``` r
st_latest(p) # latest version id (string)
```

    ## [1] "bce83fd704228312"

> **Policy:** By design, changing the `code=` you pass to
> [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
> creates a new version even if `x` is identical. This makes code
> provenance explicit.

A short practical pattern:

- Pass your transformation code to
  `st_save(..., code = <function or expression>)` so stamp can record
  the code hash.
- Use
  [`st_changed()`](https://randrescastaneda.github.io/stamp/reference/st_changed.md)
  or
  [`st_should_save()`](https://randrescastaneda.github.io/stamp/reference/st_should_save.md)
  to cheaply decide whether to run expensive computations before calling
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md).

## Inspect sidecars & metadata

``` r
meta <- st_read_sidecar(p)
meta[c(
  "format",
  "created_at",
  "size_bytes",
  "content_hash",
  "code_hash",
  "file_hash"
)]
```

    ## $format
    ## [1] "qs2"
    ## 
    ## $created_at
    ## [1] "2025-11-10T22:12:52Z"
    ## 
    ## $size_bytes
    ## [1] 154
    ## 
    ## $content_hash
    ## [1] "f05f2ec030741db5"
    ## 
    ## $code_hash
    ## [1] "488e8fa49c740261"
    ## 
    ## $file_hash
    ## [1] "2b7d70aa0270eaec"

Explanation:

- `content_hash` is the stable hash of the R object written (via
  [`st_hash_obj()`](https://randrescastaneda.github.io/stamp/reference/st_hash_obj.md)).

- `code_hash` is recorded when you provide `code=` to
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
  (via
  [`st_hash_code()`](https://randrescastaneda.github.io/stamp/reference/st_hash_code.md)).

- `file_hash` is computed after the file write (if
  `store_file_hash = TRUE`) and can be used to detect external file
  tampering.

- `content_hash` comes from `st_hash_obj(x)`

- `code_hash` comes from `st_hash_code(code)` if you supplied `code=`

- `file_hash` is optional (post-write) and is used to verify on load

## Change detection (without writing)

Use these **before** doing expensive work, to decide whether to
recompute.

``` r
x_same <- x2
x_new <- transform(x2, a = a + 10L)

st_changed(p, x = x_same, code = function(z) z)
```

    ## $changed
    ## [1] FALSE
    ## 
    ## $reason
    ## [1] "no_change"
    ## 
    ## $details
    ## $details$content_changed
    ## [1] FALSE
    ## 
    ## $details$code_changed
    ## [1] FALSE
    ## 
    ## $details$file_changed
    ## [1] FALSE

``` r
st_changed_reason(p, x = x_same, code = function(z) z) # "no_change"
```

    ## [1] "no_change"

``` r
st_changed(p, x = x_new, code = function(z) z)
```

    ## $changed
    ## [1] TRUE
    ## 
    ## $reason
    ## [1] "content"
    ## 
    ## $details
    ## $details$content_changed
    ## [1] TRUE
    ## 
    ## $details$code_changed
    ## [1] FALSE
    ## 
    ## $details$file_changed
    ## [1] FALSE

``` r
st_changed_reason(p, x = x_new, code = function(z) z) # "content"
```

    ## [1] "content"

``` r
st_should_save(p, x = x_same, code = function(z) z) # recommends skip
```

    ## $save
    ## [1] FALSE
    ## 
    ## $reason
    ## [1] "no_change_policy"

``` r
st_should_save(p, x = x_new, code = function(z) z) # recommends save
```

    ## $save
    ## [1] TRUE
    ## 
    ## $reason
    ## [1] "content"

When you call
[`st_changed()`](https://randrescastaneda.github.io/stamp/reference/st_changed.md)
or
[`st_changed_reason()`](https://randrescastaneda.github.io/stamp/reference/st_changed_reason.md)
you avoid performing any file writes. These helpers are ideal as guards
inside functions that compute expensive results only when necessary:

Example pattern inside your pipeline function:

``` r
if (st_should_save(p, x = out, code = my_transform)$save) {
  st_save(out, p, code = my_transform)
} else {
  message("Skipping write; content and code unchanged")
}
```

## Loading specific versions

``` r
vids <- st_versions(p)
head(vids)
```

    ##          version_id      artifact_id     content_hash        code_hash
    ##              <char>           <char>           <char>           <char>
    ## 1: e383acdf1d5a7a85 bcfecce15cf9de24 d73e0bf1cb9d8dc5 488e8fa49c740261
    ## 2: bce83fd704228312 bcfecce15cf9de24 f05f2ec030741db5 488e8fa49c740261
    ##    size_bytes           created_at sidecar_format
    ##         <num>               <char>         <char>
    ## 1:        201 2025-11-10T22:12:52Z           both
    ## 2:        154 2025-11-10T22:12:52Z           both

``` r
vid_latest <- st_latest(p)
obj_latest <- st_load_version(p, vid_latest)
```

    ## ✔ Loaded ← /tmp/RtmpMHf1Qq/demo.qs @
    ## bce83fd704228312 [qs2]

``` r
# Load an older version by id
if (nrow(vids) > 1L) {
  vid_old <- vids$version_id[[nrow(vids)]]
  obj_old <- st_load_version(p, vid_old)
}
```

    ## ✔ Loaded ← /tmp/RtmpMHf1Qq/demo.qs @
    ## bce83fd704228312 [qs2]

[`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md)
returns a table of version metadata. Each row includes the `version_id`,
`created_at`, and a snapshot of sidecar fields available at commit time.
Use
[`st_load_version()`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md)
to restore the artifact as it was at that version.

### Where are versions stored?

Snapshots live under `.stamp/versions/<relative-path>/<version_id>/`.

``` r
p <- fs::path(root, "demo.qs")
x <- data.frame(a = 1:5)

# Write once to create a version snapshot
st_save(x, p, code = function(z) z)
```

    ## ✔ Saved [qs2] → /tmp/RtmpMHf1Qq/demo.qs @
    ## version 956fc08574d6362f

``` r
# Now list the versions tree
vroot <- stamp:::.st_versions_root()
fs::dir_tree(vroot, recurse = TRUE, all = TRUE)
```

    ## /tmp/RtmpMHf1Qq/.stamp/versions
    ## └── demo.qs
    ##     ├── 956fc08574d6362f
    ##     │   ├── artifact
    ##     │   ├── sidecar.json
    ##     │   └── sidecar.qs2
    ##     ├── bce83fd704228312
    ##     │   ├── artifact
    ##     │   ├── sidecar.json
    ##     │   └── sidecar.qs2
    ##     └── e383acdf1d5a7a85
    ##         ├── artifact
    ##         ├── sidecar.json
    ##         └── sidecar.qs2

Each snapshot dir contains:

- `artifact` — a copy of the saved file
- `sidecar.json` and/or `sidecar.qs2` — depending on `meta_format`

Additionally each snapshot may include a `parents.json` file capturing
committed lineage between artifacts; this is created when stamp records
explicit parents during a commit. Sidecar metadata (in `stmeta/`) is the
primary local source used to decide whether to write, while snapshots
are the long-term committed record.

## Integrity checks on load (optional)

If `verify_on_load = TRUE` and a `content_hash` exists in the sidecar,
[`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
recomputes the object’s hash and warns if it differs (indicating the
file changed outside **stamp**).

``` r
invisible(st_load(p)) # triggers optional verify; warns on mismatch
```

    ## Warning: No primary key recorded for /tmp/RtmpMHf1Qq/demo.qs.
    ## ℹ You can add one with `st_add_pk()`.

    ## ✔ Loaded [qs2] ← /tmp/RtmpMHf1Qq/demo.qs

If `verify_on_load = TRUE`,
[`st_load()`](https://randrescastaneda.github.io/stamp/reference/st_load.md)
recomputes
[`st_hash_obj()`](https://randrescastaneda.github.io/stamp/reference/st_hash_obj.md)
and compares it to the `content_hash` recorded in the sidecar or
snapshot. A mismatch usually means the file was modified outside of
stamp and re-saving is recommended.

## Troubleshooting

**Q: The first
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
was skipped and `st_versions(p)` is 0.** A: The first write should
**never** be skipped. Ensure you’re using the current
[`st_should_save()`](https://randrescastaneda.github.io/stamp/reference/st_should_save.md)
which returns `save = TRUE` when the artifact is missing or the sidecar
is missing.

**Q:
[`st_changed_reason()`](https://randrescastaneda.github.io/stamp/reference/st_changed_reason.md)
says `"missing_meta"`.** A: The artifact exists but the sidecar was
removed or is unreadable. Call `st_save(x, p, code = ...)` once; it will
re-materialize metadata and record a version.

**Q: Changing only `code=` didn’t create a new version.** A: By design,
a code change **does** create a new version. Confirm
`st_opts("code_hash", .get = TRUE)` is `TRUE` and you passed `code=`
consistently (e.g., a function literal, not different object pointers to
identical functions in rare cases).

**Q: CSV round-trips aren’t byte-identical.** A:
`data.table::fread/fwrite` may coerce types (e.g., integers vs doubles).
Compare with relaxed checks or coerce types before comparison.

**Q: I see a warning on load about hash mismatch.** A: With
`verify_on_load = TRUE`, **stamp** recomputes the object hash and warns
if it differs from the sidecar’s `content_hash`. This indicates the file
was modified outside **stamp** or the sidecar is stale. Re-save to
repair.

**Q: `qs2` isn’t installed.** A: `qs2` is preferred. If unavailable,
**stamp** falls back to [qs](https://github.com/qsbase/qs) for
read/write under the `"qs2"` handler. Install
[qs2](https://github.com/qsbase/qs2) for best performance.

**Q: Sidecars not appearing.** A: Check
`st_opts("meta_format", .get = TRUE)` — set to `"json"`, `"qs2"`, or
`"both"`. Sidecars are written to `stmeta/` next to the artifact.

**Q: Versions aren’t where I expect.** A: Version snapshots live under
`.stamp/versions/<relative-path>/<version_id>/`. Use the code snippet
above to explore the tree.

## Tips & conventions

- Keep `versioning = "content"` for reproducible artifacts; use
  `"timestamp"` if you want a new version on every save; `"off"` to skip
  versioning entirely.
- Use
  [`st_changed()`](https://randrescastaneda.github.io/stamp/reference/st_changed.md)
  /
  [`st_should_save()`](https://randrescastaneda.github.io/stamp/reference/st_should_save.md)
  to gate expensive computation inside your own functions.
- Sidecars: prefer `meta_format = "json"` for readability, `"qs2"` for
  compactness, or `"both"` for redundancy.

Further reading / next steps:

- See the `lineage-rebuilds` vignette for how committed `parents` and
  sidecar parents interact during
  [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md).
- Consider recording `code=` for critical data transformations so
  provenance is preserved even when object content is identical.
