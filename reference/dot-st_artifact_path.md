# Compute the actual artifact path (internal)

Returns the path where the actual user file will be stored.

## Usage

``` r
.st_artifact_path(rel_path, alias = NULL)
```

## Arguments

- rel_path:

  Character relative path from alias root

- alias:

  Optional alias

## Value

Character scalar absolute path to the artifact file

## Details

Structure: /\<rel_path\>/

Examples:

- rel_path: "data.qs2" → artifact: /data.qs2/data.qs2

- rel_path: "dirA/file.qs" → artifact: /dirA/file.qs/file.qs
