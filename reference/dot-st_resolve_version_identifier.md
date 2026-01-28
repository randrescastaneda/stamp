# Resolve a version identifier to a version_id (internal)

Helper function for st_restore() that handles multiple version
specification formats. Centralizes identifier resolution logic for
clarity and testability.

## Usage

``` r
.st_resolve_version_identifier(version, versions_df, file)
```

## Arguments

- version:

  Version to restore. Can be specified as:

  - Integer offset from latest (1 = current/latest, 2 = previous, 3 =
    two versions back, etc.)

  - Character string "latest" for the most recent version

  - Character string "oldest" for the first saved version

  - Version ID string from the version history

- versions_df:

  data.frame from st_versions() with version_id column

- file:

  Original file path for error messages

## Value

Character scalar version_id

## Note

When using integer offsets, version = 1 restores the current/latest
version, which is equivalent to specifying version = "latest". This
allows for consistent offset-based indexing where higher numbers
represent older versions.
