# Check if object has custom (non-default) row names (internal)

R's default row.names are integer sequences stored efficiently via
.set_row_names(). This helper checks if an object has custom row.names
(e.g., character names) that differ from the default representation.

## Usage

``` r
.st_has_custom_rownames(x)
```

## Arguments

- x:

  A data.frame or similar object

## Value

Logical: TRUE if custom row.names exist, FALSE otherwise
