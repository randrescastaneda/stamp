# Retrieve the latest version row for an artifact (internal)

Return the latest version record (a single-row data.frame or data.table)
for the artifact identified by `path`. If no artifact or version exists,
`NULL` is returned.

## Usage

``` r
.st_catalog_latest_version_row(path)
```

## Arguments

- path:

  Path to the artifact.

## Value

A single-row `data.frame`/`data.table` with the version metadata, or
`NULL`.
