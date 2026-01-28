# Using Aliases with stamp

## Overview

Aliases let you work with multiple, independent stamp folders in a
single R session. An alias is a selector for which folder configuration
to use; it does not change any on-disk paths. All artifact paths remain
the same regardless of alias; only the catalog, versions, and options
used are selected by alias.

Key properties:

- Aliases select a specific stamp folder initialized via
  [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md).
- Paths never include alias segments; alias affects catalog/versions
  only.
- Reusing one alias for different folders errors.
- Different aliases pointing to the same folder warn; they share the
  same catalog/versions.
- Back-compat alias `"default"` exists and can be re-based with
  [`st_switch()`](https://randrescastaneda.github.io/stamp/reference/st_switch.md).

## Setup

Initialize one or more stamp folders and give each an alias:

``` r
root_a <- fs::path(tempdir(), "projA")
root_b <- fs::path(tempdir(), "projB")

# Note: st_init() creates the folder if missing
st_init(root_a, alias = "A")
#> ✔ stamp initialized
#>   alias: A
#>   root: /tmp/RtmpAT0h5B/projA
#>   state: /tmp/RtmpAT0h5B/projA/.stamp
st_init(root_b, alias = "B")
#> ✔ stamp initialized
#>   alias: B
#>   root: /tmp/RtmpAT0h5B/projB
#>   state: /tmp/RtmpAT0h5B/projB/.stamp

# Inspect what was created
fs::dir_tree(fs::path(root_a, ".stamp"), recurse = TRUE, all = TRUE)
#> /tmp/RtmpAT0h5B/projA/.stamp
#> ├── logs
#> └── temp
fs::dir_tree(fs::path(root_b, ".stamp"), recurse = TRUE, all = TRUE)
#> /tmp/RtmpAT0h5B/projB/.stamp
#> ├── logs
#> └── temp
```

You can inspect registered aliases:

``` r
st_alias_list()
#>   alias                  root state_dir                   stamp_path
#> 1     A /tmp/RtmpAT0h5B/projA    .stamp /tmp/RtmpAT0h5B/projA/.stamp
#> 2     B /tmp/RtmpAT0h5B/projB    .stamp /tmp/RtmpAT0h5B/projB/.stamp
# Get alias details
st_alias_get("A")
#> $root
#> /tmp/RtmpAT0h5B/projA
#> 
#> $state_dir
#> [1] ".stamp"
#> 
#> $stamp_path
#> /tmp/RtmpAT0h5B/projA/.stamp
```

## Saving and Loading with Aliases

Use the same artifact path patterns; pass `alias` to select which
catalog/versions apply:

``` r
pA <- fs::path(root_a, "data.qs")
pB <- fs::path(root_b, "data.qs")

# Save different data to A and B to ensure versions are created
st_save(data.frame(id = 1:2), pA, alias = "A")
#> ✔ Saved [qs2] → /tmp/RtmpAT0h5B/projA/data.qs @
#> version da0e7928ad6e8edb
st_save(data.frame(id = 3:4), pB, alias = "B")
#> ✔ Saved [qs2] → /tmp/RtmpAT0h5B/projB/data.qs @
#> version 6d3f67aed6eeb33e

# Each alias has its own version history
st_versions(pA, alias = "A")
st_versions(pB, alias = "B")

# Loading respects the alias
objA <- st_load(pA, alias = "A")
#> Warning: No primary key recorded for /tmp/RtmpAT0h5B/projA/data.qs.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [qs2] ← /tmp/RtmpAT0h5B/projA/data.qs
objB <- st_load(pB, alias = "B")
#> Warning: No primary key recorded for /tmp/RtmpAT0h5B/projB/data.qs.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [qs2] ← /tmp/RtmpAT0h5B/projB/data.qs
list(A = objA, B = objB)
#> $A
#>   id
#> 1  1
#> 2  2
#> 
#> $B
#>   id
#> 1  3
#> 2  4

# Inspect what was created within the stamp folders
fs::dir_tree(fs::path(root_a, ".stamp"), recurse = TRUE, all = TRUE)
#> /tmp/RtmpAT0h5B/projA/.stamp
#> ├── catalog.lock
#> ├── catalog.qs2
#> ├── logs
#> └── temp
fs::dir_tree(fs::path(root_b, ".stamp"), recurse = TRUE, all = TRUE)
#> /tmp/RtmpAT0h5B/projB/.stamp
#> ├── catalog.lock
#> ├── catalog.qs2
#> ├── logs
#> └── temp
```

Version resolution is non-interactive. `NULL` or `0` resolve to the
latest version:

``` r
# Load latest (using default version = NULL for latest)
latestA <- st_load(pA, alias = "A")
#> Warning: No primary key recorded for /tmp/RtmpAT0h5B/projA/data.qs.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [qs2] ← /tmp/RtmpAT0h5B/projA/data.qs
latestB <- st_load(pB, alias = "B")
#> Warning: No primary key recorded for /tmp/RtmpAT0h5B/projB/data.qs.
#> ℹ You can add one with `st_add_pk()`.
#> ✔ Loaded [qs2] ← /tmp/RtmpAT0h5B/projB/data.qs

list(latestA = latestA, latestB = latestB)
#> $latestA
#>   id
#> 1  1
#> 2  2
#> 
#> $latestB
#>   id
#> 1  3
#> 2  4
```

## Switching the Default Alias

The special alias `"default"` exists for backward compatibility. You can
re-base it to point at any initialized folder and keep legacy state in
sync:

``` r
# Re-base default to alias A's folder (silent)
st_switch("A")

# Now calls without alias use whatever folder default points to
st_save(data.frame(id = 5), fs::path(root_a, "more.qs"))
#> ✔ Saved [qs2] → /tmp/RtmpAT0h5B/projA/more.qs @
#> version fe6f35656b629699
```

## Constraints and Conflicts

- Reusing the same alias for two different folders errors during
  [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md).
- Pointing two different aliases to the same folder warns; both operate
  on the same underlying catalog/versions.
- Aliases are case-sensitive and trimmed; prefer simple names (letters,
  digits, `_`, `-`).

## Best Practices

- Keep per-project aliases (`A`, `B`, or project codes) and avoid
  reassigning them.
- Store the alias choice alongside project scripts to make intent
  explicit.
- Use
  [`st_switch()`](https://randrescastaneda.github.io/stamp/reference/st_switch.md)
  sparingly; explicit `alias =` in calls is clearer in shared code.
- Version resolution: pass explicit version ids when pinning; use `0`
  for latest.

## Troubleshooting

- “alias conflict” error: You tried to reuse an alias for a different
  folder. Pick a new alias or re-point the original alias only if you
  intend to share catalogs.
- “same folder” warning: Two aliases target the same folder; this is
  allowed but both will share catalog/versions.
- Latest not loading: Ensure you passed `version = 0` or `NULL`; loading
  without `version` loads the current version by default.

## Notes

- Internally, `stamp` maintains a catalog with an index for lineage
  (`parents_index`) to make reverse lookups fast. Aliases do not change
  filesystem layout; they only select which catalog is used.
- Options like retention, verification, and primary key policies are
  per-alias (per folder). Configure them with
  [`st_opts()`](https://randrescastaneda.github.io/stamp/reference/st_opts.md)
  after
  [`st_init()`](https://randrescastaneda.github.io/stamp/reference/st_init.md).
