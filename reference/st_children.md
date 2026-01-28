# List children (reverse lineage) of an artifact

Finds artifacts that depend on `path` (i.e., that record it in their
`parents.json` snapshots). If `version_id` is given, matches only that
specific parent version; otherwise, any parent version of `path`.

## Usage

``` r
st_children(path, version_id = NULL, depth = 1L, alias = NULL)
```

## Arguments

- path:

  Character path to the parent artifact.

- version_id:

  Optional version id of `path` to match. Default: any.

- depth:

  Integer depth \>= 1. Use `Inf` to recurse fully.

- alias:

  Optional stamp alias to target a specific stamp folder.

## Value

`data.frame` with columns: `level`, `child_path`, `child_version`,
`parent_path`, `parent_version`.
