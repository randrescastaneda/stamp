# Stable SipHash-1-3 of an R object

Computes a stable hash of an R object by serializing it with
`base::serialize(version = 3)` and hashing the resulting bytes via
[`secretbase::siphash13()`](https://shikokuchuo.net/secretbase/reference/siphash13.html).
The hash is stable across R sessions (given the same R version and
object structure) and suitable for change detection.

## Usage

``` r
st_hash_obj(x)
```

## Arguments

- x:

  Any R object (data.frame, data.table, list, vector, etc.)

## Value

Lowercase hex string (16 hex characters) from siphash13().

## Attribute Normalization

Before hashing, this function normalizes the order of object attributes
to ensure consistent hashes even when operations (like
[`collapse::rowbind()`](https://fastverse.org/collapse/reference/rowbind.html) +
[`collapse::funique()`](https://fastverse.org/collapse/reference/funique.html))
leave attributes in different orders.

The normalization reorders attributes to a canonical form:

1.  Priority attributes: names, row.names, class, .internal.selfref

2.  Other attributes: alphabetically sorted

This ensures that logically identical objects produce identical hashes
regardless of their attribute creation history.

## Why This Matters

Without normalization, two data.frames that are
[`identical()`](https://rdrr.io/r/base/identical.html) can produce
different hashes if their internal attributes are in different orders.
This breaks change detection in stamp, causing false positives where
objects are incorrectly flagged as changed.

## Performance

- For small to medium objects: negligible overhead

- For large objects: creates a shallow copy (data is referenced, not
  duplicated)

- The normalization cost is typically \< 1% of total hashing time

## Examples

``` r
if (FALSE) { # \dontrun{
# Two ways to create the "same" data
dt_a <- data.table(x = 1:5)
dt_b <- data.table(x = 1:5) |> collapse::rowbind(data.table(x = 1:5)) |> collapse::funique()

# They're identical in content
identical(dt_a, dt_b)  # TRUE

# And now they hash the same too!
st_hash_obj(dt_a) == st_hash_obj(dt_b)  # TRUE
} # }
```
