# Compute version IDs to keep under a retention policy (internal)

Compute version IDs to keep under a retention policy (internal)

## Usage

``` r
.st_policy_keep_ids(vtab, pol)
```

## Arguments

- vtab:

  data.frame of versions **sorted newest → oldest**

- pol:

  normalized policy from `.st_normalize_policy()`
