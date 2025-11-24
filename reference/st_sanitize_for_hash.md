# Sanitize object prior to hashing

For tabular data we want hashing to depend only on the data/frame
content, not on volatile data.table internals (e.g. `.internal.selfref`)
or differing row name representations. Strategy:

- If `x` is a data.table: coerce to plain data.frame (drops DT
  internals).

- If `x` is a data.frame (including coerced DT): enforce deterministic
  row.names via `.set_row_names(NROW(x))`.

- Record original class in `st_original_format` so a loader can restore
  it.

## Usage

``` r
st_sanitize_for_hash(x)
```

## Details

Non-tabular objects are returned unchanged (attribute normalization
handles them subsequently).

NOTE: The returned object is a shallow copy; column data is not
duplicated.
