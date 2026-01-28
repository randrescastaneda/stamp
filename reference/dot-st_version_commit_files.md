# Commit artifact and sidecars into a version snapshot (internal)

Copy the artifact file, any sidecars, and write the parents snapshot
into the version directory for the given `version_id`.

## Usage

``` r
.st_version_commit_files(rel_path, version_id, parents = NULL, alias = NULL)
```

## Arguments

- rel_path:

  Relative path from alias root (includes filename).

- version_id:

  Version identifier for the snapshot.

- parents:

  Optional list of parent descriptors to write into parents.json.

- alias:

  Optional alias.

## Value

Invisibly returns the version directory path.
