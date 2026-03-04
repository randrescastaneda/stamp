# Task Log: Fix Versioning

## Session: 2026-03-04 14:06:00

### Actions Taken

**Primary Bug Fix: `st_save()` → `st_should_save()` path handling**
- **Issue**: In `st_save()`, the call to `st_should_save()` was passing `storage_path` (e.g., `<root>/test.qs2/test.qs2`) instead of `rel_path` or `logical_path`
- **Impact**: When `st_should_save()` re-normalized this storage path via `.st_normalize_user_path()`, it double-nested to `<root>/test.qs2/test.qs2/test.qs2`, causing `rel_path` extraction to become `"test.qs2/test.qs2"` instead of `"test.qs2"`
- **Result**: Sidecar lookup always missed → always returned `missing_meta` → always saved, bypassing content-hash comparison → created duplicate versions with identical `content_hash`
- **Fix**: Changed `st_save()` line 236 in `IO_core.R` to pass `rel_path` instead of `storage_path` to `st_should_save()`

**Secondary Fix: `st_changed_reason()` redundancy**
- **Issue**: `st_changed_reason()` was pre-resolving paths via the older `.st_resolve_file_path()` helper before delegating to `st_changed()`, which already normalizes paths internally via `.st_normalize_user_path()`
- **Impact**: Redundant double-normalization using two different helpers (inconsistent API)
- **Fix**: Removed the pre-resolution step; `st_changed_reason()` now passes `path` directly to `st_changed()`, consistent with other functions

**Code Cleanup: Dead code removal**
- Removed `.st_resolve_file_path()` (~120 lines) from `R/aaa.R` — no longer called anywhere after the `st_changed_reason()` fix
- Removed `.st_resolve_and_normalize()` (~20 lines) from `R/aaa.R` — wrapper around the above, also never called
- Note: Orphaned documentation files remain in `man/` directory and should be cleaned up with `devtools::document()` or manual deletion

### Verification

**Testing**:
- Manual verification: Created test case showing the bug (saved identical content created new versions with same content_hash)
- After fix: Second save with identical content correctly skipped with reason `"no_change_policy"`
- Full test suite: 53 tests passing, 0 failures across `should-save`, `save-load`, and `edgecases` test files
- Verified `versioning = "content"` (default), `versioning = "timestamp"`, and `versioning = "off"` all work correctly

### Assumptions & Limitations

- Assumes no external code calls the removed helper functions (`.st_resolve_file_path()`, `.st_resolve_and_normalize()`)
- All path normalization now flows through `.st_normalize_user_path()` for consistency
- The bug only affected the default `versioning = "content"` mode when saving identical content multiple times

### Challenges

- Initial diagnosis required tracing the double-nesting bug through multiple layers of path normalization
- Distinguishing between `logical_path` (user-facing, absolute), `storage_path` (physical nested location), and `rel_path` (relative from root) was crucial to understanding the issue
- The bug was latent since it only manifested when `storage_path` was passed where `rel_path` was expected

### Files Modified

- `R/IO_core.R`:
  - Line 236: Changed `st_should_save(storage_path, ...)` → `st_should_save(rel_path, ...)`
  - Lines 905-925: Simplified `st_changed_reason()` to remove redundant path pre-resolution
- `R/aaa.R`:
  - Lines 177-335: Removed `.st_resolve_file_path()` and `.st_resolve_and_normalize()` functions

## To Do List

- [x] Run `devtools::document()` to regenerate `man/` folder and remove orphaned Rd files (`dot-st_resolve_file_path.Rd`, `dot-st_resolve_and_normalize.Rd`)
- [x] Consider adding a test case specifically for the double-save skip scenario to prevent regression
- [x] Review other functions that use `storage_path` to ensure they're using it correctly (only for file I/O operations, not as input to normalization functions)

### Audit Results: `storage_path` Usage Review

Reviewed all 15 occurrences of `storage_path` across `R/IO_core.R`:

**`st_save()` function:**
- ✅ Line 256: `fs::dir_create(fs::path_dir(storage_path))` - Creates physical directory (correct)
- ✅ Line 260: `.st_with_lock(storage_path, ...)` - Locks physical file (correct)
- ✅ Line 264: `path = storage_path` - Writes to physical file (correct)
- ✅ Line 299: `fs::file_info(storage_path)$size` - Gets physical file size (correct)
- ✅ Line 309: `st_hash_file(storage_path)` - Hashes physical file (correct)

**`st_load()` function:**
- ✅ Line 484: `fs::file_exists(storage_path)` - Checks physical file exists (correct)
- ✅ Line 510: `st_hash_file(storage_path)` - Hashes physical file (correct)
- ✅ Line 525: `h$read(storage_path, ...)` - Reads physical file (correct)

**`st_should_save()` function:**
- ✅ Line 943: `fs::file_exists(storage_path)` - Checks physical file exists (correct)

**Conclusion:** All uses of `storage_path` are correct. Each usage is for direct file I/O operations (directory creation, file locking, reading, writing, existence checking, file info, hashing). No function passes `storage_path` to another function that would re-normalize it. The bug fixed at line 236 (passing `storage_path` to `st_should_save()`) was the only instance of this anti-pattern.
