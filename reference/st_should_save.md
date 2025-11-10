# Decide if a save should proceed given current st_opts() Uses versioning policy and code-change rule.

Decide if a save should proceed given current st_opts() Uses versioning
policy and code-change rule.

## Usage

``` r
st_should_save(path, x = NULL, code = NULL)
```

## Arguments

- path:

  Artifact path on disk.

- x:

  Current in-memory object (for content comparison).

- code:

  Optional function/expression/character (for code comparison).

## Value

list(save = , reason = , latest_version_id = )
