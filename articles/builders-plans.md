# Builders, Plans, and Rebuilds

This short vignette focuses on the core concepts that enable
reproducible, incremental rebuilding with `stamp`: builders, plans, and
rebuilds. It complements `vignettes/stamp.Rmd` by isolating patterns and
best practices you should follow when registering programmatic targets.

``` r
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".")
} else {
  library(stamp)
}
library(data.table)
set.seed(123)
```

## Key concepts

- Builder: a function registered with
  `st_register_builder(path, builder_fn)`. Signature:
  `function(path, parents)`. It must return a list with at least:

  - `x`: the object to save
  - `code`: the producing function(s) used to compute `x` (used to
    compute code_hash)
  - optional `code_label`: a short tag used in sidecars

- Plan: the result of
  [`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
  which inspects recorded parents, `code_hash` values and artifact
  presence. It describes actions required to bring targets up-to-date.

- Rebuild: executing the plan with `st_rebuild(plan)`.
  [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
  calls the registered builders and then
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
  for each produced artifact, recording new versions and sidecars.

## Minimal example (single-target)

``` r
# Suppose we have a summary target path
summary_path <- "outputs/welfare_summary.qs2"

# Register a simple builder that loads parents and returns x+code
st_register_builder(summary_path, function(path, parents) {
  # Load welfare parents (illustrative — adapt to your parents layout)
  welfare_paths <- vapply(
    parents,
    function(p) grepl("welfare", p$path),
    logical(1)
  )
  welfare_list <- lapply(parents[welfare_paths], function(p) st_load(p$path))

  # Load macros (shared parents)
  cpi_tbl <- st_load("data/macro/cpi.qs2")
  gdp_tbl <- st_load("data/macro/gdp.qs2")
  pop_tbl <- st_load("data/macro/population.qs2")

  # call a pure worker that accepts pre-loaded inputs
  out <- bar(welfare_list, cpi_tbl, gdp_tbl, pop_tbl)

  list(
    x = out,
    code = list(bar = bar),
    code_label = "aggregate_welfare"
  )
})

# Inspect plan (strict mode is conservative)
plan <- st_plan_rebuild(
  targets = summary_path,
  include_targets = TRUE,
  mode = "strict"
)
plan

# Run only if you're ready
# st_rebuild(plan)
```

## Multi-function `code` metadata

If your target depends on multiple functions (e.g. `bar()` calls helpers
`h1()` and `h2()`), include them explicitly in `code` so
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
computes a combined hash that changes if any helper changes:

``` r
# Good: include all contributing functions
st_save(
  x,
  summary_path,
  pk = c("country", "year"),
  parents = parents,
  code = list(bar = bar, h1 = h1, h2 = h2)
)
```

This ensures
[`st_is_stale()`](https://randrescastaneda.github.io/stamp/reference/st_is_stale.md)
and plan computation detect code changes across the whole chain.

## Partitioned targets and partial rebuilds

Builders can produce partitioned outputs or you can register many
builders — one per partition — to enable targeted re-computation. Two
patterns:

1.  Parent-driven builders: the builder receives `parents` and loads
    only the parents it needs. This is simple when parents are explicit
    and named in the sidecar.

2.  Directory-driven builders: the builder identifies a partition key
    from the `path` argument and computes output for that key (see
    `vignettes/stamp.Rmd` for an end-to-end example).

Example: register a partitioned builder for per-key summaries
(illustrative):

``` r
summary_parts_dir <- "outputs/summary_parts"

st_register_builder(
  fs::path(
    summary_parts_dir,
    "country=COL/year=2012/reporting_level=urban/out.qs2"
  ),
  function(path, parents) {
    # parse key from path or use parents to find the matching welfare partition
    key <- list(country = "COL", year = 2012L, reporting_level = "urban")

    # load only matching partition + macros
    w <- st_load(st_part_path("data/welfare_parts", key))
    cpi <- st_load("data/macro/cpi.qs2")[
      country == key$country &
        year == key$year &
        reporting_level == key$reporting_level
    ]
    gdp <- st_load("data/macro/gdp.qs2")[
      country == key$country & year == key$year
    ]

    out <- bar(
      list(w),
      cpi,
      gdp,
      st_load("data/macro/population.qs2")[
        country == key$country &
          year == key$year &
          reporting_level == key$reporting_level
      ]
    )

    list(x = out, code = list(bar = bar), code_label = "partition_summary")
  }
)
```

When a macro like CPI changes for COL 2012,
[`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
will mark only those partitioned targets as stale and
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
will execute the few registered builders required.

## Modes: strict vs relaxed

- `mode = "strict"` treats missing parents or mismatched code hashes
  conservatively — prefer this for correctness.
- `mode = "relaxed"` may skip some checks to avoid unnecessary
  recomputation in noisy environments; use with caution.

## Tips & best practices

- Prefer pure worker functions that accept inputs as arguments. It makes
  testing and registration easier.
- Register builders that use the `parents` argument; avoid global state
  when possible.
- Include helper functions in `code` metadata so any relevant change
  invalidates dependent artifacts.
- Keep builders deterministic and side-effect free (don’t write inside
  builder; instead return `x` and let
  [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
  call
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)).

## Try it locally

To try the examples interactively, set `eval = TRUE` in the setup chunk
and run examples inside an interactive R session. Use a short `root_dir`
to avoid Windows PATH length issues.

## Appendix: example plan interpretation

A plan is a list-of-lists; each entry includes `target` (path), a
`reason` (`parent_changed`, `code_changed`, or `missing`) and builder
info. Inspect the plan and filter or reorder actions before calling
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md).

Example (pseudo-inspection):

``` r
plan <- st_plan_rebuild(targets = summary_path, include_targets = TRUE)
# Show targets that are stale
Filter(function(x) x$reason != "uptodate", plan)
```
