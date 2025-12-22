# Internal format handlers for stamp

Write `x` to `path` using `qs2` APIs. Errors if the .pkg qs2 package is
not installed or required entrypoints are unavailable.

Read an object from `path` using `qs2` APIs. Errors if the .pkg qs2
package is not installed or required entrypoints are unavailable.

## Usage

``` r
.st_write_qs2(x, path, ...)

.st_read_qs2(path, ...)
```

## Arguments

- x:

  R object to save.

- path:

  Destination file path.

- ...:

  Additional arguments passed to the underlying writer/reader.

## Value

Invisibly returns what the underlying writer returns.

The R object read from `path`.
