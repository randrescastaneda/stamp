# stamp 0.0.11

This release makes saving, loading, and keeping older versions more reliable.
It does not move your existing files or change their saved version IDs. Most
ordinary save and load calls can stay the same. Review the workflow changes
below before updating, especially if your code passes `x = NULL` or uses
experimental functions.

## Changes to Existing Workflows

* **Comparing with NULL:** In `st_changed()`, `st_changed_reason()`, and
  `st_should_save()`, writing `x = NULL` now means "compare with the R value NULL."
  Previously, it meant "do not compare the object." To keep that old behavior,
  leave out `x`: use `st_changed("data.rds")`, not
  `st_changed("data.rds", x = NULL)`. Calls that already leave out `x` need no
  change. Also update any helper functions that explicitly pass `x = NULL`.
* **Choosing a saved version:** `st_restore()` now accepts the same numbering as
  `st_load()`: `0` means the latest recorded version, `-1` the previous available
  version, and `-2` two versions back. These numbers count only versions still
  available after any older versions have been removed.
* **Replacing old restore numbers:** Positive numbers in `st_restore()` still
  select the same versions as before, but now produce a warning. Replace `1`
  with `0`, `2` with `-1`, and so on. In general, replace a positive number `p`
  with `1 - p`. Positive numbers will stop being supported in a future release.
  If you leave out `version`, `st_restore()` still chooses the oldest available
  version. Names such as `"latest"`, `"oldest"`, and exact version IDs still work.
* **Current file versus saved history:** `st_load()` without a `version` still
  reads the current file on disk. Use `version = 0` to read the latest recorded
  version instead. These can differ if the file was edited outside stamp.
* **Experimental tools for split datasets:** `st_part_path()`, `st_save_part()`,
  `st_write_parts()`, `st_list_parts()`, and `st_load_parts()` are no longer
  available as public functions. They need more testing with real-world data.
  Scripts using them must be reviewed; there is currently no supported public
  replacement. Access through `stamp:::` remains possible, but these functions
  can change without notice. Their user guide has also been withdrawn for now.
* **File paths:** `st_path()` is no longer a public function. Although earlier
  documentation suggested otherwise, its results did not work with `st_save()`
  or `st_load()`. Pass a text path such as `"results/model.rds"` instead.
* **Filtering data:** `st_filter()` now reports invalid filters with errors or
  warnings rather than silently ignoring them. Give every filter a column name.
  Unknown columns produce an error by default, or a warning with
  `strict = FALSE`. Set `strict` to `TRUE` or `FALSE`, not a number or text. This
  helps prevent a script from unknowingly continuing with data that were not
  filtered as intended.

## Safer Saving and Version History

* `st_rebuild()` now blocks dependent builders after a selected legacy builder
  fails, rather than publishing results that combine new inputs with an old
  failed-parent output. Blocked descendants keep their existing versions, while
  independent branches can still run.
* A failed file replacement no longer deletes the previous file first. A new
  version is added to the history list only after its saved files are ready,
  and an existing saved version cannot be overwritten.
* Saves to the same file coordinate with one another. If stamp cannot get its
  turn to write, it stops that save attempt instead of writing at the same time
  as another process.
* Removing old versions of one file no longer removes other files' history or
  their recorded dependencies. Invalid version counts, such as fractional
  numbers, are rejected instead of being rounded.
* Older versions are read using the file format recorded when they were saved.
  Changing your default format later will not make stamp choose the wrong
  reader for those versions. A failed restore is now reported as a failure,
  not as a successful restore.
* File checks also work when loading saved versions. Use
  `st_opts(verify_on_load = TRUE)` to enable checks; keep `verbose = TRUE` to see
  warnings when recorded checks do not match. Files without a recorded file
  fingerprint are not incorrectly reported as damaged.
* Rebuilding results now follows their dependencies more reliably, so inputs
  are rebuilt before results that depend on them. Existing file and version IDs
  stay the same.
* The extra information stored alongside each data file now follows changes
  between JSON and QS2 correctly. If both copies exist and disagree, stamp can
  warn and uses the JSON copy rather than silently choosing between them.

These fixes reduce the risk of losing data, but a save involving several files
is not an all-or-nothing operation. They do not guarantee recovery from a
computer crash halfway through saving. Keep backups of important data.

## Keeping data.table Keys

* RDS and QS2 saves now remember the original key of a `data.table`, including
  when loading older versions saved with this release. A key identifies the
  columns used to organize rows and speed up lookups. Tables without a key stay
  without one; declaring row identifiers, called a primary key, does not create
  a data.table key.
* Loading does not rearrange rows to create or repair a key. If the recorded key
  does not match the columns or row order, loading stops with an error. Keys
  that were not recorded in older saved versions cannot be recovered by this
  update.
* Changing only the key can now create a new version, even if the table values
  are unchanged. Scripts that inspect change reasons may see `"metadata"` and
  `details$metadata_changed`. Using `mode = "content"` still compares only the
  data content, not the key.
* If you add your own information through `metadata$attrs`, leave
  `metadata$attrs$stamp_data_table` for stamp to manage. Other user information
  is preserved. No changes to existing saved version IDs are needed.

## Saving NULL

* You can save `NULL` in RDS or QS2 files, replace an existing value with it,
  and restore a saved NULL value. Repeating an unchanged save still follows the
  usual rules for avoiding unnecessary versions.
* `NULL` is an R value meaning "no object." Saving it does not delete the file,
  and it is different from a missing value (`NA`) or a table with no rows.
* CSV, FST, and Parquet cannot store NULL this way. Those save attempts are
  rejected without replacing the previous data file. Use RDS or QS2 if NULL is
  a possible result of your workflow.

## Optional Copying of Environments

* Some advanced R objects, called environments, can change in place. An
  experimental option lets `st_save()` work on a copy of certain simple
  environments, so adding save-related information does not change the
  original object in your R session.
* The option is **off by default**. Enable it explicitly with
  `st_opts(reference_copy_on_save = TRUE)`, and read `?st_save` for its limits.
  It applies only when the object passed directly to `st_save()` is a supported
  environment and you use stamp's built-in RDS writer. It does not apply to
  environments hidden inside a list or model. Ordinary tables, lists, models,
  and NULL keep their existing save behavior.
* This is not general support for R6 objects or every kind of environment. With
  the option enabled, unsupported environments are rejected before saving,
  rather than guessing how to copy them. Links to some R or package environments
  remain shared, so the copy is not fully independent in every respect.
* Direct calls to `st_hash_obj()` and the comparison functions are unchanged.
  Leaving the option off preserves existing environment-saving behavior.

## A Summary of Saved Files

* The new `st_catalog_query()` returns one table showing the latest recorded
  version of each file in a chosen stamp folder, also called an alias. It
  includes file paths, version IDs, sizes, dates, and fingerprints used to
  recognize data and code changes. You no longer need to inspect each file
  separately to build this summary.
* An empty history returns an empty table with the usual columns. If the saved
  records are inconsistent, the function stops with a repair hint. If the folder
  has not been set up, it tells you to use `st_init()` first.

## Requested Rebuilds and Execution Records

* You can now give stamp an explicit request describing a calculation, its
  helper functions and constants, the exact saved input versions, meaningful
  metadata, and the registered file format. Planning and checks for whether a
  result is up to date use that information. Existing calls without a request
  keep their previous behavior.
* Rebuilds with a request recheck each selected result after its inputs have
  actually been rebuilt. If a calculation runs with a new input version but
  produces the same output, stamp can keep the existing output version and
  record the new execution separately. The output's original provenance is not
  rewritten, and later calculations can skip rebuilding if their input version
  has not changed.
* The new `st_execution_info()` inspects saved execution and outcome records
  without loading the data object. If you request an exact record ID, stamp
  never silently substitutes the latest record.
* The new `st_record_outcome()` records externally classified failed or blocked
  attempts. It cannot record success; successful execution records are created
  by rebuilds with a request. Saving an object by itself does not prove that a
  requested calculation ran.
* Recovery depends on the recorded failure class. A `"deterministic"` failure
  requires a reviewed failure ID and a change to an input or calculation
  component. An `"external"` failure permits one analyst-started attempt; an
  `"unknown"` failure blocks execution. A missing builder is a recoverable
  configuration problem, not an unknown failure from running the calculation.
* Changes to the declared semantic schema or values, meaning metadata that
  affects what the result represents, create a new version even when the data
  are unchanged. Historical metadata reads preserve distinctions between NULL,
  NA, empty values, and integer versus double values in JSON, QS2, and combined
  modes. If the exact requested metadata are unavailable, stamp reports an
  error rather than substituting another version.
* An unchanged save returns a checked, retained version ID, but not an execution
  record. Changes only to descriptive metadata do not rewrite the information
  stored alongside an unchanged file. Older data versions use their recorded
  physical file format rather than relying on the filename extension.
* Removing old versions now protects references from saved execution records
  and the original input history needed by retained versions. Protected or
  invalid removal selections are refused before deleting anything. These
  guarantees cover isolated, serial operations, not forced execution, automatic
  retries, cryptographic authenticity, atomic operations over SMB network
  shares, or certified operation with multiple writers.

## Other Fixes and Documentation

* Removing stamp's bookkeeping from a loaded data.table no longer changes an
  object your code already holds. Missing names in row identifiers or
  filters are rejected more clearly. Loading and unloading the package restores
  the command-line display settings it changes.
* The experimental split-dataset tools have fixes for reading selected columns
  and reporting missing or unreadable files. They remain outside the supported
  public functions.
* Added tests for failed saves, simultaneous writers, and repeated loading and
  unloading. Added developer tools to review functions and measure performance,
  plus automated checks for Windows and Linux. This does not mean every object
  type or operating-system setup has been verified.
* Updated examples to use the correct function arguments and explain how to turn
  file checks on. Clarified that `st_inspect_pk()` reads the recorded row
  identifiers; it does not check the data for duplicate rows.

# stamp 0.0.10

* Fixed unnecessary duplicate versions when saving unchanged data. A file-path
  error had prevented stamp from recognizing that the content was the same.
  Existing `st_save()` calls need no changes; workflows may now produce fewer
  duplicate versions.
* Fixed paths being repeated inside one another during saving. Simplified the
  checks used by `st_changed_reason()` and removed unused support code, without
  changing how users call these functions.

# stamp 0.0.9

## New Folder Layout

* **Upgrade warning:** This release changed where files and their history are
  stored. Back up existing stamp folders and review the layout before updating
  a workflow from an older release.
* Data files are stored in their own folders under the project root. For
  example, `st_save(data, "results/model.rds")` stores the current data at
  `<root>/results/model.rds/model.rds`. A bare name such as `"data.qs2"` is stored
  at `<root>/data.qs2/data.qs2`.
* Each file now keeps its own `versions/` folder. Previously, version history
  was kept centrally under `<root>/.stamp/versions/<version_id>/`. The `.stamp/`
  folder now holds bookkeeping, temporary files, and logs rather than the data.
* The old internal `.st_versions_root()` helper now warns that it is being
  retired. Code relying on that internal helper needs updating.

## Restoring and Finding Files

* Added `st_restore()` to bring back an earlier saved version by name, ID, or
  position in the history. Restoring is recorded as another version, so the
  history is kept. See 0.0.11 above for the current numbering rules.
* Made file paths work more consistently across saving, loading, and history
  queries. You can use a bare filename, a path with subfolders, or a full path
  inside the project root.
* Fixed Windows path errors that could prevent old versions from being removed.

## Checks and Guides

* Updated tests and documentation for the new folder layout and added restore
  tests. A performance check with 1,000 versions across 50 files removed about
  242 versions per second in that test setup; this is not a speed guarantee for
  other computers or datasets.

# stamp 0.0.8

## Working with Several Folders

* Added aliases: names that let you choose between independent stamp folders.
  The alias selects the folder; its name is not added to the saved file path.
  Existing workflows using the default folder continue to work.
* Added a guide explaining how to choose and switch aliases, with clearer
  function documentation and shorter README instructions.

## Finding Versions and Dependencies

* Made `st_children()` faster at finding results that depend on a file by keeping
  a lookup list. Older histories without that list can still be searched.
* Improved how `st_latest()` finds the newest version, reducing the risk of
  using an outdated history entry.
* Improved checks and coordination when updating the history list, including
  when more than one process is saving. Dependency queries use information
  saved with each version when it is available.
* Updated package setup, testing requirements, license files, and help pages.
  These maintenance changes do not require changes to ordinary save/load calls.

# stamp 0.0.7

## Quieter Automated Workflows

* Added `verbose` to `st_save()`, `st_load()`, and `st_load_version()`.
  `verbose = TRUE` keeps the usual progress messages. Set `verbose = FALSE` to
  hide routine messages and file-format warnings, which is useful in scripts
  and scheduled jobs.

## Loading Tables More Consistently

* Improved how tables are returned after loading, including data.table objects
  and tables with custom row names. The current-file and older-version loaders
  now use the same cleanup steps, so users see fewer internal bookkeeping
  details on their objects.
* Made ordinary numbered row names compare consistently, even when R stores
  them differently. This helps avoid treating equivalent tables as different.
* Added tests for table restoration and quiet operation. Tests use separate
  temporary folders so that one test's files do not affect another.

# stamp 0.0.6

## File Formats and Required Packages

* **Upgrade warning for this release:** `.qs` and `.qs2` were given separate
  readers and writers. `.qs` used the `qs` package; `.qs2` used `qs2`. A missing
  `qs2` package no longer caused stamp to try `qs` instead.
* The `qs2` package became optional rather than being installed automatically
  with stamp. Users of QS2 files needed to install it explicitly. Missing
  file-format packages now produce clearer error messages.
* Made the connection between file extensions and their readers and writers
  easier to inspect and maintain. Added maintainer tools for reporting those
  choices. These notes describe the 0.0.6 changes; check `st_formats()` for the
  formats available in your installed version.

# stamp 0.0.5

## Loading Earlier Versions

* Added the `version` argument to `st_load()`. You can choose a saved version by
  its ID, use negative numbers to go back through the history, or use
  `"select"`, `"pick"`, or `"choose"` to open a selection menu. See 0.0.11 above
  for the current distinction between the file on disk and recorded versions.
* The selection menu shows dates, file sizes, and version IDs to help identify
  the version you need. Added examples for these ways of loading data.

## More Reliable Version Ordering

* Recorded save times more precisely, including fractions of a second. This
  helps order versions created very quickly, such as in an automated workflow.
  Older timestamps remain readable.
* Improved `st_load_version()` so it removes stamp's internal bookkeeping and
  returns data.table objects in the expected form, consistent with `st_load()`.

# stamp 0.0.4

* Improved how stamp compares objects, especially data.tables, so differences
  in R's internal bookkeeping are less likely to create unnecessary versions.
* Reduced repeated work when calculating the fingerprints used to recognize
  unchanged objects.

# stamp 0.0.3

* Added a getting-started guide and a guide to recording rebuild steps and
  planning which results need updating.
* Standardized the package's support code around data.table.

# stamp 0.0.2

* Made an early version available for others to use.

# stamp 0.0.1

* Introduced the first stable version and prepared the initial CRAN submission.
  Automated tests and user guides were not yet included.
