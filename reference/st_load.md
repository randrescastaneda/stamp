# Load an object from disk (format auto-detected; optional integrity checks)

Load an object from disk (format auto-detected; optional integrity
checks)

## Usage

``` r
st_load(file, format = NULL, version = NULL, verbose = TRUE, alias = NULL, ...)
```

## Arguments

- file:

  path or st_path. Can be:

  - A bare filename (e.g., `"data.qs2"`) → loaded from
    `<alias_root>/data.qs2/data.qs2`

  - A path with directory (e.g., `"results/model.rds"`) → loaded from
    `<alias_root>/results/model.rds/model.rds` When using a path with
    directory and an explicit `alias`, the alias root must be a parent
    of the path, otherwise an error is raised.

- format:

  optional format override

- version:

  An integer or a quoted directive. Retrieve a specific version of an
  artifact. See details.

- verbose:

  logical; if FALSE, suppress informational messages and
  package-generated warnings (default TRUE). When `FALSE`, warnings
  about file/content hash mismatches and a missing primary key recorded
  by `st_load()` will not be shown.

- alias:

  Optional stamp alias to target a specific stamp folder. If `NULL`
  (default), uses the default alias. If the default alias does not
  exist, an error is raised. Use aliases to operate across multiple
  stamp folders.

- ...:

  forwarded to format reader

## Value

the loaded object

## Details

The `version` argument allows you to load specific versions:

- `NULL` (default): loads the most recent version available.

- Negative integer (e.g., `-1`) or zero (`0`): loads that number of
  versions before the most recent version. So, if `0`, it loads the
  current version, which is equivalent to `NULL`. If `-1`, it will load
  the version right before the current one, `-2` loads two versions
  before, and so on.

- Positive numbers: Error.

- Character: treated as a specific version ID (e.g.,
  "20250801T162739Z-d86e8").

- Interactive selection (e.g., `"select"`, `"pick"`, `"choose"`) is
  supported and only non-interactive sessions must pass a concrete
  version id or negative integer for relative selection.

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic usage: load latest version
data <- st_load("data/mydata.rds")

# Load previous version
old_data <- st_load("data/mydata.rds", version = -1)

# Load specific version by ID
vid <- st_versions("data/mydata.rds")$version_id[3]
specific <- st_load("data/mydata.rds", version = vid)

# Interactive menu (in interactive sessions only)
# Interactive selection is not supported in non-interactive contexts.
# Pass explicit version id or a negative integer.
} # }
```
