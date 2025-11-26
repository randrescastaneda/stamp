# Register a builder for an artifact path

A "builder" knows how to (re)create an artifact. It will be called by
[`st_rebuild()`](https://randrescastaneda.github.io/stamp/dev/reference/st_rebuild.md)
as `fun(path, parents)` and must return a list:

      list(
        x = <object to save>,           # required
        format = NULL,                  # optional ("qs2", "rds", ...)
        metadata = list(),              # optional, merged into sidecar
        code = NULL,                    # optional (function/expr/character)
        code_label = NULL               # optional (short description)
      )

## Usage

``` r
st_register_builder(path, fun, name = NULL)
```

## Arguments

- path:

  Character path this builder produces (exact match).

- fun:

  Function with signature `function(path, parents)`.

- name:

  Optional label so you can register multiple builders per path.

## Value

Invisibly TRUE.
