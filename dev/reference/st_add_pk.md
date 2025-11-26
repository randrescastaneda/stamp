# Add or repair primary-key metadata in an artifact sidecar

Update the artifact sidecar for `path` to include primary-key metadata
(`pk` element). The artifact file itself is not rewritten. By default
the function validates the provided keys against the current on-disk
artifact (and optionally checks uniqueness). Use `validate = FALSE` to
skip validation and perform a pure metadata update.

## Usage

``` r
st_add_pk(path, keys, validate = TRUE, check_unique = FALSE)
```

## Arguments

- path:

  Path to the artifact file whose sidecar will be updated.

- keys:

  Character vector of column names to set as the primary key.

- validate:

  Logical; when `TRUE` validate keys against the on-disk data.

- check_unique:

  Logical; when `TRUE` assert that the keys uniquely identify rows in
  the on-disk data (if `validate = TRUE`).

## Value

Invisibly returns the character vector of keys recorded.
