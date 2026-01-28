# Universal path normalization and validation helper (internal)

This is the central helper that validates and normalizes any
user-provided path. It handles both relative and absolute paths,
validates absolute paths are under the alias root, and returns a
standardized structure that all other functions can use.

## Usage

``` r
.st_normalize_user_path(
  user_path,
  alias = NULL,
  must_exist = FALSE,
  verbose = TRUE,
  auto_switch = TRUE
)
```

## Arguments

- user_path:

  Character path provided by user (relative or absolute)

- alias:

  Optional alias; if NULL, uses "default"

- must_exist:

  Logical; if TRUE and user provided absolute path, verify it exists

## Value

List with components: logical_path, storage_path, rel_path, alias,
is_absolute

## Details

**Validation Rules:**

- Absolute paths MUST be under the alias root (or raise error)

- Absolute paths MUST exist (or raise error)

- Relative paths are resolved against alias root

- All paths are normalized to absolute form

**Return Structure:**

- `logical_path`: The user's path relative to root (for catalog, API)

- `storage_path`: Physical location where file lives (/\<rel_path\>/)

- `rel_path`: Relative path from root (same as logical but may differ in
  format)

- `alias`: The alias used

- `is_absolute`: Whether user provided absolute path

## Examples

``` r
if (FALSE) { # \dontrun{
# Relative path
result <- .st_normalize_user_path("dirA/file.qs")
# result$logical_path = "dirA/file.qs"
# result$storage_path = "<root>/dirA/file.qs/file.qs"
# result$rel_path = "dirA/file.qs"

# Absolute path
result <- .st_normalize_user_path("/full/path/to/root/dirA/file.qs")
# Validates it's under root, extracts rel_path = "dirA/file.qs"
} # }
```
