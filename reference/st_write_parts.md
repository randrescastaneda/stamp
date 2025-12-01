# Auto-partition and save a dataset (Hive-style)

Splits a data.frame/data.table by partition columns and saves each
partition to a separate file using Hive-style directory structure.
Eliminates manual looping and splitting logic.

## Usage

``` r
st_write_parts(
  x,
  base,
  partitioning,
  code = NULL,
  parents = NULL,
  code_label = NULL,
  format = NULL,
  pk = NULL,
  domain = NULL,
  unique = TRUE,
  .progress = NULL,
  ...
)
```

## Arguments

- x:

  Data.frame or data.table to partition and save

- base:

  Base directory for partitions (e.g., "data/welfare_parts")

- partitioning:

  Character vector of column names to partition by (e.g., c("country",
  "year", "reporting_level"))

- code, parents, code_label, format, ...:

  Passed to st_save() for each partition

- pk:

  Optional primary key columns (passed to st_save())

- domain:

  Optional domain label(s) (passed to st_save())

- unique:

  Logical; enforce PK uniqueness at save time (default TRUE)

- .progress:

  Logical; show progress bar for partitions (default TRUE for \>10
  parts)

## Value

Invisibly, a data.frame with columns:

- partition_key: list-column of key values

- path: file path

- version_id: version identifier

- n_rows: number of rows in partition

## Performance

For large datasets with many partitions, this function uses data.table's
split for efficiency when available. Progress reporting can be disabled
with `.progress = FALSE`.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create sample data
welfare <- data.frame(
  country = rep(c("USA", "CAN"), each = 100),
  year = rep(2020:2021, each = 50),
  reporting_level = sample(c("national", "urban"), 200, replace = TRUE),
  value = rnorm(200)
)

# Auto-partition and save
st_write_parts(
  welfare,
  base = "data/welfare_parts",
  partitioning = c("country", "year", "reporting_level"),
  code_label = "welfare_partition"
)

# Result: files saved to:
#   data/welfare_parts/country=USA/year=2020/reporting_level=national/part.qs2
#   data/welfare_parts/country=USA/year=2020/reporting_level=urban/part.qs2
#   ... etc
} # }
```
