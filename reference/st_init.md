# Initialize stamp project structure

Initialize a stamp folder under `root` using `state_dir` and optionally
register it under an `alias`. Aliases allow multiple independent stamp
folders to be managed in a single R session without changing any on-disk
path structures.

## Usage

``` r
st_init(root = ".", state_dir = ".stamp", alias = NULL, verbose = TRUE)
```

## Arguments

- root:

  project root (default ".")

- state_dir:

  directory name for internal state (default ".stamp")

- alias:

  Optional character alias to identify this stamp folder. If `NULL`,
  uses "default" for backwards compatibility.

- verbose:

  logical; if `FALSE`, suppress informational messages and warnings
  (default `TRUE`). Errors are never suppressed.

## Value

(invisibly) the absolute state dir
