# Compute artifact identifier (internal)

Derive an artifact identifier from `path` using a stable SipHash of the
normalized path. This identifier is used to group versions belonging to
the same logical artifact.

## Usage

``` r
.st_artifact_id(path)
```

## Arguments

- path:

  Character path to the artifact.

## Value

Character scalar identifier.
