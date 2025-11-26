# stamp (development version)

## Major Features

### Partitioned Datasets
* **NEW**: `st_write_parts()` - Auto-partition datasets by specified columns with Hive-style directory structure. Eliminates manual nested loops for partition creation.
* **NEW**: Expression-based filtering for `st_load_parts()` and `st_list_parts()` using formula syntax (`~ year > 2021`, `~ country %in% c("USA", "CAN")`). Backward compatible with named list filtering.
* **NEW**: Columnar loading support with `columns` argument. Native column selection for parquet/fst formats (reads only specified columns from disk). Fallback subsetting for qs/rds/csv formats.
* **NEW**: Comprehensive partitioning vignette (`vignette("partitions")`) with examples, performance tips, and comparisons with Arrow/DuckDB.

### Format Support
* **NEW**: Parquet format support via `nanoparquet` package (lightweight, no system dependencies).
* **CHANGE**: Default format for partitions is now `parquet` (optimal for columnar analytics).
* **NEW**: Format registry supports automatic type-specific column selection.

### Partitioning Functions
* `st_write_parts(x, base, partitioning, ...)` - Auto-partition and save datasets
* `st_load_parts(base, filter, columns, as)` - Load partitions with filtering and column selection
* `st_list_parts(base, filter)` - List available partitions without loading data
* `st_save_part(x, base, key, ...)` - Save individual partition (low-level)
* `st_part_path(base, key, ...)` - Build partition path (utility)

### Filter Capabilities
* **Exact match** (backward compatible): `filter = list(country = "USA", year = 2020)`
* **Expression-based** (NEW): `filter = ~ year > 2021 & country != "USA"`
* **Boolean operators**: `&` (AND), `|` (OR), `!` (NOT)
* **Comparisons**: `>`, `<`, `>=`, `<=`, `==`, `!=`
* **Set operations**: `%in%` for multiple values
* **Auto type conversion**: Numeric and boolean partition keys converted from strings

## Performance Improvements
* Partitioning uses `data.table::split()` for efficient splitting when available
* Progress bar for partition operations (>10 partitions by default, configurable)
* Smart warning system for non-columnar formats (warns once per format type)
* Partition keys automatically included in loaded results

## Bug Fixes & Improvements
* Remove unnecessary `requireNamespace()` checks for packages in Imports (data.table, cli)
* Fix data.table column selection syntax in partition operations

## Documentation
* New vignette: "Working with Partitioned Datasets"
* Updated examples demonstrating auto-partitioning workflow
* Performance guidelines for partition key selection
* Format comparison tables (write/read speed, column selection, compression)

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
