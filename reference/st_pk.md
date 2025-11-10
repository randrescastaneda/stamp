# Normalize a primary-key specification

Normalize and validate a primary-key (pk) specification. The canonical
representation is a list with element `keys` containing a character
vector of column names. When `x` (a data.frame) is provided and
`validate = TRUE` the function will check that the columns exist (and
optionally that they uniquely identify rows).

## Usage

``` r
st_pk(x = NULL, keys, validate = TRUE, check_unique = FALSE)
```

## Arguments

- x:

  Optional data.frame to validate the keys against. If `NULL`, only the
  `keys` vector is normalized.

- keys:

  Character vector of column names comprising the primary key.

- validate:

  Logical; when `TRUE` validate that columns exist (and uniqueness if
  `check_unique` is `TRUE`).

- check_unique:

  Logical; when `TRUE` assert that `keys` uniquely identify rows in `x`
  (only checked when `x` is provided).

## Value

A list with element `keys` containing the canonical character vector.
