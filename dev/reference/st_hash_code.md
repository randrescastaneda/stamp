# Stable SipHash-1-3 of code

Computes a stable hash of R code (functions, expressions, or character
vectors). For functions, includes both formals (arguments) and body.
Whitespace is lightly normalized to reduce spurious differences. That
means code changes which only alter the number of spaces in strings
(e.g. "a b" vs "a b") will produce identical hashes.

## Usage

``` r
st_hash_code(code)
```

## Arguments

- code:

  A function, expression (language object), or character vector

## Value

Lowercase hex string (16 hex characters) from siphash13().

## Normalization

The code undergoes light normalization before hashing:

- Multiple spaces/tabs collapsed to single space

- Line endings normalized to `\n`

- This reduces false positives from formatting changes while preserving
  code structure

## What Gets Hashed

- **Functions**: formals (argument list) + body (code)

- **Expressions/language**: deparsed code

- **Character vectors**: concatenated with newlines

## Examples

``` r
if (FALSE) { # \dontrun{
# Hash a function
st_hash_code(function(x) x + 1)

# Hash an expression
st_hash_code(quote(x + 1))

# Hash character code
st_hash_code("x <- 1\ny <- 2")
} # }
```
