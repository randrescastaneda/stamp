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
