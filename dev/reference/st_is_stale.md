# Is a child artifact stale because its parents advanced?

Inspect the committed parents.json for the latest snapshot of `path` and
determine whether any parent now has a different latest version id.

## Usage

``` r
st_is_stale(path)
```

## Arguments

- path:

  Character path to the artifact to inspect.

## Value

Logical scalar. `TRUE` if any parent advanced, otherwise `FALSE`.
