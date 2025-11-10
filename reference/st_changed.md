# Check whether an artifact would change if saved now

Compares the *current* object/code/file to the latest saved metadata
(from the sidecar) and reports if a change is detected.

## Usage

``` r
st_changed(
  path,
  x = NULL,
  code = NULL,
  mode = c("any", "content", "code", "file")
)
```

## Arguments

- path:

  Artifact path on disk.

- x:

  Current in-memory object (for content comparison).

- code:

  Optional function/expression/character (for code comparison).

- mode:

  Which changes to check: "content", "code", "file", or "any".

## Value

A list: list(changed = , reason = , detail = )
