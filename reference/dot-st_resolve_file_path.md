# Resolve file path using alias (internal)

Resolve file path using alias (internal)

## Usage

``` r
.st_resolve_file_path(file, alias = NULL, verbose = TRUE)
```

## Arguments

- file:

  character path (bare filename or path with directory)

- alias:

  character alias or NULL

- verbose:

  logical; if TRUE, emit warnings

## Value

list(path = resolved_path, alias_used = alias_name, was_bare = logical,
rel_path = relative_path_from_root)
