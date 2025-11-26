# Write catalog to disk (internal)

Persist the catalog list to disk using a QS2-backed format. The write is
performed atomically by writing to a temporary file in the same
directory and then moving it into place.

## Usage

``` r
.st_catalog_write(cat)
```

## Arguments

- cat:

  Catalog list to persist (with `artifacts` and `versions`).

## Value

Invisible path to the catalog file.
