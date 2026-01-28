# stamp 0.0.9

# stamp 0.0.9 (Development)

## Major Changes

### Simplified Storage Structure
* **BREAKING**: Changed artifact storage structure to separate state and data:
  - `.stamp/` contains only state (catalog, temp, logs)
  - Artifacts stored directly as `<path>/<filename>/<filename>` under project root
  - Example: `st_save(data, "results/model.rds")` → `<root>/results/model.rds/model.rds`
  - Bare filenames stored directly under root: `st_save(data, "data.qs2")` → `<root>/data.qs2/data.qs2`
  - More transparent storage location matching user's mental model

### Distributed Version Storage
* **BREAKING**: Version history now stored per-artifact instead of centralized:
  - Old: `<root>/.stamp/versions/<version_id>/`
  - New: `<root>/<path>/<filename>/versions/<version_id>/`
  - Each artifact folder contains its own `versions/` directory
  - `.st_versions_root()` deprecated with warning (may be removed in future)

### New Functions
* **NEW**: `st_restore()` - Restore artifacts to previous versions
  - Supports version keywords: "latest", "oldest"
  - Supports specific version IDs
  - Supports integer offsets from latest (1 = previous, 2 = two back, etc.)
  - Creates new version entry for restoration (allows redo)

## Path Handling
* **Enhanced**: Centralized path normalization via `.st_normalize_user_path()`
  - Accepts bare filenames (stored directly under root)
  - Accepts relative paths with subdirectories
  - Accepts absolute paths under project root (converted to relative)
  - Consistent path handling across all save/load/query functions
  - Improved Windows path handling in `st_prune_versions()`

## Bug Fixes
* **FIXED**: Path normalization issue in `st_prune_versions()` on Windows
  - Replaced `fs::path_rel()` with `.st_extract_rel_path()` to prevent malformed paths
  - Fixes deletion failures with excessive `../` components in temp directory hierarchies

## Testing
* **UPDATED**: Comprehensive test suite updated for new storage structure
  - All tests now use direct-path storage (removed `.st_data` references)
  - Tests covering save/load, subdirectories, versioning, queries work with new architecture
* **NEW**: Test suite for `st_restore()` functionality (`test-restore.R`)
  - 11 tests covering restoration scenarios and error handling
* **VERIFIED**: Performance testing with 1,000 versions (50 artifacts × 20 versions)
  - Pruning performance: ~242 versions/second

## Documentation
* **UPDATED**: README now documents the simplified storage structure
* **UPDATED**: Function documentation reflects direct-path storage
* **DEPRECATED**: `.st_versions_root()` marked as deprecated with migration guidance

## Internal Changes
* All core functions updated to use direct-path storage structure:
  - `st_init()` 
  - `st_save()`, `st_load()`, `st_load_version()`
  - `st_info()`, `st_versions()`, `st_changed()`
  - `st_rebuild()`, `st_prune_versions()`
  - Catalog operations, sidecar management, version store
* Path helpers reorganized for better maintainability:
  - Updated `.st_file_storage_dir()` to work directly with root
  - Simplified `.st_extract_rel_path()` to only handle paths under root
  - Enhanced path extraction to prevent Windows path resolution issues

# stamp 0.0.8

## New Features

### Alias Support
* **NEW**: Alias support across the package to manage multiple independent stamp folders.
  - Alias acts purely as a selector (not embedded in filesystem paths).
  - Backward-compatible default alias retained.

### Reverse Lineage Index
* **NEW**: Catalog `parents_index` accelerates reverse lineage queries used by `st_children()`.
  - Falls back to snapshot scanning when index is not present.



## Internal Improvements

### Latest Version Derivation
* **Improved**: `st_latest()` derives latest from `st_versions()` ordering to avoid stale artifact rows.

### Catalog Robustness & Concurrency
* **Enhanced**: Deterministic upsert/append operations and idempotent file locks during catalog writes.
* **Defensive**: Schema checks and coercions for loaded catalogs; atomic writes for integrity.

### Lineage Traversal
* **Refined**: `st_lineage()` prioritizes committed `parents.json`; level-1 fallback to sidecar parents for convenience.

## Documentation & Metadata
* **Vignette**: Added `vignettes/using-alias.Rmd` explaining alias usage, switching, constraints, and troubleshooting.
* **README**: Trimmed alias section; linked to the dedicated vignette.
* **Roxygen**: Added `alias` parameter documentation to public functions that accept it.
* **Globals**: Expanded `utils::globalVariables` to cover `data.table` NSE symbols.
* **DESCRIPTION**: Added `withr` and `pkgload` to `Suggests` for tests/vignettes.
* **.Rbuildignore**: Now ignores `.vscode`.
* **LICENSE**: Converted to CRAN-compliant stub for `MIT + file LICENSE`.

## Bug Fixes
* **Fixed**: Resolved `Rd \usage` mismatch for internal `.st_version_write_parents()`.

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
