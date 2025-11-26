# Load a specific version of an artifact

Load a previously committed snapshot for an artifact identified by
`path` and `version_id`. The artifact file for the requested version is
read from the version snapshot directory using the format-specific read
handler registered in the package. This is useful for inspecting or
restoring historical versions of artifacts.

## Usage

``` r
st_load_version(path, version_id, ...)
```

## Arguments

- path:

  Character path to the artifact (same value used with
  `st_save`/`st_load`).

- version_id:

  Character version identifier (as returned by `st_save` or present in
  the catalog).

- ...:

  Additional arguments forwarded to the format's read function (e.g.
  `read` options).

## Value

The object produced by the format-specific read handler (typically an R
object loaded from disk).

## Details

The function will abort if the requested version snapshot does not exist
or if there is no registered format handler for the artifact's format.

## Examples

``` r
if (FALSE) { # \dontrun{
# load a historical version of a dataset
old <- st_load_version("data/cleaned.rds", "20250101T000000Z-abcdef01")
} # }
```
