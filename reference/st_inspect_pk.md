# Inspect primary-key of an artifact from its sidecar

Read the sidecar for `path` and return the recorded primary-key column
names. If no sidecar or pk information is present, returns
`character(0)`.

## Usage

``` r
st_inspect_pk(path)
```

## Arguments

- path:

  Path to the artifact file.

## Value

Character vector of primary-key column names (may be length 0).
