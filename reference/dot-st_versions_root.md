# Versions root directory (internal, deprecated)

**DEPRECATED**: This function returns the old centralized versions
directory. In the current architecture, versions are stored per-artifact
in `<artifact_folder>/versions/` rather than in a central location.

For compatibility with old vignettes and examples, this still returns
`<root>/<state_dir>/versions`, but this location is no longer used for
storing new versions.

## Usage

``` r
.st_versions_root(alias = NULL)
```

## Value

Character scalar path to the (legacy) versions root directory.
