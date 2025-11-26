# Register or override a format handler

Public function that allows users to register a new format handler or
override an existing one. Handlers must be functions with the expected
signatures documented below.

## Usage

``` r
st_register_format(name, read, write, extensions = NULL)
```

## Arguments

- name:

  Character scalar: format name (e.g. `"qs2"`, `"rds"`).

- read:

  Function `function(path, ...)` returning an R object.

- write:

  Function `function(object, path, ...)` that writes `object` to `path`.

- extensions:

  Optional character vector of file extensions (e.g. `c("qs","qs2")`) to
  map to this format; case-insensitive; without dots.

## Value

Invisibly returns `TRUE` on success.

## Examples

``` r
st_register_format(
  "txt",
  read  = function(p, ...) readLines(p, ...),
  write = function(x, p, ...) writeLines(x, p, ...),
  extensions = "txt"
)
#> ✔ Registered format txt
#>   extensions: .txt
```
