# Sidecar metadata path helper (internal)

Build the path to a sidecar metadata file for `path`. Sidecars live in a
sibling directory named `stmeta` next to the file's directory. The
returned filename has the original basename with a `.stmeta.<ext>`
suffix where `ext` is typically `"json"` or `"qs2"`.

## Usage

``` r
.st_sidecar_path(path, ext = c("json", "qs2"))
```

## Arguments

- path:

  Character scalar path to the main data file.

- ext:

  Character scalar extension for the sidecar (e.g. "json" or "qs2").

## Value

Character scalar with the computed sidecar path.
