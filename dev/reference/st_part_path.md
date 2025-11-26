# Build a concrete partition path under a base directory

Build a concrete partition path under a base directory

## Usage

``` r
st_part_path(base, key, file = NULL, format = NULL)
```

## Arguments

- base:

  Character base directory (e.g., "data/users")

- key:

  Named list of scalar values, e.g. list(country="US", year=2025)

- file:

  Optional filename (default "part.")

- format:

  Optional format (qs2\|rds\|csv\|fst\|json); default = stamp option

## Value

Character file path to the partition artifact
