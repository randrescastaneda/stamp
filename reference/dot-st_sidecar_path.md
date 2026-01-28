# Sidecar metadata path helper (internal)

Build the path to a sidecar metadata file for a given relative path. New
structure: \<data_folder\>/\<rel_path\>/stmeta/.stmeta.

## Usage

``` r
.st_sidecar_path(rel_path, ext = c("json", "qs2"), alias = NULL)
```

## Arguments

- rel_path:

  Character relative path from alias root (includes filename).

- ext:

  Character scalar extension for the sidecar (e.g. "json" or "qs2").

- alias:

  Optional alias

## Value

Character scalar with the computed sidecar path.
