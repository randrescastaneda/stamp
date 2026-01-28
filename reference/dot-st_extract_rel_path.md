# Extract relative path from an absolute path (internal)

Given an absolute path under alias root, extract the relative path
component.

## Usage

``` r
.st_extract_rel_path(abs_path, alias = NULL)
```

## Arguments

- abs_path:

  Character absolute path

- alias:

  Optional alias

## Value

Character relative path from root, or NULL if path not under root

## Details

Structure: /\<rel_path\>/ or /\<rel_path\>/stmeta/... or
/\<rel_path\>/versions/...
