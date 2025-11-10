# Empty catalog template (internal)

Create an empty catalog structure used when no catalog file exists on
disk. The structure contains `artifacts` and `versions` tables and will
use `data.table` if available, otherwise base `data.frame`.

## Usage

``` r
.st_catalog_empty()
```

## Value

A list with elements `artifacts` and `versions` (data.frame or
data.table).
