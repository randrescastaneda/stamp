# Commit artifact and sidecars into a version snapshot (internal)

Copy the artifact file, any sidecars, and write the parents snapshot
into the version directory for the given `version_id`.

## Usage

``` r
.st_version_commit_files(artifact_path, version_id, parents = NULL)
```

## Arguments

- artifact_path:

  Path to the artifact file on disk.

- version_id:

  Version identifier for the snapshot.

- parents:

  Optional list of parent descriptors to write into parents.json.

## Value

Invisibly returns the version directory path.
