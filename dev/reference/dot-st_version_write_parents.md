# Write parents metadata for a version (internal)

Persist the list of parent descriptors for a version as JSON inside the
version directory. The function performs an atomic write to avoid
partial files on disk.

## Usage

``` r
.st_version_write_parents(version_dir, parents)
```

## Arguments

- version_dir:

  Path to the version directory where parents.json will be written.

- parents:

  List of parent descriptors (each a list with `path` and `version_id`).

## Value

Invisibly `NULL`.
