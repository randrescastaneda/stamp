# Show immediate or recursive parents for an artifact

Show immediate or recursive parents for an artifact

## Usage

``` r
st_lineage(path, depth = 1L, alias = NULL)
```

## Arguments

- path:

  Artifact path (child)

- depth:

  Integer depth \>= 1. Use Inf to walk recursively.

- alias:

  Optional stamp alias to target a specific stamp folder.

## Value

data.frame with columns: level, child_path, child_version, parent_path,
parent_version
