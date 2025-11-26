# Read catalog from disk (internal)

Read the persisted catalog from the on-disk catalog file. If the file
does not exist, an empty catalog template is returned.

## Usage

``` r
.st_catalog_read()
```

## Value

A list with elements `artifacts` and `versions`.
