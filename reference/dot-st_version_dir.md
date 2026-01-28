# Version directory for an artifact (internal)

Compute the version directory path for a file. New structure:
\<data_folder\>/\<rel_path\>/versions/\<version_id\>

## Usage

``` r
.st_version_dir(rel_path, version_id, alias = NULL)
```

## Arguments

- rel_path:

  Relative path from alias root (includes filename).

- version_id:

  Version identifier (character).

- alias:

  Optional alias

## Value

Character scalar path to the version directory, or NA if version_id is
NA/empty.
