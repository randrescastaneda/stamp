# Load and row-bind partitioned data

Load and row-bind partitioned data

## Usage

``` r
st_load_parts(base, filter = NULL, columns = NULL, as = c("rbind", "dt"))
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

- columns:

  Character vector of column names to load (optional). For parquet/fst
  formats, uses native column selection (fast, low memory). For other
  formats (qs/rds/csv), loads full object then subsets (with warning).

- as:

  Data frame binding mode: "rbind" (base) or "dt" (data.table)

## Value

Data frame with unioned columns and extra columns for the key fields

## Examples

``` r
if (FALSE) { # \dontrun{
# Load all partitions
st_load_parts("data/parts")

# Filter with exact match
st_load_parts("data/parts", filter = list(country = "USA"))

# Filter with expression
st_load_parts("data/parts", filter = ~ year > 2010)

# Combine filter + column selection
st_load_parts("data/parts", filter = ~ year > 2010, columns = c("value", "metric"))
} # }
```
