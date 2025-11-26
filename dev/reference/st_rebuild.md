# Rebuild artifacts from a plan (level order)

Rebuild artifacts from a plan (level order)

## Usage

``` r
st_rebuild(plan, rebuild_fun = NULL, dry_run = FALSE)
```

## Arguments

- plan:

  A data.frame from `st_plan_rebuild(...)` with columns:
  `level, path, reason, latest_version_before`.

- rebuild_fun:

  Optional function called as:
  `rebuild_fun(path, parents) -> list(x=..., format=?, metadata=?, code=?, code_label=?)`.
  If omitted (NULL), `st_rebuild()` will look up a registered builder
  for `path` (by
  [`st_register_builder()`](https://randrescastaneda.github.io/stamp/dev/reference/st_register_builder.md)).

- dry_run:

  If TRUE, do not write anything; just report what would happen.

## Value

Invisibly, a data.frame with the build results (status, version_id,
msg).
