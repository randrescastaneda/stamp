# Version directory for an artifact (internal)

Compute the version directory path for `artifact_path` and `version_id`
under /\<state_dir\>/versions. We store snapshots under the *relative*
artifact path from root; if the artifact is outside the root, we fall
back to a collision-free identifier based on the artifact's unique ID.

## Usage

``` r
.st_version_dir(artifact_path, version_id)
```

## Arguments

- artifact_path:

  Path to the artifact file.

- version_id:

  Version identifier (character).

## Value

Character scalar path to the version directory, or NA if version_id is
NA/empty.
