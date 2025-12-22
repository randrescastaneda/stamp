# stamp

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
#>   root: C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS
#>   state: C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/.stamp

p <- fs::path(root, "demo.qs")
x <- data.frame(id = 1:3, val = letters[1:3])

st_save(x, p, pk = "id", code = function(z) z)
#> ✔ Saved [qs] → 'C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/demo.qs' @
#>   version 9f17a32f99df9990
y <- st_load(p)
#> ✔ Loaded [qs] ← 'C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/demo.qs'
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash        code_hash
#>              <char>           <char>           <char>           <char>
#> 1: 9f17a32f99df9990 526fcbc6552f1098 cdbe771e53841cf7 488e8fa49c740261
#>    size_bytes                  created_at sidecar_format
#>         <num>                      <char>         <char>
#> 1:        170 2025-12-22T10:40:28.932216Z           json

# Retention
st_opts(retain_versions = 2)
#> ✔ stamp options updated
#>   retain_versions = "2"
st_save(transform(x, val = toupper(val)), p, code = function(z) z)
#> ✔ Retention policy matched zero versions; nothing to prune.
#> ✔ Saved [qs] → 'C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/demo.qs' @
#>   version 68b91238470c74fc
vrs <- st_versions(p)
head(vrs)
#>          version_id      artifact_id     content_hash        code_hash
#>              <char>           <char>           <char>           <char>
#> 1: 68b91238470c74fc 526fcbc6552f1098 d2b54b7e265bb11f 488e8fa49c740261
#> 2: 9f17a32f99df9990 526fcbc6552f1098 cdbe771e53841cf7 488e8fa49c740261
#>    size_bytes                  created_at sidecar_format
#>         <num>                      <char>         <char>
#> 1:        149 2025-12-22T10:40:29.104312Z           json
#> 2:        170 2025-12-22T10:40:28.932216Z           json

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
#>   'C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/inputs/country_year/country=PER/year=2023/part.qs2'
#>   @ version 2201f3bf291ca2f2
st_list_parts(base)
#>                                                                                                   path
#> 1 C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/inputs/country_year/country=PER/year=2023/part.qs2
#>   country year
#> 1     PER 2023
st_load_parts(base, as = "rbind")
#> ✔ Loaded [qs2] ←
#>   'C:/Users/wb535623/AppData/Local/Temp/5/Rtmps9BVCS/inputs/country_year/country=PER/year=2023/part.qs2'
#>   country year  pop
#> 1     PER 2023 34.5
```

## File Formats

`stamp` supports multiple serialization formats. The two binary formats
have distinct implementations:

| Extension | Format | Package Required                                   | Notes                                                |
|-----------|--------|----------------------------------------------------|------------------------------------------------------|
| `.qs2`    | qs2    | [qs2](https://github.com/qsbase/qs2)               | New qs2 binary format (recommended for new projects) |
| `.qs`     | qs     | [qs](https://github.com/qsbase/qs)                 | Legacy qs binary format                              |
| `.rds`    | rds    | (base R)                                           | R serialized format                                  |
| `.csv`    | csv    | [data.table](https://r-datatable.com)              | Comma-separated values                               |
| `.fst`    | fst    | [fst](http://www.fstpackage.org)                   | Fast columnar format                                 |
| `.json`   | json   | [jsonlite](https://jeroen.r-universe.dev/jsonlite) | JSON format                                          |

**Important**: `.qs` and `.qs2` are **different formats** and require
their respective packages. There is no automatic fallback between them.
If you attempt to save/load a `.qs2` file without
[qs2](https://github.com/qsbase/qs2) installed, `stamp` will abort with
a clear error message.

### Installing Format Packages

``` r
# For qs2 format support
install.packages("qs2")

# For legacy qs format support
install.packages("qs")

# For fst format support
install.packages("fst")
```

### Format Selection

`stamp` infers format from file extension by default:

``` r
# Uses qs2 format (requires {qs2})
st_save(data, "output.qs2")

# Uses qs format (requires {qs})
st_save(data, "output.qs")

# Uses RDS (base R, always available)
st_save(data, "output.rds")
```

You can also specify format explicitly:

``` r
st_save(data, "output", format = "qs2")
```

Why stamp? Sidecars: hashes, provenance, PKs.

Retention: keep latest N and/or recent days.

Partitions: Hive-style directories, easy bind & filter.

See vignettes for retention + partition details.
