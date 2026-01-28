# Explain why an artifact would change

Explain why an artifact would change

## Usage

``` r
st_changed_reason(
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

  Optional stamp alias to target a specific stamp folder.

## Value

Character scalar: "no_change", "missing_artifact", "missing_meta", or
e.g. "content+code"
