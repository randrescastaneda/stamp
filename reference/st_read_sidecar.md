# Read sidecar metadata (internal)

Read the sidecar metadata for `path` if it exists, returning `NULL` when
no sidecar file is present. Preference order is JSON first, then QS2.
When a QS2 variant is encountered the function will try `qs2` and fall
back to `qs`.

## Usage

``` r
st_read_sidecar(path)
```

## Arguments

- path:

  Character path of the data file whose sidecar will be read.

## Value

A list (parsed JSON / qs object) or `NULL` if not found.
