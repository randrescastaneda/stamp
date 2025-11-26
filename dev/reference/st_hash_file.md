# SipHash-1-3 of a file (bytes on disk)

Computes a hash of a file's contents by reading the file as raw bytes
and hashing them via
[`secretbase::siphash13()`](https://shikokuchuo.net/secretbase/reference/siphash13.html).
This is faster than reading the file into R first because `secretbase`
can stream the file directly.

## Usage

``` r
st_hash_file(path)
```

## Arguments

- path:

  Character path to a file

## Value

Lowercase hex string (16 hex characters) from siphash13().

## Use Cases

- Detecting if an artifact file has been modified on disk

- Verifying file integrity across copies

- Checking if a file needs to be re-saved

## Note

This hashes the file's raw bytes, not its R representation. If you save
an R object with [`saveRDS()`](https://rdrr.io/r/base/readRDS.html), the
file hash will change even if the object content is the same (due to
timestamps, compression variation, etc.). Use
[`st_hash_obj()`](https://randrescastaneda.github.io/stamp/dev/reference/st_hash_obj.md)
for content-based hashing of R objects.

## Examples

``` r
if (FALSE) { # \dontrun{
# Hash a file
st_hash_file("data.csv")
} # }
```
