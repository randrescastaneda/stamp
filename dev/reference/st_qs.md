# saving in qs2 format in stamps

Attempts to write `x` to `path` using
[`qs2::qs_save()`](https://rdrr.io/pkg/qs2/man/qs_save.html) or
`qs2::qsave()` when available, otherwise falls back to
[`qs::qsave()`](https://rdrr.io/pkg/qs/man/qsave.html). Errors if
neither package is installed.

Reads an object from `path` using
[`qs2::qs_read()`](https://rdrr.io/pkg/qs2/man/qs_read.html) or
`qs2::qread()` when available, otherwise falls back to
[`qs::qread()`](https://rdrr.io/pkg/qs/man/qread.html). Errors if
neither package is installed.

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

  Additional arguments passed to the underlying writer.

## Value

Invisibly returns what the underlying writer returns.

The R object read from `path`.
