# Load an object from disk (format auto-detected; optional integrity checks)

Load an object from disk (format auto-detected; optional integrity
checks)

## Usage

``` r
st_load(file, format = NULL, version = NULL, ...)
```

## Arguments

- file:

  path or st_path

- format:

  optional format override

- version:

  An integer or a quoted directive. Retrieve a specific version of an
  artifact. See details.

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

- `"select"`, `"pick"`, or `"choose"`: displays an interactive menu to
  select from available versions (only in interactive R sessions).

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
selected <- st_load("data/mydata.rds", version = "select")
# or use "pick" or "choose"
selected <- st_load("data/mydata.rds", version = "pick")
} # }
```
