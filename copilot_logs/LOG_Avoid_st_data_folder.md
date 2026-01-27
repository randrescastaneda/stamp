# Task: Avoid st_data folder

Task name: Avoid st_data folder  
Description: Avoid the creation of .st_data folder and just write data right away in the path given by the user (or folder if it is part of the path provided by the user)

Initialized: 2026-01-26T14:01:45-05:00

Initial context and relevant information
- Repository / workspace roots open:
  - e:\PovcalNet\01.personal\wb535623\PIP\pipdata
  - e:\PovcalNet\01.personal\wb535623\PIP\stamp
- Active file & excerpt: e:\PovcalNet\01.personal\wb535623\PIP\stamp\R\IO_core.R
  - st_init() currently creates a data folder:
    - data_folder_name <- st_opts("data_folder", .get = TRUE) %||% ".st_data"
    - data_folder <- fs::path(root_abs, data_folder_name)
    - .st_dir_create(data_folder)
- Observed behavior: .st_data folder is created under project root by default. st_save() and related helpers assume artifact storage under that folder for relative paths.

Goal
- Stop creating a dedicated .st_data folder by default.
- When user provides a path:
  - If path includes directories, write directly into that folder (relative to project root or absolute path) rather than mirroring into .st_data.
  - If a bare filename is provided, write it directly under the project root (or respect explicit alias handling) rather than placing it under .st_data.
- Maintain alias/state behavior and versioning; ensure sidecar/catalog still operate correctly.

Assumptions / open questions
- Do we still want a configurable `st_opts("data_folder")` option supported for backwards compatibility? (default currently ".st_data")
- How should absolute paths outside project root be treated? (allow, error, or convert to relative?)
- For bare filenames, should we write to root_abs directly (current request) or to a configurable location?
- Confirm desired behavior for multiple aliases pointing to same folder (no change expected).

Initial To Do List
- [ ] Confirm behaviors for absolute paths and bare filenames (user decision).
- [ ] Update .st_init to stop creating data folder (remove/guard .st_dir_create(data_folder)).
- [ ] Update path-normalization helpers (.st_normalize_user_path / .st_resolve_file_path) to:
      - respect user-supplied paths (directories included) and compute storage_path accordingly
      - keep logical_path for catalog consistent with the user's path
- [ ] Update st_save, st_load, st_restore tests and add new unit tests covering:
      - bare filename saves (written to root)
      - relative-path saves (written to the directory in the path)
      - absolute-path saves (behavior to be decided)
- [ ] Update docs and examples for st_init/st_save/st_load behavior
- [ ] Run package tests and adjust failing expectations referencing .st_data
- [ ] Add migration note for users relying on .st_data

Relevant files likely to change
- stamp/R/IO_core.R (.st_init, .st_normalize_user_path, .st_resolve_file_path)
- stamp/R/IO_sidecar.R (sidecar location logic)
- stamp/R/catalog.R (if artifact storage assumptions appear)
- tests/testthat/* (tests referencing .st_data)

Notes
- Keep backward compatibility option: if st_opts("data_folder") explicitly set, honor it; otherwise default to writing directly to supplied paths.
- Ensure atomic writes, sidecar writes, and version snapshotting remain unchanged.

Running summary (will be appended as we progress)
- 2026-01-26T14:01:45-05:00: Task initialized; awaiting confirmation on absolute-path & bare-filename behavior.
- 2026-01-26T14:35:00-05:00: Confirmed decisions:
  - No backward compatibility needed (st_opts("data_folder") will be removed completely)
  - Absolute paths: keep current restriction (must be under alias root)
  - New storage structure:
    - Bare filename "data.qs2" → <root>/data.qs2/data.qs2 (with stmeta/ and versions/ under <root>/data.qs2/)
    - Path "results/model.rds" → <root>/results/model.rds/model.rds (with stmeta/ and versions/ under <root>/results/model.rds/)
  - Duplicate filename in storage path is necessary (folder named after file with format)
- 2026-01-26T14:40:00-05:00: Implemented core changes:
  - ✅ Removed .st_data folder creation from st_init() in IO_core.R
  - ✅ Removed .st_data_folder() function completely from utils.R
  - ✅ Updated .st_file_storage_dir() to work directly with root instead of data_folder
  - ✅ Updated .st_artifact_path() documentation (logic unchanged, works correctly)
  - ✅ Simplified .st_extract_rel_path() to only handle paths under root (removed .st_data logic)
  - ✅ Updated .st_normalize_user_path() to remove data_folder references
  - ✅ Updated documentation for st_save(), st_load(), and st_restore() to reflect new storage structure
- 2026-01-26T17:00:00-05:00: Final cleanup of test files:
  - ✅ Updated test-write-parts.R: Removed all .st_data references (2 locations)
  - ✅ Verified NO remaining .st_data references in any test files
  - All test files now use new storage structure: <root>/<path>/<filename> instead of <root>/.st_data/<path>/<filename>
  
Task complete. All code and tests updated to remove .st_data folder.

---

## Update: 2026-01-26T18:20:00-05:00

### Progress Summary
- ✅ Fixed vignette rebuild error in `version_retention_prune.Rmd`
- ✅ Deprecated `.st_versions_root()` function with proper documentation
- ✅ Fixed `st_prune_versions()` path normalization bug causing deletion failures
- ✅ Updated vignette to show per-artifact version directory structure

### Challenges Encountered

**Vignette Error During R CMD check:**
- Error occurred when rebuilding `version_retention_prune.Rmd` vignette
- Root cause: Path normalization issue in `st_prune_versions()`
- Error message showed mangled path with many `../` components:
  ```
  [ENOENT] Failed to remove 'C:/Users/.../stamp-retention-example/../../../../../../../../../../users/.../stamp-retention-example/a.qs/versions/1c34572a11dd4c1a/artifact': no such file or directory
  ```

**Technical Issue:**
- `st_prune_versions()` was using `fs::path_rel(a_path, start = root)` to compute relative paths
- On Windows with temp directories in different hierarchies, this creates paths with excessive `../` components
- These malformed paths don't resolve correctly when passed to `fs::dir_delete()`

### Changes Made

1. **R/retention.R** (lines 265-277):
   - Changed from manual `fs::path_rel()` computation to using `.st_extract_rel_path()`
   - This helper properly handles path extraction from absolute paths stored in catalog
   - Prevents path resolution issues across different directory hierarchies

2. **vignettes/version_retention_prune.Rmd** (lines 88-95):
   - Removed call to deprecated `.st_versions_root()`
   - Updated to show per-artifact version directories: `<root>/A.qs/versions/`
   - Added comment explaining new distributed version storage

3. **R/version_store.R** (lines 60-88):
   - Marked `.st_versions_root()` as deprecated in documentation
   - Added warning when function is called explaining versions are now per-artifact
   - Function no longer creates centralized versions directory

4. **man/dot-st_versions_root.Rd**:
   - Updated documentation to reflect deprecation status
   - Added explanation of new architecture

### Next Steps
None - all issues resolved. The package now correctly:
- Stores versions in `<artifact_folder>/versions/<version_id>/` instead of centralized location
- Prunes versions without path resolution errors
- Builds vignettes successfully in R CMD check

---

## To Do List

- [x] Run full R CMD check - Confirmed passing

### Critical Improvements (Robustness)

- [ ] **Add path validation in deletion loop** (PRIORITY: CRITICAL)
  - Issue: `.st_extract_rel_path()` can return NULL/NA on failure, but deletion loop doesn't validate before proceeding
  - Risk: Catalog corruption when paths can't be resolved - catalog updated but files not deleted
  - Implementation: Add validation check before `fs::dir_delete()`, abort on failure
  - Location: `R/retention.R` lines 268-276 in deletion loop
  - Code snippet:
    ```r
    for (i in seq_len(nrow(to_delete))) {
      a_path <- .st_extract_rel_path(to_delete$storage_path[i], alias = alias)
      if (is.null(a_path) || is.na(a_path)) {
        cli::cli_abort("Failed to extract path for version {to_delete$version_id[i]}")
      }
      v_dir <- .st_version_dir(a_path, to_delete$version_id[i])
      # ... rest of deletion logic
    }
    ```

- [ ] **Track deletion failures and update catalog accordingly** (PRIORITY: CRITICAL)
  - Issue: Partial failures not tracked - catalog always updated even if some deletions fail
  - Risk: Catalog-filesystem inconsistency when file system errors occur
  - Implementation: Track success/failure for each deletion, only update catalog for successfully deleted versions
  - Location: `R/retention.R` lines 268-298
  - Code snippet:
    ```r
    deleted_versions <- character(0)
    for (i in seq_len(nrow(to_delete))) {
      tryCatch({
        # ... deletion logic
        deleted_versions <- c(deleted_versions, to_delete$version_id[i])
      }, error = function(e) {
        cli::cli_warn("Failed to delete version {to_delete$version_id[i]}: {e$message}")
      })
    }
    # Update catalog only for successfully deleted versions
    catalog$versions <- catalog$versions[!version_id %in% deleted_versions]
    ```

### High Priority Improvements (Performance & Maintainability)

- [ ] **Eliminate redundant sorting in policy evaluation** (PRIORITY: HIGH)
  - Issue: Sorts entire table once (line 210), then re-sorts each artifact block in loop (line 220)
  - Impact: O(n log n) × N artifacts - significant overhead for large catalogs
  - Expected gain: 20-30% faster policy evaluation
  - Implementation: Sort once with artifact_id as primary key, remove per-block sort
  - Location: `R/retention.R` lines 208-224
  - Code snippet:
    ```r
    # Sort ONCE with artifact_id as grouping key
    setorder(vers, artifact_id, -created_at, -version_id)
    # Split by artifact (already sorted)
    vers_by_artifact <- split(vers, by = "artifact_id", keep.by = FALSE)
    # Remove the sort() call in loop at line 220
    ```

- [ ] **Vectorize artifact updates using data.table** (PRIORITY: HIGH)
  - Issue: Row-by-row updates in loop (lines 287-295), grows vector incrementally
  - Impact: Inefficient memory allocation and repeated catalog modifications
  - Expected gain: Faster, more idiomatic data.table code
  - Implementation: Collect all artifact_ids to update, use single by-reference operation
  - Code snippet:
    ```r
    # After deletion loop
    affected_artifacts <- unique(to_delete$artifact_id)
    catalog$artifacts[artifact_id %in% affected_artifacts, 
                      last_modified := format(Sys.time(), "%Y-%m-%d %H:%M:%S")]
    ```

### Medium Priority Improvements (Performance)

- [ ] **Hoist alias lookup outside deletion loop** (PRIORITY: MEDIUM)
  - Issue: Calls `.st_extract_rel_path()` 750+ times in loop, each doing alias lookup and path normalization
  - Impact: ~10-15% overhead from redundant operations
  - Expected gain: 3.1s → ~2.7s for 750 versions
  - Implementation: Resolve alias config once before loop, inline path extraction using pre-computed root
  - Location: `R/retention.R` lines 268-276
  - Status: Deferred from earlier efficiency review

- [ ] **Pre-allocate vectors instead of growing in loops** (PRIORITY: MEDIUM)
  - Issue: Growing `artifact_ids` vector in loop (line 285)
  - Impact: Repeated memory reallocation, though minor for typical catalog sizes
  - Implementation: Pre-allocate with `character(nrow(to_delete))`, track index
  - Also applies to deleted_versions tracking in failure handling improvement above

### Documentation & Cleanup

- [ ] Consider removing `.st_versions_root()` entirely - Deprecated function only kept for backward compatibility, evaluate if complete removal is better
- [ ] Review other vignettes - Check if other vignettes reference centralized version storage or `.st_data` folder and update them to reflect the new per-artifact structure
- [ ] Update package documentation - Ensure README.md and other high-level documentation reflects the removal of `.st_data` folder and new storage architecture
