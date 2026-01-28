# Check whether an artifact would change if saved now

Compares the *current* object/code/file to the latest saved metadata
(from the sidecar) and reports if a change is detected.

## Usage

``` r
st_changed(
  path,
  x = NULL,
  code = NULL,
  mode = c("any", "content", "code", "file"),
  alias = NULL
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

- alias:

  Optional character alias to identify this stamp folder. If `NULL`,
  uses "default" for backwards compatibility.

## Value

A list: list(changed = , reason = , detail = )
