# Restore original object attributes after sanitization (internal)

Reverse the transformations applied by st_sanitize_for_hash() to return
the object to its original user-facing form. This includes:

- Restoring data.table class if it was a data.table originally

- Restoring original row.names if they were preserved

- Removing internal stamp attributes

## Usage

``` r
.st_restore_sanitized_object(res)
```

## Arguments

- res:

  Object to restore (typically just read from disk)

## Value

The restored object with original attributes
