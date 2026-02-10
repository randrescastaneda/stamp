
<!-- README.md is generated from README.Rmd. Please edit that file -->

# stamp

<!-- badges: start -->

[![Codecov test
coverage](https://codecov.io/gh/randrescastaneda/stamp/branch/master/graph/badge.svg)](https://app.codecov.io/gh/randrescastaneda/stamp?branch=master)
<!-- badges: end -->

Lightweight versioned artifact store for R with sidecar metadata,
pruning policies, and Hive-style partitions.

## Installation

You can install the development version of stamp from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("randrescastaneda/stamp")
```

## Quickstart

``` r
library(stamp)
root <- tempdir()
st_init(root)
#> ✔ stamp initialized
#>   alias: default
#>   root: C:/Users/wb535623/AppData/Local/Temp/2/RtmpAZV9Z4
#>   state: C:/Users/wb535623/AppData/Local/Temp/2/RtmpAZV9Z4/.stamp

p <- fs::path(root, "demo.qs")
x <- data.frame(id = 1:3, val = letters[1:3])

# Save with primary key (code parameter tracks provenance - see vignettes)
st_save(x, p, pk = "id")
#> ✔ Saved [qs2] → ']8;;file://c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qsc:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qs]8;;' @ version 55e6d708f85dc0f3
y <- st_load(p)
#> ✔ Loaded [qs2] ← ']8;;file://c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qsc:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qs]8;;'
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash        code_hash size_bytes                  created_at sidecar_format
#>              <char>           <char>           <char>           <char>      <num>                      <char>         <char>
#> 1: 55e6d708f85dc0f3 b4e25ff824bb4cef cdbe771e53841cf7             <NA>        296 2026-02-10T21:53:56.048742Z           json
#> 2: 77d3fabca8b80fbc b4e25ff824bb4cef d2b54b7e265bb11f 488e8fa49c740261        263 2026-02-10T21:17:44.985804Z           json

# Retention
st_opts(retain_versions = 2)
#> ✔ stamp options updated
#>   retain_versions = "2"
st_save(transform(x, val = toupper(val)), p)
#> ✔ Saved [qs2] → ']8;;file://c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qsc:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/demo.qs]8;;' @ version 5c7dfcd6208ba1d3
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash code_hash size_bytes                  created_at sidecar_format
#>              <char>           <char>           <char>    <char>      <num>                      <char>         <char>
#> 1: 5c7dfcd6208ba1d3 b4e25ff824bb4cef d2b54b7e265bb11f      <NA>        263 2026-02-10T21:53:56.203360Z           json
#> 2: 55e6d708f85dc0f3 b4e25ff824bb4cef cdbe771e53841cf7      <NA>        296 2026-02-10T21:53:56.048742Z           json

# Partitions
base <- fs::path(root, "inputs/country_year")
st_save_part(
  data.frame(country = "PER", year = 2023, pop = 34.5),
  base,
  key = list(country = "PER", year = 2023),
  pk = c("country", "year")
)
#> ✔ Retention policy matched zero versions; nothing to prune.
#> ✔ Saved [qs2] → ']8;;file://c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/inputs/country_year/country=per/year=2023/part.qs2c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/inputs/country_year/country=per/year=2023/part.qs2]8;;' @ version 48c0bb9d51966d76
st_list_parts(base)
#>                                                                                                   path country year
#> 1 C:/Users/wb535623/AppData/Local/Temp/2/RtmpAZV9Z4/inputs/country_year/country=per/year=2023/part.qs2     per 2023
st_load_parts(base, as = "rbind")
#> ✔ Loaded [qs2] ←
#> ']8;;file://c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/inputs/country_year/country=per/year=2023/part.qs2c:/users/wb535623/appdata/local/temp/2/rtmpazv9z4/inputs/country_year/country=per/year=2023/part.qs2]8;;'
#>   country year  pop
#> 1     per 2023 34.5
```

## Managing Multiple Stamp Folders with Aliases

See the vignette “Using Aliases with stamp” for a comprehensive guide:

- Online:
  <https://randrescastaneda.github.io/stamp/articles/using-alias.html>
- Source: `vignettes/using-alias.Rmd`

## File Formats

`stamp` supports multiple serialization formats. The two binary formats
have distinct implementations:

| Extension | Format | Package Required | Notes |
|----|----|----|----|
| `.qs2` | qs2 | `{qs2}` | New qs2 binary format (recommended for new projects) |
| `.qs` | qs | `{qs}` | Legacy qs binary format (deprecated; use `.qs2` instead) |
| `.rds` | rds | (base R) | R serialized format |
| `.csv` | csv | `{data.table}` | Comma-separated values |
| `.fst` | fst | `{fst}` | Fast columnar format |
| `.json` | json | `{jsonlite}` | JSON format |

**Important**: `.qs` and `.qs2` are **different formats** and require
their respective packages. There is no automatic fallback between them.
If you attempt to save/load a `.qs2` file without `{qs2}` installed,
`stamp` will abort with a clear error message.

> **Migration Note**: Existing `.qs` files can still be loaded if `{qs}`
> is installed. To migrate to `.qs2`, load with `st_load()` and re-save
> with `format = "qs2"`. The `.qs2` format offers better performance and
> is actively maintained.

### Installing Format Packages

``` r
# For qs2 format support
install.packages("qs2")

# For fst format support
install.packages("fst")
```

### Format Selection

`stamp` infers format from file extension by default:

``` r
# Uses qs2 format (requires {qs2})
st_save(data, "output.qs2")

# Uses RDS (base R, always available)
st_save(data, "output.rds")
```

You can also specify format explicitly:

``` r
st_save(data, "output", format = "qs2")
```

## Core Functions

The functions below are organized by workflow. **New users** should
start with *Initialization*, *Save & Load*, and *Versioning* sections.
Advanced features like partitions, lineage tracking, and aliases are
covered in the [vignettes](#learn-more).

### Initialization & Configuration

- **`st_init(root)`** - Initialize stamp in a directory, creating the
  `.stamp/` state folder
- **`st_opts()`** - Get or set package options (versioning mode,
  retention policies, metadata format)
- **`st_opts_reset()`** - Reset all options to defaults

### Save & Load

- **`st_save(x, path, ...)`** - Save an artifact with automatic
  versioning, metadata, and lineage tracking
  - Optional: `pk` (primary key), `parents` (lineage), `code`
    (provenance), `domain` (category), `alias` (target directory)
- **`st_load(path, ...)`** - Load the latest version of an artifact
  - Optional: `verify = TRUE` (check content hash), `alias` (source
    directory)
- **`st_load_version(path, version_id)`** - Load a specific historical
  version by ID

### Versioning & History

- **`st_versions(path)`** - List all versions of an artifact with
  metadata (timestamp, size, hashes)
- **`st_latest(path)`** - Get the version ID of the most recent version
- **`st_changed(x, path)`** - Check if an object differs from the saved
  version
- **`st_changed_reason(x, path)`** - Explain why content/code changed
- **`st_should_save(x, path)`** - Determine whether saving would create
  a new version

### Lineage & Dependencies

- **`st_lineage(path, depth = 1)`** - Show parent artifacts (inputs) for
  a given artifact
- **`st_children(path, depth = 1)`** - Show child artifacts (outputs)
  that depend on this artifact
- **`st_is_stale(path)`** - Check if an artifact needs rebuilding
  because parents changed

### Metadata & Inspection

- **`st_info(path)`** - Get comprehensive artifact information (sidecar,
  catalog, snapshot location, parents)
- **`st_read_sidecar(path)`** - Read sidecar metadata (hashes,
  timestamps, primary keys, domain, parents)
- **`st_hash_obj(x)`** - Compute stable hash for any R object
- **`st_hash_code(code)`** - Compute hash of code/function
- **`st_hash_file(path)`** - Compute SHA-256 hash of file on disk

### Primary Keys

- **`st_add_pk(x, pk, path)`** - Add or update primary key definition
  for an artifact
- **`st_get_pk(path)`** - Retrieve primary key columns from metadata
- **`st_inspect_pk(x, pk)`** - Validate primary key uniqueness and
  coverage

### Partitioned Data

- **`st_save_part(x, base, key, ...)`** - Save a single partition with
  Hive-style directories
- **`st_auto_partition(x, base, partition_cols, ...)`** - Automatically
  split and save dataset by partition columns
- **`st_load_parts(base, filter = NULL, as = "rbind")`** - Load and
  combine partitions matching a filter
- **`st_list_parts(base, filter = NULL)`** - List available partitions
  without loading
- **`st_part_path(base, key)`** - Construct path for a partition given
  its key

### Retention & Pruning

- **`st_prune(path, policy = NULL)`** - Remove old versions based on
  retention policy
- **`st_prune_all(policy = NULL)`** - Prune all artifacts in catalog
- **`st_retention_policy(...)`** - Create custom retention policy (keep
  N versions, recent days, or tag-based)

### Aliases (Multi-Directory Support)

- **`st_alias_register(name, root)`** - Register a named alias pointing
  to a stamp directory
- **`st_alias_list()`** - List all registered aliases
- **`st_alias_get(name = NULL)`** - Get configuration for an alias

### Builders & Rebuilds ⚠️ *Experimental*

> **Note**: The builder system is under active development. Safe for
> prototyping, but consider pinning your stamp version in production
> code until the API stabilizes (expected in v1.0).

- **`st_register_builder(path, builder_fn)`** - Register a function to
  rebuild an artifact from its parents
- **`st_clear_builders(paths = NULL)`** - Clear registered builders
- **`st_plan_rebuild(targets, ...)`** - Compute rebuild plan (which
  targets are stale and why)
- **`st_rebuild(plan)`** - Execute a rebuild plan, calling builders and
  saving results

### Filtering Helpers ⚠️ *Experimental*

> **Note**: Advanced filtering utilities are under development.

- **`st_filter(df, filters = list(), strict = TRUE)`** - Apply named
  list filters to data frames (used internally for partition queries)

## Learn More

For detailed guides and workflows, see the package vignettes:

- **[Setup and
  Basics](https://randrescastaneda.github.io/stamp/articles/setup-and-basics.html)** -
  Getting started with stamp
- **[Hashing and
  Versions](https://randrescastaneda.github.io/stamp/articles/hashing-and-versions.html)** -
  Understanding content hashing and version control
- **[Using
  Aliases](https://randrescastaneda.github.io/stamp/articles/using-alias.html)** -
  Managing multiple stamp directories
- **[Partitions](https://randrescastaneda.github.io/stamp/articles/partitions.html)** -
  Working with partitioned datasets
- **[Lineage and
  Rebuilds](https://randrescastaneda.github.io/stamp/articles/lineage-rebuilds.html)** -
  Dependency tracking and automated rebuilds
- **[Version
  Retention](https://randrescastaneda.github.io/stamp/articles/version_retention_prune.html)** -
  Managing version history with retention policies
- **[Stamp
  Directory](https://randrescastaneda.github.io/stamp/articles/stamp-directory.html)** -
  Understanding the `.stamp/` internal structure
