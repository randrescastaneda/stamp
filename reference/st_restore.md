# Restore artifact to a previous version

Replaces the current artifact file with a specified historical version.
This is a convenience wrapper around
[`st_load_version`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md)
and
[`st_save`](https://randrescastaneda.github.io/stamp/reference/st_save.md)
that restores an artifact in-place.

## Usage

``` r
st_restore(file, version = "oldest", verbose = TRUE, alias = NULL, ...)
```

## Arguments

- file:

  Character path to the artifact to restore. Can be:

  - Bare filename (e.g., "data.qs2") - stored in /data.qs2/

  - Relative path with subdirs (e.g., "results/model.rds") - stored in
    /results/model.rds/

  - Absolute path under project root - converted to relative for
    versioning

- version:

  Version identifier to restore to. Can be:

  - A specific version_id string

  - "latest" - most recent version

  - "oldest" - first saved version

  - Integer offset from latest (1 = previous, 2 = two versions back,
    etc.)

- verbose:

  Logical; if TRUE, prints informative messages.

- alias:

  Optional stamp alias to target a specific stamp folder.

- ...:

  Additional arguments passed to format reader/writer.

## Value

Invisibly returns the restored object.

## Details

The function:

1.  Loads the specified version from version history

2.  Overwrites the current artifact file with that version

3.  Creates a new version entry for the restoration

This allows you to revert changes by restoring to any previous version.
The restoration itself becomes a new version in the history, so you can
always go forward again if needed.

## See also

[`st_load_version`](https://randrescastaneda.github.io/stamp/reference/st_load_version.md),
[`st_versions`](https://randrescastaneda.github.io/stamp/reference/st_versions.md),
[`st_save`](https://randrescastaneda.github.io/stamp/reference/st_save.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Initialize and create some versions
st_init()
df1 <- data.frame(x = 1:5)
st_save(df1, "data.qs2")

df2 <- data.frame(x = 6:10)
st_save(df2, "data.qs2")

# Restore to previous version
st_restore("data.qs2", version = "oldest")

# Or restore to a specific version ID
versions <- st_versions("data.qs2")
st_restore("data.qs2", version = versions$version_id[1])
} # }
```
