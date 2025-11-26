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

  Partition filter. Supports three formats:

  - Named list for exact matching: `list(country = "USA", year = 2020)`

  - Formula with expression: `~ year > 2010` or
    `~ country == "COL" & year >= 2012`

  - NULL for no filtering (default)

- recursive:

  Logical; search subdirs (default TRUE)

## Value

A data.frame with columns: path plus one column per partition key

## Examples

``` r
if (FALSE) { # \dontrun{
# List all partitions
st_list_parts("data/parts")

# Exact match (backward compatible)
st_list_parts("data/parts", filter = list(country = "USA"))

# Expression-based (flexible)
st_list_parts("data/parts", filter = ~ year > 2010)
st_list_parts("data/parts", filter = ~ country == "COL" & year >= 2012)
} # }
```
