# List available partitions under a base directory

List available partitions under a base directory

## Usage

``` r
st_list_parts(base, filter = NULL, recursive = TRUE)
```

## Arguments

- base:

  Base dir

- filter:

  Named list to restrict partitions (exact match on key fields)

- recursive:

  Logical; search subdirs (default TRUE)

## Value

A data.frame with columns: path plus one column per partition key
