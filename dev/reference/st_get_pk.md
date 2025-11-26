# Read primary-key keys from a data.frame or sidecar/meta list

Extract the primary-key column names from either an in-memory data.frame
(via the `stamp_pk` attribute) or from a sidecar/meta list (a previously
recorded `pk` element). Returns an empty character vector when none is
found.

## Usage

``` r
st_get_pk(x_or_meta)
```

## Arguments

- x_or_meta:

  Either a data.frame (with attribute `stamp_pk`) or a sidecar/meta list
  as returned by
  [`st_read_sidecar()`](https://randrescastaneda.github.io/stamp/dev/reference/st_read_sidecar.md).

## Value

Character vector of primary-key column names (may be length 0).
