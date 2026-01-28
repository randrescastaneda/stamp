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
#>   root: /tmp/RtmpR7lyEd/s
#>   state: /tmp/RtmpR7lyEd/s/.stamp

# Define subdirectories (they will be created as needed)
welfare_dir <- fs::path(root_dir, "data", "welfare")
macro_dir <- fs::path(root_dir, "data", "macro")
population_dir <- macro_dir
outputs_dir <- fs::path(root_dir, "outputs") |>
  fs::dir_create()
welfare_parts_dir <- fs::path(root_dir, "data", "welfare_parts")
summary_parts_dir <- fs::path(root_dir, "outputs", "summary_parts")

fs::dir_create(c(welfare_dir, macro_dir, welfare_parts_dir, summary_parts_dir))

# Helper: list only data files with known extensions to avoid locks/sidecars
data_files <- function(dir) {
  f <- fs::dir_ls(dir)
  ext <- tolower(fs::path_ext(f))
  allowed <- c("qs2", "rds", "csv", "fst", "json")
  f[ext %in% allowed]
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
fs::dir_create(welfare_dir)

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
  fn <- fs::path(welfare_dir, sprintf("%s_%d.qs2", row$country, row$year))
  # Primary key columns include household id for uniqueness
  st_save(
    dt,
    fn,
    pk = c("country", "year", "reporting_level", "hh_id"),
    domain = "welfare"
  )
  welfare_paths[[length(welfare_paths) + 1]] <- fn
}
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2 @ version
#>   417c7eefee7da29d
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2 @ version
#>   36a516036d6dd00c
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2 @ version
#>   ad1f74be26f42903
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2 @ version
#>   f95970cf40e02cbb
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2 @ version
#>   6aa96405ae61a66c
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2 @ version
#>   57ce8c26e539e6f6
unlist(welfare_paths)
#> [1] "/tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2"
#> [2] "/tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2"
#> [3] "/tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2"
#> [4] "/tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2"
#> [5] "/tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2"
#> [6] "/tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2"
```

Each call to
[`st_save()`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
assigns a version id (if content differs) and writes sidecar metadata
including PK.

Inspect one artifact:

``` r
st_info(fs::path(welfare_dir, "COL_2010.qs2"))
#> $sidecar
#> $sidecar$path
#> [1] "/tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2"
#> 
#> $sidecar$format
#> [1] "qs2"
#> 
#> $sidecar$created_at
#> [1] "2026-01-28T15:50:47.038602Z"
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
#> [1] "417c7eefee7da29d"
#> 
#> $catalog$n_versions
#> [1] 1
#> 
#> 
#> $snapshot_dir
#> /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2/versions/417c7eefee7da29d
#> 
#> $parents
#> list()
```

### 2. Simulate and Save Macro Data (CPI, GDP, Population)

CPI & population are reporting-level granular; GDP is country-year only.

``` r
fs::dir_create(macro_dir)

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
  fs::path(macro_dir, "cpi.qs2"),
  pk = c("country", "year", "reporting_level"),
  domain = "macro"
)
#> ✔ Saved [qs2] →
#> /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 @ version cf6a9e4fc574b256
st_save(
  pop,
  fs::path(macro_dir, "population.qs2"),
  pk = c("country", "year", "reporting_level"),
  domain = "macro"
)
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/macro/population.qs2 @ version
#>   67d6e2eef7b3f61f
st_save(
  gdp,
  fs::path(macro_dir, "gdp.qs2"),
  pk = c("country", "year"),
  domain = "macro"
)
#> ✔ Saved [qs2] →
#> /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2 @ version c18a04d73750ead8
```

Version listing for CPI:

``` r
print(st_versions(fs::path(macro_dir, "cpi.qs2")))
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: cf6a9e4fc574b256 9843ac63b559e3b0 c1456c61190cd9b6      <NA>        880
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-01-28T15:50:47.670951Z           json
```

### 3. Aggregation Function `foo()` and Output Table

We compute per `(country, year, reporting_level)` welfare statistics and
merge with CPI, GDP, population. We demonstrate loading inputs inside
the function for self-containment.

``` r
foo <- function() {
  # Load all welfare micro artifacts (only recognized data files)
  welfare_files <- data_files(welfare_dir)
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

  cpi <- st_load(fs::path(macro_dir, "cpi.qs2"))
  gdp <- st_load(fs::path(macro_dir, "gdp.qs2"))
  pop <- st_load(fs::path(macro_dir, "population.qs2"))

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
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/population.qs2
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
# Define output path before save attempt
out_summary_path <- fs::path(outputs_dir, "welfare_summary.qs2")

# Only save summary if it has data (i.e., welfare data was available)
if (nrow(summary_table) > 0) {
  parent_paths <- c(
    data_files(welfare_dir),
    fs::path(macro_dir, "cpi.qs2"),
    fs::path(macro_dir, "gdp.qs2"),
    fs::path(macro_dir, "population.qs2")
  )
  parents <- lapply(parent_paths, function(p) {
    list(path = p, version_id = st_latest(p))
  })

  st_save(
    summary_table,
    out_summary_path,
    pk = c("country", "year", "reporting_level"),
    parents = parents,
    domain = "summary"
  )
  st_lineage(out_summary_path, depth = 1)
} else {
  cat("Summary table is empty; skipping save and lineage demo.\n")
}
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 @ version
#>   ecd4d43b8cb62fd9
#>   level                                    child_path    child_version
#> 1     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 2     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 3     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 4     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 5     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 6     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 7     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 8     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#> 9     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 ecd4d43b8cb62fd9
#>                                   parent_path   parent_version
#> 1 /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2 417c7eefee7da29d
#> 2 /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2 36a516036d6dd00c
#> 3 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2 ad1f74be26f42903
#> 4 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2 f95970cf40e02cbb
#> 5 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2 6aa96405ae61a66c
#> 6 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2 57ce8c26e539e6f6
#> 7        /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 cf6a9e4fc574b256
#> 8        /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2 c18a04d73750ead8
#> 9 /tmp/RtmpR7lyEd/s/data/macro/population.qs2 67d6e2eef7b3f61f
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
welfare_files <- data_files(welfare_dir)
if (length(welfare_files) > 0) {
  welfare_list <- lapply(welfare_files, st_load)
  cpi_tbl <- st_load(fs::path(macro_dir, "cpi.qs2"))
  gdp_tbl <- st_load(fs::path(macro_dir, "gdp.qs2"))
  pop_tbl <- st_load(fs::path(macro_dir, "population.qs2"))

  summary_table2 <- bar(welfare_list, cpi_tbl, gdp_tbl, pop_tbl)
  if (nrow(summary_table2) > 0) {
    st_save(
      summary_table2,
      out_summary_path,
      pk = c("country", "year", "reporting_level"),
      parents = parents,
      code = bar, # addition the function as parent so st_save() can track it
      domain = "summary"
    )
    st_lineage(out_summary_path, depth = 1)
  } else {
    cat("Summary table2 is empty; skipping save.\n")
  }
} else {
  cat("No welfare data to process in bar-and-save example.\n")
}
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 @ version
#>   6fdd4791ace10c4a
#>   level                                    child_path    child_version
#> 1     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 2     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 3     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 4     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 5     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 6     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 7     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 8     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#> 9     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 6fdd4791ace10c4a
#>                                   parent_path   parent_version
#> 1 /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2 417c7eefee7da29d
#> 2 /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2 36a516036d6dd00c
#> 3 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2 ad1f74be26f42903
#> 4 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2 f95970cf40e02cbb
#> 5 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2 6aa96405ae61a66c
#> 6 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2 57ce8c26e539e6f6
#> 7        /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 cf6a9e4fc574b256
#> 8        /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2 c18a04d73750ead8
#> 9 /tmp/RtmpR7lyEd/s/data/macro/population.qs2 67d6e2eef7b3f61f
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
cpi2 <- st_load(fs::path(macro_dir, "cpi.qs2"))
#> ✔ Loaded [qs2] ←
#> /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
cpi2[country == "COL" & year == 2012, cpi := cpi * 1.05] # 5% adjustment
st_save(cpi2, fs::path(macro_dir, "cpi.qs2")) # new version recorded
#> ✔ Saved [qs2] →
#> /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 @ version 65f6bf2b05f4831f
st_versions(fs::path(macro_dir, "cpi.qs2"))[1:3]
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: 65f6bf2b05f4831f 9843ac63b559e3b0 24996ec3b7463f5f      <NA>        895
#> 2: cf6a9e4fc574b256 9843ac63b559e3b0 c1456c61190cd9b6      <NA>        880
#> 3:             <NA>             <NA>             <NA>      <NA>         NA
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-01-28T15:50:48.940267Z           json
#> 2: 2026-01-28T15:50:47.670951Z           json
#> 3:                        <NA>           <NA>
st_is_stale(out_summary_path) # should be TRUE
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
st_register_builder(out_summary_path, function(path, parents) {
  # parents is a list of lists: each element has $path and $version_id
  # Filter parent paths to identify welfare partitions vs macros, then load them
  welfare_parent_paths <- vapply(
    parents,
    function(p) grepl("welfare", p$path),
    logical(1)
  )
  welfare_list <- lapply(parents[welfare_parent_paths], function(p) {
    st_load(p$path)
  })

  cpi_tbl <- st_load(fs::path(macro_dir, "cpi.qs2"))
  gdp_tbl <- st_load(fs::path(macro_dir, "gdp.qs2"))
  pop_tbl <- st_load(fs::path(macro_dir, "population.qs2"))

  # Produce the output using a helper function (bar) that accepts pre-loaded inputs
  out <- bar(welfare_list, cpi_tbl, gdp_tbl, pop_tbl)

  # Return the produced object plus code metadata (capture both producer and helpers)
  list(
    x = out,
    code = list(bar = bar), # include helpers as needed
    code_label = "aggregate_welfare_partitioned"
  )
})
#> ✔ Registered builder for /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2
#>   (default)
```

Inspect the plan before running it:

``` r
plan <- st_plan_rebuild(
  targets = out_summary_path,
  include_targets = TRUE,
  mode = "strict"
)
print(plan)
#>   level                                          path         reason
#> 1     0 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 parent_changed
#>   latest_version_before
#> 1      6fdd4791ace10c4a
```

Run the plan to execute the builders and record new versions:

``` r
st_rebuild(plan)
#> ✔ Rebuild level 0: 1 artifact
#>   • /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 (parent_changed)
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 @ version
#>   76c1aec6042378c7
#> OK @ version 76c1aec6042378c7
#> ✔ Rebuild summary
#>   built 1
```

This example shows the recommended pattern: load from `parents`, call a
pure worker (like `bar()`), and return `x` and `code`. That ensures
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/reference/st_rebuild.md)
can uniformly save artifacts, record lineage, and compute `code_hash`
changes for future incremental rebuilds.

Plan & rebuild using a registered builder for the summary artifact.

``` r
st_register_builder(out_summary_path, function(path, parents) {
  list(x = foo(), code = foo, code_label = "aggregate_welfare")
})
#> ✔ Registered builder for /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2
#>   (default)

plan <- st_plan_rebuild(
  targets = out_summary_path,
  include_targets = TRUE,
  mode = "strict"
)
plan
#> [1] level                 path                  reason               
#> [4] latest_version_before
#> <0 rows> (or 0-length row.names)
st_rebuild(plan)
#> ✔ Nothing to rebuild (empty plan).
st_lineage(out_summary_path, depth = 1)
#>   level                                    child_path    child_version
#> 1     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 2     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 3     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 4     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 5     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 6     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 7     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 8     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#> 9     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 76c1aec6042378c7
#>                                   parent_path   parent_version
#> 1 /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2 417c7eefee7da29d
#> 2 /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2 36a516036d6dd00c
#> 3 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2 ad1f74be26f42903
#> 4 /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2 f95970cf40e02cbb
#> 5 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2 6aa96405ae61a66c
#> 6 /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2 57ce8c26e539e6f6
#> 7        /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 65f6bf2b05f4831f
#> 8        /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2 c18a04d73750ead8
#> 9 /tmp/RtmpR7lyEd/s/data/macro/population.qs2 67d6e2eef7b3f61f
```

### 5. Add New Data (ARG 2015 Welfare)

We introduce a new welfare dataset (ARG 2015) which appears in macro
tables already. Only the summary rows for ARG 2015 will be newly added.

``` r
dt_arg_2015 <- simulate_welfare("ARG", 2015)
st_save(
  dt_arg_2015,
  fs::path(welfare_dir, "ARG_2015.qs2"),
  pk = c("country", "year", "reporting_level", "hh_id"),
  domain = "welfare"
)
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/data/welfare/ARG_2015.qs2 @ version
#>   3e74c8f76594f0d6

# Only recompute and save summary if we have welfare data
if (length(data_files(welfare_dir)) > 0 && nrow(summary_table) > 0) {
  parents2 <- lapply(
    c(
      data_files(welfare_dir),
      fs::path(macro_dir, "cpi.qs2"),
      fs::path(macro_dir, "gdp.qs2"),
      fs::path(macro_dir, "population.qs2")
    ),
    function(p) list(path = p, version_id = st_latest(p))
  )
  summary_table_new <- foo()
  if (nrow(summary_table_new) > 0) {
    st_save(
      summary_table_new,
      out_summary_path,
      pk = c("country", "year", "reporting_level"),
      parents = parents2,
      domain = "summary"
    )
    head(st_load(out_summary_path))
  } else {
    cat("Summary table after adding ARG 2015 is empty; skipping save.\n")
  }
} else {
  cat("Insufficient data to recompute summary.\n")
}
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/ARG_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/data/macro/population.qs2
#> ✔ Saved [qs2] → /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 @ version
#>   e580c61b58fd9888
#> ✔ Loaded [qs2] ← /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2
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
fs::dir_create(welfare_parts_dir)

# Write partitioned welfare (one partition per country/year/reporting_level)
for (i in seq_len(nrow(welfare_specs))) {
  row <- welfare_specs[i, ]
  dt <- simulate_welfare(row$country, row$year) # new simulated (independent from earlier saves)
  # split by reporting_level
  for (rl in unique(dt$reporting_level)) {
    part_dt <- dt[reporting_level == rl]
    st_save_part(
      part_dt,
      base = welfare_parts_dir,
      key = list(country = row$country, year = row$year, reporting_level = rl),
      code_label = "welfare_partition",
      pk = c("country", "year", "reporting_level", "hh_id")
    )
  }
}
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=urban/year=2010/part.qs2
#>   @ version 340687c05e121c17
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=rural/year=2010/part.qs2
#>   @ version 55146dee242ab4e1
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=urban/year=2012/part.qs2
#>   @ version 733ef75993438e36
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=rural/year=2012/part.qs2
#>   @ version 5025b069fcf575d9
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=urban/year=2010/part.qs2
#>   @ version 20ab8744b3223648
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2010/part.qs2
#>   @ version 0bdb234ae7949a47
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=urban/year=2015/part.qs2
#>   @ version 318baa9021f4afb2
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2015/part.qs2
#>   @ version d7b241c15ff2f582
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=PRY/reporting_level=national/year=2011/part.qs2
#>   @ version 952762c72bda3483
#> ✔ Saved [qs2] →
#>   /tmp/RtmpR7lyEd/s/data/welfare_parts/country=PRY/reporting_level=national/year=2014/part.qs2
#>   @ version 22213960b92d0214
st_list_parts(welfare_parts_dir)[1:6, ]
#>                                                                                        path
#> 1 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=rural/year=2010/part.qs2
#> 2 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=rural/year=2012/part.qs2
#> 3 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=urban/year=2010/part.qs2
#> 4 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=COL/reporting_level=urban/year=2012/part.qs2
#> 5 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2010/part.qs2
#> 6 /tmp/RtmpR7lyEd/s/data/welfare_parts/country=MEX/reporting_level=rural/year=2015/part.qs2
#>   country reporting_level year
#> 1     COL           rural 2010
#> 2     COL           rural 2012
#> 3     COL           urban 2010
#> 4     COL           urban 2012
#> 5     MEX           rural 2010
#> 6     MEX           rural 2015
```

Define a partitioned builder writing one output partition per
`(country, year, reporting_level)` summary row. Each output partition
depends on: the corresponding welfare partition + CPI + GDP + population
(all three macro artifacts are shared parents).

``` r
fs::dir_create(summary_parts_dir)

partition_keys <- st_list_parts(welfare_parts_dir)

build_partition_summary <- function(path, parents) {
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
  w_path <- st_part_path(welfare_parts_dir, key, format = NULL)
  w <- st_load(w_path)

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
  cpi <- st_load(fs::path(macro_dir, "cpi.qs2"))[
    country == key$country &
      year == as.integer(key$year) &
      reporting_level == key$reporting_level
  ]
  pop <- st_load(fs::path(macro_dir, "population.qs2"))[
    country == key$country &
      year == as.integer(key$year) &
      reporting_level == key$reporting_level
  ]
  gdp <- st_load(fs::path(macro_dir, "gdp.qs2"))[
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
# List a few partitioned summary partitions
st_list_parts(summary_parts_dir)[1:6, ]
#> [1] NA NA NA NA NA NA
```

#### Partial Re-execution After CPI Change

If CPI changes only for COL 2012, we want to rebuild only partitions for
COL 2012 across reporting levels.

``` r
# Modify CPI again (COL 2012) to trigger staleness
cpi3 <- st_load(fs::path(macro_dir, "cpi.qs2"))
#> ✔ Loaded [qs2] ←
#> /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2
cpi3[country == "COL" & year == 2012, cpi := cpi * 1.02]
st_save(cpi3, fs::path(macro_dir, "cpi.qs2"))
#> ✔ Saved [qs2] →
#> /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 @ version 19972b4addfff138

# Detect which partition outputs are stale (simple check: those whose parent CPI version differs)
summary_parts <- st_list_parts(summary_parts_dir)
stale_idx <- vapply(summary_parts$path, st_is_stale, logical(1))
summary_parts[stale_idx, ]
#> character(0)
```

Rebuild only stale partitions (manually filtered):

``` r
stale_paths <- summary_parts$path[stale_idx]
for (p in stale_paths) {
  # reconstruct key from path to identify its welfare partition parent
  rel <- fs::path_rel(p, start = summary_parts_dir)
  segs <- strsplit(dirname(rel), .Platform$file.sep)[[1]]
  kv <- lapply(segs, function(s) strsplit(s, "=")[[1]])
  key <- setNames(lapply(kv, function(x) x[2]), lapply(kv, function(x) x[1]))
  parents <- list(
    list(
      path = st_part_path(welfare_parts_dir, key),
      version_id = st_latest(st_part_path(welfare_parts_dir, key))
    ),
    list(
      path = fs::path(macro_dir, "cpi.qs2"),
      version_id = st_latest(fs::path(macro_dir, "cpi.qs2"))
    ),
    list(
      path = fs::path(macro_dir, "gdp.qs2"),
      version_id = st_latest(fs::path(macro_dir, "gdp.qs2"))
    ),
    list(
      path = fs::path(macro_dir, "population.qs2"),
      version_id = st_latest(fs::path(macro_dir, "population.qs2"))
    )
  )
  b <- build_partition_summary(p, parents)
  st_save(
    b$x,
    p,
    parents = parents,
    pk = c("country", "year", "reporting_level"),
    code = b$code,
    code_label = b$code_label
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
st_lineage(out_summary_path, depth = 2)[1:10, ]
#>    level                                    child_path    child_version
#> 1      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 2      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 3      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 4      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 5      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 6      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 7      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 8      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 9      1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#> 10     1 /tmp/RtmpR7lyEd/s/outputs/welfare_summary.qs2 e580c61b58fd9888
#>                                    parent_path   parent_version
#> 1  /tmp/RtmpR7lyEd/s/data/welfare/ARG_2015.qs2 3e74c8f76594f0d6
#> 2  /tmp/RtmpR7lyEd/s/data/welfare/COL_2010.qs2 417c7eefee7da29d
#> 3  /tmp/RtmpR7lyEd/s/data/welfare/COL_2012.qs2 36a516036d6dd00c
#> 4  /tmp/RtmpR7lyEd/s/data/welfare/MEX_2010.qs2 ad1f74be26f42903
#> 5  /tmp/RtmpR7lyEd/s/data/welfare/MEX_2015.qs2 f95970cf40e02cbb
#> 6  /tmp/RtmpR7lyEd/s/data/welfare/PRY_2011.qs2 6aa96405ae61a66c
#> 7  /tmp/RtmpR7lyEd/s/data/welfare/PRY_2014.qs2 57ce8c26e539e6f6
#> 8         /tmp/RtmpR7lyEd/s/data/macro/cpi.qs2 65f6bf2b05f4831f
#> 9         /tmp/RtmpR7lyEd/s/data/macro/gdp.qs2 c18a04d73750ead8
#> 10 /tmp/RtmpR7lyEd/s/data/macro/population.qs2 67d6e2eef7b3f61f
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
