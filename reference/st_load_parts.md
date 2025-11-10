# Load and row-bind partitioned data

Load and row-bind partitioned data

## Usage

``` r
st_load_parts(base, filter = NULL, as = c("rbind", "dt"))
```

## Arguments

- base:

  Base dir

- filter:

  Named list to restrict partitions (exact match)

- as:

  Data frame binding mode: "rbind" (base) or "dt" (data.table if
  available)

## Value

Data frame with unioned columns and extra columns for the key fields
