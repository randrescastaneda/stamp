# Ensure directory exists (idempotent)

Create `path` if it does not already exist. Intermediate directories are
created as needed.

## Usage

``` r
.st_dir_create(path)
```

## Arguments

- path:

  Character scalar path to a directory.

## Value

Invisibly returns `NULL`.
