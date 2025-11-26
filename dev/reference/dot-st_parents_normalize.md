# Normalize parents structure (internal)

Ensure the `parents` object has the canonical shape: a list of lists
each containing `path` and `version_id`. Accepts data.frames, singleton
lists, or list-of-lists.

## Usage

``` r
.st_parents_normalize(parents)
```

## Arguments

- parents:

  Object representing parents (data.frame, list, etc.)

## Value

A list of parent descriptors (each a list with `path` and `version_id`).
