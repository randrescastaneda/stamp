# Get or set package options

- **Setter**: `st_opts(meta_format = "both", versioning = "timestamp")`

- **Getter**: `st_opts(.get = TRUE)` returns a named list of all options

- **Single getter**: `st_opts("meta_format", .get = TRUE)` returns one
  value

## Usage

``` r
st_opts(..., .get = FALSE)
```

## Arguments

- ...:

  Named pairs for setting options; or a single character key when
  `.get = TRUE`.

- .get:

  Logical. If `TRUE`, performs a read instead of a write.

## Value

For setters, `invisible(NULL)`. For getters, the requested value(s).

## Details

Valid keys (defined in `.stamp_default_opts` in `R/aaa.R`):
`meta_format`, `versioning`, `force_on_code_change`, `retain_versions`,
`code_hash`, `store_file_hash`, `verify_on_load`, `default_format`,
`verbose`, `timezone`, `timeformat`, `usetz`, `require_pk_on_load`,
`warn_missing_pk_on_load`.

For a single authoritative source of truth, see `.stamp_default_opts` in
`R/aaa.R`; changes to that object determine the set of supported keys.

## See also

[`st_opts_reset()`](https://randrescastaneda.github.io/stamp/reference/st_opts_reset.md),
`.stamp_default_opts`
