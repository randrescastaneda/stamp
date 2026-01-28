# Inspect an artifact's current status (sidecar + catalog + snapshot location)

Inspect an artifact's current status (sidecar + catalog + snapshot
location)

## Usage

``` r
st_info(path, alias = NULL)
```

## Arguments

- path:

  Artifact path

- alias:

  Optional stamp alias to target a specific stamp folder.

## Value

A named list with fields:

- sidecar: sidecar list (or NULL)

- catalog: list(latest_version_id, n_versions)

- snapshot_dir: absolute path to latest version dir (or NA)

- parents: list(...) parsed from latest version's parents.json (if any)
