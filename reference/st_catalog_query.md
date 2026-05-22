# Query latest version metadata for all artifacts in an alias

Return a `data.table` with one row per artifact in the catalog,
containing the metadata for that artifact's most recent version only.
This provides a snapshot of the current state of all tracked artifacts
without having to iterate over individual artifact paths.

## Usage

``` r
st_catalog_query(alias = NULL)
```

## Arguments

- alias:

  Character scalar. Stamp alias to query. `NULL` (default) uses the
  default alias.

## Value

A `data.table` with one row per artifact and columns:

- path:

  Absolute path to the artifact file.

- version_id:

  Latest version identifier for this artifact.

- content_hash:

  Content hash of the latest version (may be `NA`).

- code_hash:

  Code hash of the latest version (may be `NA`).

- size_bytes:

  Size in bytes of the latest version artifact.

- created_at:

  ISO8601 timestamp when the latest version was recorded.

An empty `data.table` with the same schema is returned when the catalog
has no artifacts.

## Details

Unlike
[`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md),
which returns all historical versions for a single artifact,
`st_catalog_query()` returns exactly one row per artifact — the latest
version — across the entire alias catalog.

## See also

[`st_versions()`](https://randrescastaneda.github.io/stamp/reference/st_versions.md)
to query all versions for a single artifact.

## Examples

``` r
if (FALSE) { # \dontrun{
# Query all latest versions in a named alias
latest <- st_catalog_query(alias = "my_project")
nrow(latest)  # one row per artifact

# Use default alias
latest <- st_catalog_query()
} # }
```
