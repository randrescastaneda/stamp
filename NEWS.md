# stamp 0.0.7

## New Features

### Verbose Argument Support
* **NEW**: `st_save()`, `st_load()`, and `st_load_version()` now accept a `verbose` argument
  - `verbose = TRUE` (default): displays informational messages (backward compatible)
  - `verbose = FALSE`: suppresses all stamp messages and format warnings
  - Useful for batch processing and automated scripts
* Format wrappers automatically suppress warnings when `verbose = FALSE`
* Consistent verbose handling across all save/load functions

## Internal Improvements

### Restoration Logic Refactor
* **Refactored**: Consolidated duplicated restoration code into shared helper functions
  - New internal helper `.st_restore_sanitized_object()` restores sanitized objects (data.frames, data.tables)
  - New internal helper `.st_has_custom_rownames()` detects custom vs. default row.names
  - Both `st_load()` and `st_load_version()` now use the same restoration logic
* **Improved**: Row.names handling now treats all default representations equivalently
  - Compact form: `c(NA, -n)`, expanded integer: `1:n`, expanded character: `"1":"n"`
  - Sanitization uses `.set_row_names(as.integer(NROW(x)))` for consistent compact representation
* **Enhanced**: Full round-trip fidelity for data.frames with custom row.names and data.table objects
* **Tested**: Comprehensive test suite added in `tests/testthat/test-restoration-helpers.R`
  - 70+ tests covering helpers, edge cases, integration, and performance
  - Tests validate no internal attribute leakage to user code

### Test Infrastructure
* Integration tests use isolated temporary directories to prevent artifact reuse
* Format wrapper tests added in `tests/testthat/test-format-wrappers.R`

# stamp 0.0.6

## Breaking Changes

### Format Handling: qs vs qs2
* **BREAKING**: `.qs` and `.qs2` are now treated as distinct formats with separate handlers
  - `.qs` files use the `{qs}` package (`qs::qread` / `qs::qsave`)
  - `.qs2` files use the `{qs2}` package (`qs2::qs_read` / `qs2::qs_save`)
  - **No automatic fallback** from `qs2` to `qs` when `{qs2}` is not installed
  - Operations requiring a missing package will abort with a clear error message
* `{qs2}` moved from `Imports` to `Suggests` in DESCRIPTION
  - Install `{qs2}` explicitly if you need `.qs2` format support
  - Tests that require `{qs2}` now skip gracefully when the package is unavailable

### Extension Mapping
* Centralized extension-to-format mapping in `.st_extmap_defaults` table
* Added maintainer helpers: `st_extmap_defaults()` and `st_extmap_report()`
* Extension mapping now explicit and documented for easier maintenance

## Internal Changes
* Removed all qs2→qs fallback logic from format registry and I/O functions
* Format handlers in `.st_formats_env` now independently check for required packages
* Improved error messages when format-specific packages are missing

# stamp 0.0.5

## Major Features

### Version Loading
* **NEW**: `st_load()` now accepts a `version` argument to load specific historical versions
  - `version = NULL` or `0` loads the latest version (default behavior)
  - `version = -1, -2, ...` loads relative versions (previous, two back, etc.)
  - `version = "version_id"` loads a specific version by ID
  - `version = "select"`, `"pick"`, or `"choose"` shows interactive menu in console
* Interactive version selection menu displays timestamps, file sizes, and version IDs
* New internal function `.st_resolve_version()` handles version resolution logic

## Bug Fixes & Improvements

### Timestamp Precision
* **FIXED**: Timestamp precision increased from seconds to microseconds (ISO8601 format with `%OS6`)
  - Resolves ordering issues when multiple versions are saved within the same second
  - Format: `"2025-10-30T15:42:07.123456Z"` (backward compatible with old format)
  - Ensures reliable version ordering in rapid-fire save scenarios (e.g., automated pipelines)
* Updated `.st_now_utc()` to use microsecond precision
* Updated `.st_version_id()` to handle fractional seconds in timestamps
* Interactive menu timestamp parser handles both old (seconds) and new (microseconds) formats

### Data Loading
* `st_load_version()` now properly cleans loaded data, removing internal attributes (`st_original_format`, `stamp_sanitized`) and restoring `data.table` class when appropriate
* Consistent cleanup behavior between `st_load()` and `st_load_version()`

## Documentation
* Added vignette section demonstrating version loading workflows
* Examples showing interactive version selection and relative version indexing
* Updated documentation for `st_load()` with comprehensive `@param version` details

# stamp 0.0.5
* add ability to load specific versions via `st_load(version=...)`
* improve timestamp precision to microseconds to avoid ordering issues in versioning
* update `st_load_version()` to clean loaded data properly

# stamp 0.0.4

* add normalization of attributes
* Sanitize data.tables for consistent hashing
* improve logic of `st_hash_obj()`
* Avoid redundancies and make more efficient the use of `st_hash_obj()`

# stamp 0.0.3
* standardize helpers to use data.table
* Add get started vignette
* Add builders and plan vignette

# stamp 0.0.2
* first version to share

# stamp 0.0.1
* first stable version without testing or vignettes

* Initial CRAN submission.
