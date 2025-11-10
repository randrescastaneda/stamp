# Save a single partition (uses st_save under the hood)

Save a single partition (uses st_save under the hood)

## Usage

``` r
st_save_part(
  x,
  base,
  key,
  code = NULL,
  parents = NULL,
  code_label = NULL,
  format = NULL,
  ...
)
```

## Arguments

- x:

  Object to save

- base:

  Base dir for partitions

- key:

  Named list of scalar values (e.g., list(country="US", year=2025))

- code, parents, code_label, format, ...:

  Passed to st_save()

## Value

invisibly, list(path=..., version_id=...)
