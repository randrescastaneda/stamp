# List children (reverse lineage) of an artifact (internal helper)

Internal helper that finds immediate children that list `path` as a
parent in their committed parents.json snapshots. Returned columns:
child_path, child_version, parent_path, parent_version.

## Usage

``` r
.st_children_once(path, version_id = NULL)
```

## Arguments

- path:

  Character path to the parent artifact.

- version_id:

  Optional version id to match; if provided, only children listing that
  exact parent version are returned.

## Value

A data.frame of matching children (may be empty).
