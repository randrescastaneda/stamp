# Read parents metadata for a version (internal)

Read and return the parents metadata stored in `parents.json` inside the
given `version_dir`. If no parents file exists an empty list is
returned.

## Usage

``` r
.st_version_read_parents(version_dir)
```

## Arguments

- version_dir:

  Path to the version directory.

## Value

List of parent descriptors, or an empty list.
