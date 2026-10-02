---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# stamp

<!-- badges: start -->
[![Codecov test coverage](https://codecov.io/gh/randrescastaneda/stamp/branch/master/graph/badge.svg)](https://app.codecov.io/gh/randrescastaneda/stamp?branch=master)
<!-- badges: end -->

Lightweight versioned artifact store for R with sidecar metadata and pruning
policies.


## Installation

You can install the development version of stamp from [GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("randrescastaneda/stamp")
```

## Quickstart


``` r
library(stamp)
root <- "demo_stamp"
st_init(root)
#> ✔ stamp initialized
#>   alias: default
#>   root: E:/PovcalNet/01.personal/wb535623/PIP/stamp/demo_stamp
#>   state: E:/PovcalNet/01.personal/wb535623/PIP/stamp/demo_stamp/.stamp

p <- "demo.qs2"
x <- data.frame(id = 1:3, val = letters[1:3])

# Save with primary key (code parameter tracks provenance - see vignettes)
st_save(x, p, pk = "id")
#> ✔ Saved [qs2] →
#>   'e:/povcalnet/01.personal/wb535623/pip/stamp/demo_stamp/demo.qs2' @ version
#>   56b8bed4353089fc
y <- st_load(p)
#> ✔ Loaded [qs2] ←
#>   'e:/povcalnet/01.personal/wb535623/pip/stamp/demo_stamp/demo.qs2'
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: 56b8bed4353089fc c124606df64bb597 82872a9f48806630      <NA>        296
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-10-02T18:07:02.098726Z           json

# Retention
st_opts(retain_versions = 2)
#> ✔ stamp options updated
#>   retain_versions = "2"
st_save(transform(x, val = toupper(val)), p)
#> ✔ Retention policy matched zero versions; nothing to prune.
#> ✔ Saved [qs2] →
#>   'e:/povcalnet/01.personal/wb535623/pip/stamp/demo_stamp/demo.qs2' @ version
#>   36bbc93780811846
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash code_hash size_bytes
#>              <char>           <char>           <char>    <char>      <num>
#> 1: 36bbc93780811846 c124606df64bb597 714bd8da989ab3a8      <NA>        264
#> 2: 56b8bed4353089fc c124606df64bb597 82872a9f48806630      <NA>        296
#>                     created_at sidecar_format
#>                         <char>         <char>
#> 1: 2026-10-02T18:07:02.249957Z           json
#> 2: 2026-10-02T18:07:02.098726Z           json
```

## Managing Multiple Stamp Folders with Aliases

See the vignette "Using Aliases with stamp" for a comprehensive guide:

- Online: https://randrescastaneda.github.io/stamp/articles/using-alias.html
- Source: `vignettes/using-alias.Rmd`

## File Formats

`stamp` supports multiple serialization formats. The two binary formats have distinct implementations:

| Extension | Format | Package Required | Notes |
|-----------|--------|------------------|-------|
| `.qs2` | qs2 | `{qs2}` | Binary format (recommended for new projects) |
| `.rds` | rds | (base R) | R serialized format |
| `.csv` | csv | `{data.table}` | Comma-separated values |
| `.fst` | fst | `{fst}` | Fast columnar format |
| `.json` | json | `{jsonlite}` | JSON format |
| `.parquet` | parquet | `{nanoparquet}` | Columnar format |

**Important**: `.qs2` requires `{qs2}`. If you attempt to save or load a `.qs2` file without `{qs2}` installed, `stamp` aborts with a clear error message.

> **Unrecognized extensions** fall back to the `default_format` option (`"qs2"`) rather than raising an error, so pass `format =` explicitly whenever the extension is not one of those listed above.

### Installing Format Packages

```r
# For qs2 format support
install.packages("qs2")

# For fst format support
install.packages("fst")
```

### Format Selection

`stamp` infers format from file extension by default:

```r
# Uses qs2 format (requires {qs2})
st_save(data, "output.qs2")

# Uses RDS (base R, always available)
st_save(data, "output.rds")
```

You can also specify format explicitly:

```r
st_save(data, "output", format = "qs2")
```

## Core Functions

The functions below are organized by workflow. **New users** should start with *Initialization*, *Save & Load*, and *Versioning* sections. Advanced features like lineage tracking and aliases are covered in the [vignettes](#learn-more).

### Initialization & Configuration

- **`st_init(root)`** - Initialize stamp in a directory, creating the `.stamp/` state folder
- **`st_opts()`** - Get or set package options (versioning mode, retention policies, metadata format)
- **`st_opts_get(key = NULL)`** - Read a single option, or all of them when `key` is `NULL`
- **`st_opts_reset()`** - Reset all options to defaults

### Save & Load

- **`st_save(x, path, ...)`** - Save an artifact with automatic versioning, metadata, and lineage tracking
  - Optional: `pk` (primary key), `parents` (lineage), `code` (provenance), `domain` (category), `alias` (target directory)
- **`st_load(path, ...)`** - Load the latest version of an artifact
  - Optional: `verify = TRUE` (check content hash), `alias` (source directory)
- **`st_load_version(path, version_id)`** - Load a specific historical version by ID

### Formats

- **`st_formats()`** - List the registered format handlers (`csv`, `fst`, `json`, `parquet`, `qs2`, `rds`)
- **`st_register_format(name, read, write, extensions = NULL)`** - Register or override a format handler, optionally mapping file extensions to it

### Versioning & History

- **`st_versions(path)`** - List all versions of an artifact with metadata (timestamp, size, hashes)
- **`st_latest(path)`** - Get the version ID of the most recent version
- **`st_changed(x, path)`** - Check if an object differs from the saved version
- **`st_changed_reason(x, path)`** - Explain why content/code changed
- **`st_should_save(x, path)`** - Determine whether saving would create a new version
- **`st_restore(file, version = "oldest", ...)`** - Restore an artifact to a previous version, writing it back as the current one

### Lineage & Dependencies

- **`st_lineage(path, depth = 1)`** - Show parent artifacts (inputs) for a given artifact
- **`st_children(path, depth = 1)`** - Show child artifacts (outputs) that depend on this artifact
- **`st_is_stale(path)`** - Check if an artifact needs rebuilding because parents changed

### Catalog Queries

- **`st_catalog_query(alias = NULL)`** - Return a `data.table` with the latest version metadata for every artifact in a catalog — one row per artifact (`path`, `version_id`, `content_hash`, `code_hash`, `size_bytes`, `created_at`). Useful for downstream consumers that need a snapshot of all tracked artifacts without iterating over individual paths.

### Metadata & Inspection

- **`st_info(path)`** - Get comprehensive artifact information (sidecar, catalog, snapshot location, parents)
- **`st_read_sidecar(path)`** - Read sidecar metadata (hashes, timestamps, primary keys, domain, parents)
- **`st_hash_obj(x)`** - Compute stable hash for any R object

### Primary Keys

- **`st_add_pk(path, keys)`** - Add or update primary key definition for an artifact
- **`st_get_pk(x_or_meta)`** - Retrieve primary key columns from metadata
- **`st_inspect_pk(path)`** - Validate primary key uniqueness and coverage
- **`st_pk(x = NULL, keys, ...)`** - Normalize a primary-key specification, optionally validating it against `x`
- **`st_with_pk(x, keys)`** - Attach primary-key metadata to a data.frame in memory, without saving

### Pruning Data

- **`st_prune_versions(path, policy)`** - Remove old versions based on retention policy

### Aliases (Multi-Directory Support)

- **`st_alias_list()`** - List all registered aliases
- **`st_alias_get(name = NULL)`** - Get configuration for an alias
- **`st_switch(alias)`** - Switch the session's default alias

### Builders & Rebuilds ⚠️ *Experimental*

> **Note**: The builder system is under active development. Safe for prototyping, but consider pinning your stamp version in production code until the API stabilizes (expected in v1.0).

- **`st_register_builder(path, builder_fn)`** - Register a function to rebuild an artifact from its parents
- **`st_clear_builders(paths = NULL)`** - Clear registered builders
- **`st_builders()`** - List the currently registered builders
- **`st_plan_rebuild(targets, ...)`** - Compute rebuild plan (which targets are stale and why)
- **`st_rebuild(plan)`** - Execute a rebuild plan, calling builders and saving results

### Filtering Helpers ⚠️ *Experimental*

> **Note**: Advanced filtering utilities are under development.

- **`st_filter(df, filters = list(), strict = TRUE)`** - Apply named list filters to data frames

## Learn More

For detailed guides and workflows, see the package vignettes:

- **[Setup and Basics](https://randrescastaneda.github.io/stamp/articles/setup-and-basics.html)** - Getting started with stamp
- **[Hashing and Versions](https://randrescastaneda.github.io/stamp/articles/hashing-and-versions.html)** - Understanding content hashing and version control
- **[Using Aliases](https://randrescastaneda.github.io/stamp/articles/using-alias.html)** - Managing multiple stamp directories
- **[Lineage and Rebuilds](https://randrescastaneda.github.io/stamp/articles/lineage-rebuilds.html)** - Dependency tracking and automated rebuilds
- **[Version Retention](https://randrescastaneda.github.io/stamp/articles/version_retention_prune.html)** - Managing version history with retention policies
- **[Stamp Directory](https://randrescastaneda.github.io/stamp/articles/stamp-directory.html)** - Understanding the `.stamp/` internal structure


