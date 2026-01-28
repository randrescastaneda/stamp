# Resolve file path and create st_path object (internal)

Resolve file path and create st_path object (internal)

## Usage

``` r
.st_resolve_and_normalize(file, format = NULL, alias = NULL, verbose = TRUE)
```

## Arguments

- file:

  character path or st_path object

- format:

  optional format override

- alias:

  character alias or NULL

- verbose:

  logical; if TRUE, emit warnings

## Value

list(sp = st_path object, resolved_path, alias_used, was_bare, rel_path)
