# Read sidecar metadata (internal)

Read the sidecar metadata for a file if it exists, returning `NULL` when
no sidecar file is present. Preference order is JSON first, then QS2.

## Usage

``` r
st_read_sidecar(rel_path, alias = NULL)
```

## Arguments

- rel_path:

  Character relative path from alias root, or an absolute path. If an
  absolute path is provided, it will be normalized to a relative path.

- alias:

  Optional alias. If `NULL` and an absolute path is provided, the alias
  will be auto-detected from the path.

## Value

A list (parsed JSON / qs object) or `NULL` if not found.
