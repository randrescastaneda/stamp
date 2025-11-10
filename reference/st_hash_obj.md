# Stable SipHash-1-3 of an R object

Serializes the object with base::serialize(version = 3) and hashes the
raw bytes via secretbase::siphash13(). This is stable across sessions
(given the same R version and object structure) and suitable for change
detection.

## Usage

``` r
st_hash_obj(x)
```

## Arguments

- x:

  Any R object.

## Value

Lowercase hex string (16 hex chars) from siphash13().
