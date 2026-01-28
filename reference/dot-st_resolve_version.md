# Resolve version specification to a concrete version_id (internal)

Resolve version specification to a concrete version_id (internal)

## Usage

``` r
.st_resolve_version(path, version = NULL, alias = NULL)
```

## Arguments

- path:

  artifact path

- version:

  NULL (latest), integer (relative), character (specific version ID), or
  "select"/"pick"/"choose" to show interactive menu

## Value

character version_id or NA_character\_
