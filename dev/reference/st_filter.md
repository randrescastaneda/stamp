# Filter a data.frame by primary-key values (or arbitrary columns)

Convenience helper to subset a data.frame by a set of named values. The
`filters` argument is a named list mapping column names to allowed
values (vector). When `strict = TRUE`, unknown filter columns raise an
error.

## Usage

``` r
st_filter(df, filters = list(), strict = TRUE)
```

## Arguments

- df:

  A data.frame to filter.

- filters:

  Named list of filtering values, e.g. `list(country = "PER")`.

- strict:

  Logical; when `TRUE` unknown filter columns cause an error.

## Value

A subsetted data.frame (same columns as `df`).
