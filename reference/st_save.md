# Save an R object to disk with metadata & versioning (atomic move)

Save an R object to disk with metadata & versioning (atomic move)

## Usage

``` r
st_save(
  x,
  file,
  format = NULL,
  metadata = list(),
  code = NULL,
  parents = NULL,
  code_label = NULL,
  pk = NULL,
  domain = NULL,
  unique = TRUE,
  verbose = TRUE,
  ...
)
```

## Arguments

- x:

  object to save

- file:

  destination path (character or st_path)

- format:

  optional format override ("qs2" \| "rds" \| "csv" \| "fst" \| "json")

- metadata:

  named list of extra metadata (merged into sidecar)

- code:

  Optional function/expression/character whose hash is stored as
  `code_hash`.

- parents:

  Optional list of parent descriptors: list(list(path = "", version_id =
  ""), ...).

- code_label:

  Optional short label/description of the producing code (for humans).

- pk:

  optional character vector of primary-key columns (for tables)

- domain:

  optional character scalar or vector label(s) for the dataset

- unique:

  logical; enforce uniqueness of pk at save time (default TRUE)

- verbose:

  logical; if `FALSE`, suppress informational messages and
  package-generated warnings (default TRUE). When `FALSE`, messages
  about skipped saves or save failures emitted by `st_save()` will not
  be shown.

- ...:

  forwarded to format writer

## Value

invisibly, a list with path, metadata, and version_id (or skipped=TRUE)
