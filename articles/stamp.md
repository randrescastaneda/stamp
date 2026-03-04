# Stamp

## The Problem

You have multiple input files produced by different processes. You want
to read, process, and save derived artifacts while capturing.

Let’s simulate the data and folder structure:

``` r
if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".")
} else {
  library(stamp)
}
#> ℹ Loading stamp
library(data.table)
set.seed(123)

# Create an isolated temporary root so all writes occur outside the package tree.
# Use a short name to avoid long path issues on Windows (PATH_MAX = 260).
root_dir <- fs::path_temp("s") |>
  fs::dir_create()
old_wd <- setwd(root_dir)
on.exit(setwd(old_wd), add = TRUE)

# Initialize stamp under this temp root
st_init(root = root_dir)
#> ✔ stamp initialized
#>   alias: default
#>   root: /tmp/RtmpY36x6N/s
#>   state: /tmp/RtmpY36x6N/s/.stamp

# Helper: list only data files with known extensions to avoid locks/sidecars
# Returns relative paths from alias root (suitable for st_load)
data_files <- function(dir) {
  # Convert dir to relative path from root_dir if it's absolute
  rel_dir <- if (fs::is_absolute_path(dir)) {
    as.character(fs::path_rel(dir, start = root_dir))
  } else {
    dir
  }
  
  # Get absolute path for listing
  abs_dir <- fs::path(root_dir, rel_dir)
  if (!fs::dir_exists(abs_dir)) {
    return(character(0))
  }
  
  f <- fs::dir_ls(abs_dir)
  ext <- tolower(fs::path_ext(f))
  allowed <- c("qs2", "rds", "csv", "fst", "json")
  f <- f[ext %in% allowed]
  
  # Return relative paths from root_dir
  as.character(fs::path_rel(f, start = root_dir))
}
```

## The Solution

### Harmonizing Economic Indicators with Versioning & Lineage

We walk through a realistic data engineering scenario: several
country/year micro datasets and macro indicators must be combined into a
standardized output table. We want:

1.  Consistent saving, versioning, and timestamp metadata for each input
    artifact.
2.  Explicit primary keys (PK) recorded on disk.
3.  A derived summary table saved with full lineage (parents listed).
4.  Demonstrating how a single input change propagates using
    [`st_is_stale()`](https://randrescastaneda.github.io/stamp/reference/st_is_stale.md),
    [`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md),
    and
    [`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md).
5.  Adding new data (ARG 2015) and observing minimal recomputation.
6.  Producing the same output using partitioned artifacts for partial
    re-runs.

- Countries/years for welfare (micro) data: COL2010, COL2012, MEX2010,
  MEX2015, PRY2011, PRY2014.

- Reporting levels:

  - COL and MEX: both `urban` and `rural`.
  - PRY: only `national`.

- Macro data (CPI, GDP, population) exist for COL, MEX, PRY, BRA, ARG
  (2010–2015). CPI & population have all three reporting levels
  (`national`, `urban`, `rural`) for every country-year.

### 1. Simulate and Save Input Micro Data

We’ll create small synthetic micro datasets with columns: `country`,
`year`, `reporting_level`, `hh_id`, `welfare`, `weight`.

``` r
welfare_specs <- data.frame(
  country = c("COL", "COL", "MEX", "MEX", "PRY", "PRY"),
  year = c(2010, 2012, 2010, 2015, 2011, 2014),
  stringsAsFactors = FALSE
)

mk_reporting <- function(cty) {
  if (cty %in% c("COL", "MEX")) c("urban", "rural") else c("national")
}

simulate_welfare <- function(country, year) {
  rl <- mk_reporting(country)
  # 200 households per reporting level
  dt_list <- lapply(rl, function(rlev) {
    n <- 200L
    data.table(
      country = country,
      year = year,
      reporting_level = rlev,
      hh_id = sprintf("%s_%s_%s_%03d", country, year, rlev, seq_len(n)),
      welfare = round(
        rlnorm(n, meanlog = log(1000 + year) - 7, sdlog = 0.5),
        2
      ),
      weight = runif(n, 0.5, 2)
    )
  })
  rbindlist(dt_list)
}

welfare_paths <- list()
for (i in seq_len(nrow(welfare_specs))) {
  row <- welfare_specs[i, ]
  dt <- simulate_welfare(row$country, row$year)
  fn <- sprintf("data/welfare/%s_%d.qs2", row$country, row$year)
  # Primary key columns include household id for uniqueness
  st_save(
    dt,
    fn,
    pk = c("country", "year", "reporting_level", "hh_id"),
    domain = "welfare",
    alias = NULL
  )
  welfare_paths[[length(welfare_paths) + 1]] <- fn
}
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2 @ version
#>   8b1dbe696bcea9df
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/COL_2012.qs2 @ version
#>   8d0f4db0d01f9acd
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/MEX_2010.qs2 @ version
#>   fa94b52e244fdec4
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/MEX_2015.qs2 @ version
#>   d64a3d91877b4ed8
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/PRY_2011.qs2 @ version
#>   f49d447a72fc621f
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/PRY_2014.qs2 @ version
#>   c0fc350a6216ba9a
unlist(welfare_paths)
#> [1] "data/welfare/COL_2010.qs2" "data/welfare/COL_2012.qs2"
#> [3] "data/welfare/MEX_2010.qs2" "data/welfare/MEX_2015.qs2"
#> [5] "data/welfare/PRY_2011.qs2" "data/welfare/PRY_2014.qs2"
```

Each call to
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
assigns a version id (if content differs) and writes sidecar metadata
including PK.

Inspect one artifact:

``` r
st_info("data/welfare/COL_2010.qs2", alias = NULL)
#> $sidecar
#> $sidecar$path
#> [1] "/tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2"
#> 
#> $sidecar$format
#> [1] "qs2"
#> 
#> $sidecar$created_at
#> [1] "2026-03-04T21:30:24.568204Z"
#> 
#> $sidecar$size_bytes
#> [1] 4805
#> 
#> $sidecar$content_hash
#> [1] "051b413d268e903b"
#> 
#> $sidecar$code_hash
#> NULL
#> 
#> $sidecar$file_hash
#> NULL
#> 
#> $sidecar$code_label
#> NULL
#> 
#> $sidecar$parents
#> list()
#> 
#> $sidecar$attrs
#> list()
#> 
#> $sidecar$pk
#> $sidecar$pk$keys
#> [1] "country"         "year"            "reporting_level" "hh_id"          
#> 
#> 
#> $sidecar$domain
#> [1] "welfare"
#> 
#> 
#> $catalog
#> $catalog$latest_version_id
#> [1] "8b1dbe696bcea9df"
#> 
#> $catalog$n_versions
#> [1] 1
#> 
#> 
#> $snapshot_dir
#> /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2/versions/8b1dbe696bcea9df
#> 
#> $parents
#> list()
```

### 2. Simulate and Save Macro Data (CPI, GDP, Population)

CPI & population are reporting-level granular; GDP is country-year only.

``` r
years <- 2010:2015
countries_macro <- c("COL", "MEX", "PRY", "BRA", "ARG")
levels_all <- c("national", "urban", "rural")

simulate_cpi <- function() {
  out <- CJ(
    country = countries_macro,
    year = years,
    reporting_level = levels_all
  )
  out[, cpi := round(runif(.N, 80, 140), 2)]
  out
}

simulate_population <- function() {
  out <- CJ(
    country = countries_macro,
    year = years,
    reporting_level = levels_all
  )
  out[, population := round(runif(.N, 5e5, 20e6))]
  out
}

simulate_gdp <- function() {
  out <- CJ(country = countries_macro, year = years)
  out[, gdp := round(runif(.N, 1e9, 5e11))]
  out
}

cpi <- simulate_cpi()
pop <- simulate_population()
gdp <- simulate_gdp()

st_save(
  cpi,
  "data/macro/cpi.qs2",
  pk = c("country", "year", "reporting_level"),
  domain = "macro",
  alias = NULL
)
#> ✔ Saved [qs2] →
#> /tmp/RtmpY36x6N/s/data/macro/cpi.qs2 @ version 3aa865079fd51644
st_save(
  pop,
  "data/macro/population.qs2",
  pk = c("country", "year", "reporting_level"),
  domain = "macro",
  alias = NULL
)
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/macro/population.qs2 @ version
#>   4aacc11fecf18e2e
st_save(
  gdp,
  "data/macro/gdp.qs2",
  pk = c("country", "year"),
  domain = "macro",
  alias = NULL
)
#> ✔ Saved [qs2] →
#> /tmp/RtmpY36x6N/s/data/macro/gdp.qs2 @ version 314fe408d45251a0
```

Version listing for CPI:

``` r
print(st_versions("data/macro/cpi.qs2", alias = NULL))
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: 3aa865079fd51644 940ea41ee32c6d5f c1456c61190cd9b6      <NA>        880
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-03-04T21:30:25.161060Z           json
```

### 3. Aggregation Function `foo()` and Output Table

We compute per `(country, year, reporting_level)` welfare statistics and
merge with CPI, GDP, population. We demonstrate loading inputs inside
the function for self-containment.

``` r
foo <- function() {
  # Load all welfare micro artifacts (only recognized data files)
  welfare_files <- data_files("data/welfare")
  if (length(welfare_files) == 0) {
    cat("No welfare files found; returning empty table.\n")
    return(data.table::data.table())
  }
  wf <- rbindlist(lapply(welfare_files, st_load))

  stats <- wf[,
    .(
      welfare_mean = weighted.mean(welfare, weight),
      welfare_median = as.numeric(stats::median(welfare)),
      welfare_sd = stats::sd(welfare),
      welfare_n = .N
    ),
    by = .(country, year, reporting_level)
  ]

  cpi <- st_load("data/macro/cpi.qs2", alias = NULL)
  gdp <- st_load("data/macro/gdp.qs2", alias = NULL)
  pop <- st_load("data/macro/population.qs2", alias = NULL)

  # Merge; CPI & population contain rows not present in welfare; keep welfare rows only
  out <- merge(
    stats,
    cpi,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(
    out,
    pop,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(out, gdp, by = c("country", "year"), all.x = TRUE)
  setcolorder(
    out,
    c(
      "country",
      "year",
      "reporting_level",
      "welfare_mean",
      "welfare_median",
      "welfare_sd",
      "welfare_n",
      "cpi",
      "gdp",
      "population"
    )
  )
  out
}

# Call foo() to compute summary (empty if no data found)
summary_table <- foo()
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/population.qs2
if (nrow(summary_table) > 0) {
  head(summary_table)
} else {
  cat("Summary table is empty; ensure welfare data was saved.\n")
  summary_table
}
#> Key: <country, year>
#>    country  year reporting_level welfare_mean welfare_median welfare_sd
#>     <char> <int>          <char>        <num>          <num>      <num>
#> 1:     COL  2010           rural     3.188479          2.895   1.604006
#> 2:     COL  2010           urban     3.065242          2.665   1.681036
#> 3:     COL  2012           rural     3.196254          2.820   1.872963
#> 4:     COL  2012           urban     3.079524          2.750   1.627238
#> 5:     MEX  2010           rural     3.247370          2.775   1.696690
#> 6:     MEX  2010           urban     3.006862          2.710   1.606477
#>    welfare_n    cpi          gdp population
#>        <int>  <num>        <num>      <num>
#> 1:       200  92.71 449669674645   10746038
#> 2:       200  99.10 449669674645    5152778
#> 3:       200  93.11  55701684731    7761159
#> 4:       200 111.42  55701684731   15249755
#> 5:       200  93.68 384563952393    5367608
#> 6:       200 125.54 384563952393   12591517
```

Save the summary with lineage: parents include all welfare micro
datasets plus CPI/GDP/population.

``` r
# Only save summary if it has data (i.e., welfare data was available)
if (nrow(summary_table) > 0) {
  parent_paths <- c(
    data_files("data/welfare"),
    "data/macro/cpi.qs2",
    "data/macro/gdp.qs2",
    "data/macro/population.qs2"
  )
  parents <- lapply(parent_paths, function(p) {
    list(path = p, version_id = st_latest(p, alias = NULL))
  })

  st_save(
    summary_table,
    "outputs/welfare_summary.qs2",
    pk = c("country", "year", "reporting_level"),
    parents = parents,
    domain = "summary",
    alias = NULL
  )
  st_lineage("outputs/welfare_summary.qs2", depth = 1, alias = NULL)
} else {
  cat("Summary table is empty; skipping save and lineage demo.\n")
}
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/outputs/welfare_summary.qs2 @ version
#>   85d3da801bdc6602
#> [1] level          child_path     child_version  parent_path    parent_version
#> <0 rows> (or 0-length row.names)
```

Note: to make provenance explicit, pass the producing function as
`code=` so
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
records the function hash. Below we demonstrate both patterns: `foo()`
loads its own data, while `bar()` accepts pre-loaded objects and is
saved with `code = bar`.

``` r
# Variant that accepts loaded objects (preferred for testability and clarity)
bar <- function(welfare_list, cpi_tbl, gdp_tbl, pop_tbl) {
  if (length(welfare_list) == 0) {
    cat("No welfare data provided; returning empty table.\n")
    return(data.table::data.table())
  }
  wf <- data.table::rbindlist(welfare_list)
  stats <- wf[,
    .(
      welfare_mean = weighted.mean(welfare, weight),
      welfare_median = as.numeric(stats::median(welfare)),
      welfare_sd = stats::sd(welfare),
      welfare_n = .N
    ),
    by = .(country, year, reporting_level)
  ]

  out <- merge(
    stats,
    cpi_tbl,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(
    out,
    pop_tbl,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(out, gdp_tbl, by = c("country", "year"), all.x = TRUE)
  setcolorder(
    out,
    c(
      "country",
      "year",
      "reporting_level",
      "welfare_mean",
      "welfare_median",
      "welfare_sd",
      "welfare_n",
      "cpi",
      "gdp",
      "population"
    )
  )
  out
}

# Example: load inputs outside the worker and call bar()
welfare_files <- data_files("data/welfare")
if (length(welfare_files) > 0) {
  welfare_list <- lapply(welfare_files, st_load)
  cpi_tbl <- st_load("data/macro/cpi.qs2", alias = NULL)
  gdp_tbl <- st_load("data/macro/gdp.qs2", alias = NULL)
  pop_tbl <- st_load("data/macro/population.qs2", alias = NULL)

  summary_table2 <- bar(welfare_list, cpi_tbl, gdp_tbl, pop_tbl)
  if (nrow(summary_table2) > 0) {
    parent_paths <- c(
      data_files("data/welfare"),
      "data/macro/cpi.qs2",
      "data/macro/gdp.qs2",
      "data/macro/population.qs2"
    )
    parents <- lapply(parent_paths, function(p) {
      list(path = p, version_id = st_latest(p, alias = NULL))
    })
    st_save(
      summary_table2,
      "outputs/welfare_summary.qs2",
      pk = c("country", "year", "reporting_level"),
      parents = parents,
      code = bar, # addition the function as parent so st_save() can track it
      domain = "summary",
      alias = NULL
    )
    st_lineage("outputs/welfare_summary.qs2", depth = 1, alias = NULL)
  } else {
    cat("Summary table2 is empty; skipping save.\n")
  }
} else {
  cat("No welfare data to process in bar-and-save example.\n")
}
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/outputs/welfare_summary.qs2 @ version
#>   4691a9007013923a
#> [1] level          child_path     child_version  parent_path    parent_version
#> <0 rows> (or 0-length row.names)
```

Handling multiple function dependencies

If the output depends on more than one function (for example `foo()`
calls `f1()` and `f2()`), you can provide a combined `code` metadata to
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
that captures all producing functions.
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
accepts any object for `code`; best practice is to pass a short list of
the functions involved,
e.g. `code = list(foo = foo, helper1 = f1, helper2 = f2)`. The package
hashes `code` and records a `code_hash` in the sidecar so downstream
[`st_is_stale()`](https://randrescastaneda.github.io/stamp/reference/st_is_stale.md)
can detect changes in any contributor.

Example pattern:

``` r
# Provide multiple functions to st_save so code_hash changes if any of them change
# st_save(x, path, code = list(foo = foo, helper1 = f1, helper2 = f2))
```

### 4. Modify CPI (COL 2012) → New Version & Staleness

We change CPI for COL 2012 (all reporting levels) to illustrate a new
version and stale downstream artifact.

``` r
cpi2 <- st_load("data/macro/cpi.qs2", alias = NULL)
#> ✔ Loaded [qs2] ←
#> /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
cpi2[country == "COL" & year == 2012, cpi := cpi * 1.05] # 5% adjustment
st_save(cpi2, "data/macro/cpi.qs2", alias = NULL) # new version recorded
#> ✔ Saved [qs2] →
#> /tmp/RtmpY36x6N/s/data/macro/cpi.qs2 @ version d4dca467d94e562f
st_versions("data/macro/cpi.qs2", alias = NULL)[1:3]
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: d4dca467d94e562f 940ea41ee32c6d5f 24996ec3b7463f5f      <NA>        895
#> 2: 3aa865079fd51644 940ea41ee32c6d5f c1456c61190cd9b6      <NA>        880
#> 3:             <NA>             <NA>             <NA>      <NA>         NA
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-03-04T21:30:26.284852Z           json
#> 2: 2026-03-04T21:30:25.161060Z           json
#> 3:                        <NA>           <NA>
st_is_stale("outputs/welfare_summary.qs2") # should be TRUE
#> [1] TRUE
```

### Builders, plans and rebuilds — concepts and how we use them here

A short glossary and explanation of the concepts used in the examples
above:

- **Artifact**: a saved object on disk (one path managed by stamp).

- **Sidecar**: metadata file beside each artifact (PKs, parents, code
  hash, domain, timestamps).

- **Version**: immutable snapshot; new version id recorded when
  [`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
  detects changed content.

- **Parent**: pointer (path + version_id) to an upstream artifact used
  to produce a downstream artifact.

- **Lineage**: directed graph linking artifacts via parent
  relationships; inspect with
  [`st_lineage()`](https://randrescastaneda.github.io/stamp/reference/st_lineage.md).

- **Builder**: function registered with
  `st_register_builder(path, builder_fn)` that knows how to produce one
  artifact. Returns at least `x` (object to save) and `code`
  (function(s) used) so code changes trigger staleness.

- **Plan**: result of
  [`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
  describing which targets are stale (parents changed, code changed, or
  artifact missing) and thus need rebuilding.

- **Rebuild**: executing a plan via `st_rebuild(plan)`; runs builders,
  saves artifacts, updates sidecars/versions.

General idea - Register builders for reproducible targets. Builders
should be deterministic and return the object to save (do not save
directly inside the builder). - Use
[`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
to compute what needs to be rebuilt (it inspects recorded parents and
code hashes). - Inspect the plan, then call
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
to execute builders and record new versions.

How this vignette implements those ideas - We register a builder for
`out_summary_path` (see the
[`st_register_builder()`](https://randrescastaneda.github.io/stamp/reference/st_register_builder.md)
call below). That builder returns
`list(x = foo(), code = foo, code_label = "aggregate_welfare")`. -
[`st_plan_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_plan_rebuild.md)
compares current parent version ids and the code hash of `foo` against
what the sidecar recorded; if any parent or code changed the plan will
mark the target as stale. - `st_rebuild(plan)` calls the registered
builder, then
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
persistently records the new artifact and sidecar (including the new
`code_hash` and parent pointers). - This flow gives you a lightweight,
auditable, and incremental pipeline: change an upstream artifact or a
function and the plan will tell you what to rebuild.

Practical tips and a small example - Builders should prefer to use the
`parents` argument passed in (this avoids global state and makes
builders easier to test). - If your target depends on multiple
functions, pass them all in `code` so
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
records a combined code hash: `code = list(foo = foo, helper = f1)`.

Example builder that loads parents explicitly and returns multiple
functions in `code`:

``` r
# Example: register a builder that uses the provided `parents` list and avoids global loads
st_register_builder("outputs/welfare_summary.qs2", function(path, parents) {
  # parents is a list of lists: each element has $path and $version_id
  # Filter parent paths to identify welfare partitions vs macros, then load them
  welfare_parent_paths <- vapply(
    parents,
    function(p) grepl("welfare", p$path),
    logical(1)
  )
  welfare_list <- lapply(parents[welfare_parent_paths], function(p) {
    st_load(p$path, alias = NULL)
  })

  cpi_tbl <- st_load("data/macro/cpi.qs2", alias = NULL)
  gdp_tbl <- st_load("data/macro/gdp.qs2", alias = NULL)
  pop_tbl <- st_load("data/macro/population.qs2", alias = NULL)

  # Produce the output using a helper function (bar) that accepts pre-loaded inputs
  out <- bar(welfare_list, cpi_tbl, gdp_tbl, pop_tbl)

  # Return the produced object plus code metadata (capture both producer and helpers)
  list(
    x = out,
    code = list(bar = bar), # include helpers as needed
    code_label = "aggregate_welfare_partitioned"
  )
})
#> ✔ Registered builder for outputs/welfare_summary.qs2
#> (default)
```

Inspect the plan before running it:

``` r
plan <- st_plan_rebuild(
  targets = "outputs/welfare_summary.qs2",
  include_targets = TRUE,
  mode = "strict"
)
print(plan)
#>   level                        path         reason latest_version_before
#> 1     0 outputs/welfare_summary.qs2 parent_changed      4691a9007013923a
```

Run the plan to execute the builders and record new versions:

``` r
st_rebuild(plan)
#> ✔ Rebuild level 0: 1 artifact
#>   • outputs/welfare_summary.qs2 (parent_changed)
#> Warning: FAILED: ✖ Absolute path
#> /home/runner/work/stamp/stamp/vignettes/data/welfare/COL_2010.qs2 is not under
#> alias root. ℹ Alias "default" root: /tmp/RtmpY36x6N/s ℹ Provide a relative path
#> or an absolute path under the alias root.
#> ✔ Rebuild summary
#>   failed 1
```

This example shows the recommended pattern: load from `parents`, call a
pure worker (like `bar()`), and return `x` and `code`. That ensures
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
can uniformly save artifacts, record lineage, and compute `code_hash`
changes for future incremental rebuilds.

Plan & rebuild using a registered builder for the summary artifact.

``` r
st_register_builder("outputs/welfare_summary.qs2", function(path, parents) {
  list(x = foo(), code = foo, code_label = "aggregate_welfare")
})
#> ✔ Registered builder for outputs/welfare_summary.qs2
#> (default)

plan <- st_plan_rebuild(
  targets = "outputs/welfare_summary.qs2",
  include_targets = TRUE,
  mode = "strict"
)
plan
#>   level                        path         reason latest_version_before
#> 1     0 outputs/welfare_summary.qs2 parent_changed      4691a9007013923a
st_rebuild(plan)
#> ✔ Rebuild level 0: 1 artifact
#>   • outputs/welfare_summary.qs2 (parent_changed)
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/outputs/welfare_summary.qs2 @ version
#>   790b0baeb888bb52
#> OK @ version 790b0baeb888bb52
#> ✔ Rebuild summary
#>   built 1
st_lineage("outputs/welfare_summary.qs2", depth = 1, alias = NULL)
#> [1] level          child_path     child_version  parent_path    parent_version
#> <0 rows> (or 0-length row.names)
```

### 5. Add New Data (ARG 2015 Welfare)

We introduce a new welfare dataset (ARG 2015) which appears in macro
tables already. Only the summary rows for ARG 2015 will be newly added.

``` r
dt_arg_2015 <- simulate_welfare("ARG", 2015)
st_save(
  dt_arg_2015,
  "data/welfare/ARG_2015.qs2",
  pk = c("country", "year", "reporting_level", "hh_id"),
  domain = "welfare",
  alias = NULL
)
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/data/welfare/ARG_2015.qs2 @ version
#>   b24a6c84d2101331

# Only recompute and save summary if we have welfare data
if (length(data_files("data/welfare")) > 0 && nrow(summary_table) > 0) {
  parents2 <- lapply(
    c(
      data_files("data/welfare"),
      "data/macro/cpi.qs2",
      "data/macro/gdp.qs2",
      "data/macro/population.qs2"
    ),
    function(p) list(path = p, version_id = st_latest(p, alias = NULL))
  )
  summary_table_new <- foo()
  if (nrow(summary_table_new) > 0) {
    st_save(
      summary_table_new,
      "outputs/welfare_summary.qs2",
      pk = c("country", "year", "reporting_level"),
      parents = parents2,
      domain = "summary",
      alias = NULL
    )
    head(st_load("outputs/welfare_summary.qs2", alias = NULL))
  } else {
    cat("Summary table after adding ARG 2015 is empty; skipping save.\n")
  }
} else {
  cat("Insufficient data to recompute summary.\n")
}
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/ARG_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpY36x6N/s/outputs/welfare_summary.qs2 @ version
#>   d421fc3990f3fd93
#> ✔ Loaded [qs2] ← /tmp/RtmpY36x6N/s/outputs/welfare_summary.qs2
#>    country  year reporting_level welfare_mean welfare_median welfare_sd
#>     <char> <int>          <char>        <num>          <num>      <num>
#> 1:     ARG  2015        national     3.100148          2.510   1.700340
#> 2:     COL  2010           rural     3.188479          2.895   1.604006
#> 3:     COL  2010           urban     3.065242          2.665   1.681036
#> 4:     COL  2012           rural     3.196254          2.820   1.872963
#> 5:     COL  2012           urban     3.079524          2.750   1.627238
#> 6:     MEX  2010           rural     3.247370          2.775   1.696690
#>    welfare_n      cpi          gdp population
#>        <int>    <num>        <num>      <num>
#> 1:       200 120.4800 250154797653    8785981
#> 2:       200  92.7100 449669674645   10746038
#> 3:       200  99.1000 449669674645    5152778
#> 4:       200  97.7655  55701684731    7761159
#> 5:       200 116.9910  55701684731   15249755
#> 6:       200  93.6800 384563952393    5367608
```

### 6. Partitioned Workflow for Partial Re-execution

Instead of storing one large welfare micro file per country-year, we can
store partitions per `(country, year, reporting_level)` using
[`st_save_part()`](https://randrescastaneda.github.io/stamp/reference/st_save_part.md)
and then recompute only the affected partitions when an input changes.

``` r
# Write partitioned welfare (one partition per country/year/reporting_level)
for (i in seq_len(nrow(welfare_specs))) {
  row <- welfare_specs[i, ]
  dt <- simulate_welfare(row$country, row$year) # new simulated (independent from earlier saves)
  # split by reporting_level
  for (rl in unique(dt$reporting_level)) {
    part_dt <- dt[reporting_level == rl]
    st_save_part(
      part_dt,
      base = "data/welfare_parts",
      key = list(country = row$country, year = row$year, reporting_level = rl),
      code_label = "welfare_partition",
      pk = c("country", "year", "reporting_level", "hh_id"),
      alias = NULL
    )
  }
}
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=COL/reporting_level=urban/year=2010/part.qs2
#>   @ version 9c21c8ac0fc0cc7d
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=COL/reporting_level=rural/year=2010/part.qs2
#>   @ version 184a1cda0ff128c2
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=COL/reporting_level=urban/year=2012/part.qs2
#>   @ version 332d287ae5be9093
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=COL/reporting_level=rural/year=2012/part.qs2
#>   @ version 94ee27b64025ac47
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=MEX/reporting_level=urban/year=2010/part.qs2
#>   @ version 6d16f39055cb4111
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2010/part.qs2
#>   @ version 69e55b858802a922
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=MEX/reporting_level=urban/year=2015/part.qs2
#>   @ version f768ba5c09a8b0a4
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2015/part.qs2
#>   @ version 2bc801691be7a4a1
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=PRY/reporting_level=national/year=2011/part.qs2
#>   @ version 9d55a50bba9451e1
#> ✔ Saved [qs2] →
#>   /tmp/RtmpY36x6N/s/data/welfare_parts/country=PRY/reporting_level=national/year=2014/part.qs2
#>   @ version b0b70e5377279882
st_list_parts("data/welfare_parts")[1:6, ]
#> [1] NA NA NA NA NA NA
```

Define a partitioned builder writing one output partition per
`(country, year, reporting_level)` summary row. Each output partition
depends on: the corresponding welfare partition + CPI + GDP + population
(all three macro artifacts are shared parents).

``` r
partition_keys <- st_list_parts("data/welfare_parts")

build_partition_summary <- function(path, parents) {
  welfare_parts_dir <- fs::path(root_dir, "data", "welfare_parts")
  summary_parts_dir <- fs::path(root_dir, "outputs", "summary_parts")
  
  # path is the final destination for this partition artifact
  # Extract key by parsing path (we stored key in directory names)
  rel <- fs::path_rel(path, start = summary_parts_dir)
  segs <- strsplit(dirname(rel), .Platform$file.sep)[[1]]
  segs <- segs[nzchar(segs)]
  # Extract only segments that follow the key=value pattern and ignore others
  kv_pairs <- lapply(segs, function(s) {
    m <- regmatches(s, regexec("^([^=]+)=(.*)$", s))[[1]]
    if (length(m) == 3L) list(k = m[2], v = m[3]) else NULL
  })
  kv_pairs <- Filter(Negate(is.null), kv_pairs)
  if (!length(kv_pairs)) {
    key <- list()
  } else {
    key <- setNames(
      lapply(kv_pairs, function(x) x$v),
      vapply(kv_pairs, function(x) x$k, character(1))
    )
  }

  # Load welfare partition matching key
  w_path <- st_part_path("data/welfare_parts", key, format = NULL)
  w <- st_load(w_path, alias = NULL)

  stats <- w[,
    .(
      welfare_mean = weighted.mean(welfare, weight),
      welfare_median = as.numeric(median(welfare)),
      welfare_sd = sd(welfare),
      welfare_n = .N
    ),
    by = .(country, year, reporting_level)
  ]

  # Load macro (shared) and subset to key
  cpi <- st_load("data/macro/cpi.qs2", alias = NULL)[
    country == key$country &
      year == as.integer(key$year) &
      reporting_level == key$reporting_level
  ]
  pop <- st_load("data/macro/population.qs2", alias = NULL)[
    country == key$country &
      year == as.integer(key$year) &
      reporting_level == key$reporting_level
  ]
  gdp <- st_load("data/macro/gdp.qs2", alias = NULL)[
    country == key$country & year == as.integer(key$year)
  ]

  out <- merge(
    stats,
    cpi,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(
    out,
    pop,
    by = c("country", "year", "reporting_level"),
    all.x = TRUE
  )
  out <- merge(out, gdp, by = c("country", "year"), all.x = TRUE)
  list(
    x = out,
    code = build_partition_summary,
    code_label = "partition_summary"
  )
}
```

``` r
# Populate outputs/summary_parts by running the builder for each welfare partition key
summary_parts_dir <- fs::path(root_dir, "outputs", "summary_parts")
for (i in seq_len(nrow(partition_keys))) {
  key_row <- partition_keys[i, ]
  # Reconstruct key list from the partition_keys table (drop non-key columns)
  key_cols <- setdiff(names(key_row), "path")
  key <- as.list(key_row[, key_cols, drop = FALSE])
  key <- Filter(Negate(is.na), key)

  # Construct the output partition path
  out_path <- st_part_path(
    "outputs/summary_parts",
    key,
    format = "qs2"
  )

  # Build parents list: welfare partition + the three macro files
  welfare_path <- st_part_path("data/welfare_parts", key, format = NULL)
  parents_i <- list(
    list(path = welfare_path,              version_id = st_latest(welfare_path,              alias = NULL)),
    list(path = "data/macro/cpi.qs2",        version_id = st_latest("data/macro/cpi.qs2",        alias = NULL)),
    list(path = "data/macro/gdp.qs2",        version_id = st_latest("data/macro/gdp.qs2",        alias = NULL)),
    list(path = "data/macro/population.qs2", version_id = st_latest("data/macro/population.qs2", alias = NULL))
  )

  result <- build_partition_summary(out_path, parents_i)
  st_save(
    result$x,
    out_path,
    parents = parents_i,
    pk = c("country", "year", "reporting_level"),
    code = result$code,
    code_label = result$code_label,
    alias = NULL
  )
}
```

``` r
# List a few partitioned summary partitions
st_list_parts("outputs/summary_parts")[1:6, ]
#> [1] NA NA NA NA NA NA
```

#### Partial Re-execution After CPI Change

If CPI changes only for COL 2012, we want to rebuild only partitions for
COL 2012 across reporting levels.

``` r
# Modify CPI again (COL 2012) to trigger staleness
cpi3 <- st_load("data/macro/cpi.qs2", alias = NULL)
#> ✔ Loaded [qs2] ←
#> /tmp/RtmpY36x6N/s/data/macro/cpi.qs2
cpi3[country == "COL" & year == 2012, cpi := cpi * 1.02]
st_save(cpi3, "data/macro/cpi.qs2", alias = NULL)
#> ✔ Saved [qs2] →
#> /tmp/RtmpY36x6N/s/data/macro/cpi.qs2 @ version daeb308e94d8da1e

# Detect which partition outputs are stale (simple check: those whose parent CPI version differs)
summary_parts <- st_list_parts("outputs/summary_parts")
stale_idx <- vapply(summary_parts$path, st_is_stale, logical(1))
summary_parts[stale_idx, ]
#> character(0)
```

Rebuild only stale partitions (manually filtered):

``` r
stale_paths <- summary_parts$path[stale_idx]
summary_parts_dir <- fs::path(root_dir, "outputs", "summary_parts")
for (p in stale_paths) {
  # reconstruct key from path to identify its welfare partition parent
  rel <- fs::path_rel(p, start = summary_parts_dir)
  segs <- strsplit(dirname(rel), .Platform$file.sep)[[1]]
  kv <- lapply(segs, function(s) strsplit(s, "=")[[1]])
  key <- setNames(lapply(kv, function(x) x[2]), lapply(kv, function(x) x[1]))
  parents <- list(
    list(
      path = st_part_path("data/welfare_parts", key),
      version_id = st_latest(st_part_path("data/welfare_parts", key), alias = NULL)
    ),
    list(
      path = "data/macro/cpi.qs2",
      version_id = st_latest("data/macro/cpi.qs2", alias = NULL)
    ),
    list(
      path = "data/macro/gdp.qs2",
      version_id = st_latest("data/macro/gdp.qs2", alias = NULL)
    ),
    list(
      path = "data/macro/population.qs2",
      version_id = st_latest("data/macro/population.qs2", alias = NULL)
    )
  )
  b <- build_partition_summary(p, parents)
  st_save(
    b$x,
    p,
    parents = parents,
    pk = c("country", "year", "reporting_level"),
    code = b$code,
    code_label = b$code_label,
    alias = NULL
  )
}
```

Only COL 2012 partitions were recomputed, avoiding unnecessary work for
other countries/years.

### 7. Summary

We demonstrated:

- Saving multiple artifacts with PK metadata and automatic versioning.
- Building a derived summary with explicit lineage and rebuilding after
  an upstream change.
- Adding new data (ARG 2015) and incorporating it with minimal friction.
- A partitioned strategy enabling targeted re-execution for changed
  inputs.

Explore lineage further:

``` r
st_lineage("outputs/welfare_summary.qs2", depth = 2, alias = NULL)[1:10, ]
#>      level child_path child_version parent_path parent_version
#> NA      NA       <NA>          <NA>        <NA>           <NA>
#> NA.1    NA       <NA>          <NA>        <NA>           <NA>
#> NA.2    NA       <NA>          <NA>        <NA>           <NA>
#> NA.3    NA       <NA>          <NA>        <NA>           <NA>
#> NA.4    NA       <NA>          <NA>        <NA>           <NA>
#> NA.5    NA       <NA>          <NA>        <NA>           <NA>
#> NA.6    NA       <NA>          <NA>        <NA>           <NA>
#> NA.7    NA       <NA>          <NA>        <NA>           <NA>
#> NA.8    NA       <NA>          <NA>        <NA>           <NA>
#> NA.9    NA       <NA>          <NA>        <NA>           <NA>
```

**Warning: The code below will permanently delete the temporary vignette
root directory and all its contents.**

``` r
# Remove the temporary root used for vignette examples. Only run in a local
# interactive session when you are sure you no longer need the temporary files.
if (exists("root_dir") && fs::dir_exists(root_dir)) {
  # fs::dir_delete() permanently removes the directory tree.
  fs::dir_delete(root_dir)
}
```
