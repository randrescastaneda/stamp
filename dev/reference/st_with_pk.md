# Attach primary-key metadata to a data.frame (in-memory)

Attach primary-key metadata to a data.frame by setting an attribute
`stamp_pk` with the normalized pk list returned by
[`st_pk()`](https://randrescastaneda.github.io/stamp/dev/reference/st_pk.md).
This does not modify on-disk sidecars; it is an in-memory convenience.

## Usage

``` r
st_with_pk(x, keys)
```

## Arguments

- x:

  Data.frame to annotate.

- keys:

  Character vector of column names making the primary key.

## Value

The input data.frame with attribute `stamp_pk` set.
