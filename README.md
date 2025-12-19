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
#>   root: C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa
#>   state: C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/.stamp

p <- fs::path(root, "demo.qs")
x <- data.frame(id = 1:3, val = letters[1:3])

st_save(x, p, pk = "id", code = function(z) z)
#> ✔ Saved [qs2] → 'C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/demo.qs' @
#>   version 127affba57484657
y <- st_load(p)
#> ✔ Loaded [qs2] ← 'C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/demo.qs'
st_versions(p)
#>          version_id      artifact_id     content_hash        code_hash
#>              <char>           <char>           <char>           <char>
#> 1: 127affba57484657 e7350537ff428064 2ba92a4feeebbf98 f61faf5f16af2f9f
#>    size_bytes           created_at sidecar_format
#>         <num>               <char>         <char>
#> 1:        255 2025-11-06T22:43:15Z           json

# Retention
st_opts(retain_versions = 2)
#> ✔ stamp options updated
#>   retain_versions = "2"
st_save(transform(x, val = toupper(val)), p, code = function(z) z)
#> ✔ Retention policy matched zero versions; nothing to prune.
#> ✔ Saved [qs2] → 'C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/demo.qs' @
#>   version 66a5ca432fe09e5a
st_versions(p)
#>          version_id      artifact_id     content_hash        code_hash
#>              <char>           <char>           <char>           <char>
#> 1: 66a5ca432fe09e5a e7350537ff428064 ac6d1caaa0c15f0e f61faf5f16af2f9f
#> 2: 127affba57484657 e7350537ff428064 2ba92a4feeebbf98 f61faf5f16af2f9f
#>    size_bytes           created_at sidecar_format
#>         <num>               <char>         <char>
#> 1:        228 2025-11-06T22:43:16Z           json
#> 2:        255 2025-11-06T22:43:15Z           json

# Partitions
base <- fs::path(root, "inputs/country_year")
st_save_part(
  data.frame(country = "PER", year = 2023, pop = 34.5),
  base,
  key = list(country = "PER", year = 2023),
  pk = c("country", "year")
)
#> ✔ Retention policy matched zero versions; nothing to prune.
#> ✔ Saved [qs2] →
#>   'C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/inputs/country_year/country=PER/year=2023/part.qs2'
#>   @ version b79b777eef2607f4
st_list_parts(base)
#>                                                                                                 path
#> 1 C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/inputs/country_year/country=PER/year=2023/part.qs2
#>   country year
#> 1     PER 2023
st_load_parts(base, as = "rbind")
#> ✔ Loaded [qs2] ←
#>   'C:/Users/wb384996/AppData/Local/Temp/Rtmpama7Fa/inputs/country_year/country=PER/year=2023/part.qs2'
#>   country year  pop
#> 1     PER 2023 34.5
```

Why stamp? Sidecars: hashes, provenance, PKs.

Retention: keep latest N and/or recent days.

Partitions: Hive-style directories, easy bind & filter.

See vignettes for retention + partition details.

## File Formats

`stamp` supports multiple serialization formats. The two binary formats have distinct implementations:

| Extension | Format | Package Required | Notes |
|-----------|--------|------------------|-------|
| `.qs2` | qs2 | `{qs2}` | New qs2 binary format (recommended for new projects) |
| `.qs` | qs | `{qs}` | Legacy qs binary format |
| `.rds` | rds | (base R) | R serialized format |
| `.csv` | csv | `{data.table}` | Comma-separated values |
| `.fst` | fst | `{fst}` | Fast columnar format |
| `.json` | json | `{jsonlite}` | JSON format |

**Important**: `.qs` and `.qs2` are **different formats** and require their respective packages. There is no automatic fallback between them. If you attempt to save/load a `.qs2` file without `{qs2}` installed, `stamp` will abort with a clear error message.

### Installing Format Packages

```r
# For qs2 format support
install.packages("qs2")

# For legacy qs format support
install.packages("qs")

# For fst format support
install.packages("fst")
```

### Format Selection

`stamp` infers format from file extension by default:

```r
# Uses qs2 format (requires {qs2})
st_save(data, "output.qs2")

# Uses qs format (requires {qs})
st_save(data, "output.qs")

# Uses RDS (base R, always available)
st_save(data, "output.rds")
```

You can also specify format explicitly:

```r
st_save(data, "output", format = "qs2")
```
