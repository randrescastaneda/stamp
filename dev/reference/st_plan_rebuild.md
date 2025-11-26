# Plan a rebuild of descendants when parents changed

Returns the set of *stale descendants* of `targets`. Two modes:

- `"propagate"` (default): treat each `target` as "will change", then
  breadth-first schedule children whose parents intersect the set of
  nodes marked "will change". Newly scheduled nodes are also marked
  "will change" so their children are considered at the next level.

- `"strict"`: only include nodes already stale against their parents'
  *current* latest versions (no propagation).

## Usage

``` r
st_plan_rebuild(
  targets,
  depth = Inf,
  include_targets = FALSE,
  mode = c("propagate", "strict")
)
```

## Arguments

- targets:

  Character vector of artifact paths.

- depth:

  Integer depth \>= 1, or Inf.

- include_targets:

  Logical; if TRUE and a target is stale, include it at level 0.

- mode:

  "propagate" (default) or "strict".

## Value

data.frame with columns: level, path, reason, latest_version_before
