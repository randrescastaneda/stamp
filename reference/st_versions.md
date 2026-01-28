# List versions for an artifact path

Return a table of recorded versions for the artifact identified by
`path` from the catalog. When `data.table` is available the result is a
`data.table`; otherwise a base `data.frame` is returned. The table
contains one row per recorded version with the columns described below.
Rows are ordered by `created_at` descending.

## Usage

``` r
st_versions(path, alias = NULL)
```

## Arguments

- path:

  file or directory path

- alias:

  Optional stamp alias to target a specific stamp folder.

## Value

A `data.frame` or `data.table` with columns:

- version_id:

  Character version identifier.

- artifact_id:

  Character artifact identifier (hashed).

- content_hash:

  Character content hash for the version (may be NA).

- code_hash:

  Character code hash for the version (may be NA).

- size_bytes:

  Numeric size of the stored artifact in bytes.

- created_at:

  Character ISO8601 timestamp when the version was recorded.

- sidecar_format:

  Character sidecar format present: "json", "qs2", "both", or "none".

An empty table is returned when no versions exist for the given path.
