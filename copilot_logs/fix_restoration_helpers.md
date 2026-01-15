# Refactor Restoration Logic for Efficiency and Maintainability

**Task:** `fix_restoration_helpers`  
**Date:** January 15, 2026  
**Branch:** `fix_verbose`  
**Repository:** stamp (randrescastaneda)

---

## 1. Task Overview

### What the Task Was About

The task focused on improving code efficiency, simplicity, and maintainability in the `stamp` package's object restoration logic. Specifically:

- **Identified Problem:** Duplicated restoration code existed in both `st_load()` and `st_load_version()` for restoring sanitized objects (data.frames, data.tables) after deserialization.
- **Goal:** Consolidate the restoration logic into shared helper functions to eliminate redundancy, improve testability, and ensure consistent behavior across the save/load cycle.
- **Scope:** Refactored hashing/sanitization utilities, load functions, and created comprehensive test coverage for the new helper functions.

### Main Files and Functions Affected

**Modified Files:**
1. **`R/hashing.R`**
   - Added `.st_restore_sanitized_object()`: Centralized helper to restore original object attributes (class, row.names) and remove internal metadata.
   - Added `.st_has_custom_rownames()`: Helper to detect whether a data.frame has custom (non-default) row.names.
   - Updated `st_sanitize_for_hash()`: Enhanced to use `.set_row_names(as.integer(NROW(x)))` for default row.names normalization, ensuring compact internal representation.

2. **`R/IO_core.R`**
   - Updated `st_load()`: Replaced inline restoration code with a call to `.st_restore_sanitized_object()`.

3. **`R/version_store.R`**
   - Updated `st_load_version()`: Replaced inline restoration code with a call to `.st_restore_sanitized_object()`.

4. **`tests/testthat/test-restoration-helpers.R`**
   - Created comprehensive test suite covering:
     - Helper function behavior (custom vs. default row.names detection)
     - Restoration fidelity for data.frames, data.tables, edge cases
     - Integration tests with `st_save()`, `st_load()`, `st_load_version()`
     - Performance validation for large data.tables

**Unchanged Files:**
- **`R/format_registry.R`**: Verified that format wrappers already support `verbose` parameter; no changes needed.

### Major Decisions and Trade-Offs

1. **Centralized Restoration Logic:**
   - **Decision:** Create a single `.st_restore_sanitized_object()` function called by both `st_load()` and `st_load_version()`.
   - **Rationale:** Eliminates code duplication, ensures consistent restoration semantics, and simplifies future maintenance.
   - **Trade-off:** Adds one more internal function to the codebase, but the benefit of avoiding duplication outweighs the cost.

2. **Default Row.Names Normalization:**
   - **Decision:** Use `.set_row_names(as.integer(NROW(x)))` in `st_sanitize_for_hash()` to set default row.names in their compact form.
   - **Rationale:** R's internal representation of default row.names can be compact (`c(NA, -n)`) or expanded (`c("1", "2", ..., "n")`). Using the integer form ensures consistent compact representation across R sessions and avoids spurious hash differences.
   - **Trade-off:** Slight increase in complexity in the sanitization logic, but gains consistency and correctness.

3. **Custom Row.Names Detection:**
   - **Decision:** `.st_has_custom_rownames()` treats default row.names equivalently across all internal representations (compact `c(NA, -n)`, integer `1:n`, character `"1":"n"`).
   - **Rationale:** R can represent default row.names in multiple ways; the helper must recognize all of them to avoid false positives.
   - **Trade-off:** More elaborate detection logic, but necessary for robustness.

4. **Test File Cleanup Strategy:**
   - **Decision:** Use `withr::defer(..., testthat::teardown_env())` instead of deprecated `teardown()` to remove `.stamp` directories after test runs.
   - **Rationale:** Aligns with testthat edition 3 best practices and eliminates deprecation warnings.
   - **Trade-off:** Slightly more verbose, but future-proof and cleaner.

5. **Integration Test Isolation:**
   - **Decision:** Create fresh temporary directories for integration tests using `td <- withr::local_tempdir(); withr::local_dir(td)` before `st_init(".")`.
   - **Rationale:** Prevents test interference when artifacts already exist in the working directory, which would cause `st_save()` to skip and return no `version_id`.
   - **Trade-off:** Adds setup boilerplate, but essential for test reliability.

---

## 2. Technical Explanation

### Step-by-Step Description of How the Code Works

#### Sanitization for Hashing (`st_sanitize_for_hash()`)

1. **Purpose:** Prepare an R object for content hashing by normalizing attributes that are irrelevant to the data content (e.g., row.names, data.table class).

2. **Process:**
   - **Detect Custom Row.Names:** Calls `.st_has_custom_rownames()` to check if the object has custom row.names.
     - If custom, store them in `attr(x, "st_original_rownames")` for later restoration.
   - **Normalize Default Row.Names:** If not custom, set row.names to compact default using `.set_row_names(as.integer(NROW(x)))`.
   - **Convert data.table to data.frame:** If the object is a `data.table`, convert it to `data.frame` and store the original class in `attr(x, "st_original_format")`.
   - **Mark as Sanitized:** Add `attr(x, "stamp_sanitized") <- TRUE` to indicate processing.

3. **Result:** A normalized object whose hash will be stable across equivalent data content.

#### Custom Row.Names Detection (`.st_has_custom_rownames()`)

1. **Purpose:** Determine whether a data.frame has custom (user-specified) row.names or default (automatic) row.names.

2. **Logic:**
   - **Retrieve row.names:** `rn <- attr(x, "row.names", exact = TRUE)`.
   - **Empty or NULL:** Return `FALSE`.
   - **Compact Form:** If `is.integer(rn) && length(rn) == 2 && is.na(rn[1])`, it's the compact default (`c(NA, -n)`); return `FALSE`.
   - **Integer or Character Sequence:** If `rn` is `1:n` (integer) or `"1":"n"` (character), it's default; return `FALSE`.
   - **Otherwise:** Custom row.names; return `TRUE`.

3. **Edge Cases:**
   - Handles zero-row data.frames.
   - Treats all equivalent representations of default row.names consistently.

#### Restoration (`.st_restore_sanitized_object()`)

1. **Purpose:** Reverse the sanitization applied by `st_sanitize_for_hash()`, restoring the original object attributes.

2. **Process:**
   - **Restore data.table Class:** If `attr(x, "st_original_format") == "data.table"`, convert back using `data.table::setDT(x)`.
   - **Restore Custom Row.Names:** If `attr(x, "st_original_rownames")` is present, restore them using `attr(x, "row.names") <- orig_rn`.
   - **Remove Internal Attributes:** Delete `st_original_rownames`, `st_original_format`, and `stamp_sanitized`.

3. **Result:** An object identical to the original before sanitization, with no internal metadata leakage.

#### Integration in Load Functions

**`st_load()`:**
- After reading the artifact with the format-specific reader, calls `.st_restore_sanitized_object(res)` to restore original attributes.
- Attaches additional metadata (pk, schema, domain) from the sidecar.
- Performs optional integrity checks (file hash, content hash).

**`st_load_version()`:**
- Reads a specific version from the snapshot directory.
- Calls `.st_restore_sanitized_object(res)` to restore attributes.
- Attaches metadata from the version's sidecar.

### Important Algorithmic and Design Choices

1. **Compact Row.Names Representation:**
   - Using `.set_row_names(as.integer(NROW(x)))` ensures R uses the compact form `c(NA, -n)` internally, reducing memory and avoiding unnecessary expansions.

2. **Attribute Preservation:**
   - Sanitization stores original attributes in temporary internal attributes (`st_original_rownames`, `st_original_format`).
   - Restoration removes these internal attributes to prevent leakage into user code.

3. **data.table Handling:**
   - data.table objects are converted to data.frame for hashing (to ignore data.table-specific metadata).
   - Restoration uses `data.table::setDT()` to convert back in-place, preserving keys and other data.table structures.

4. **Idempotency:**
   - `.st_restore_sanitized_object()` safely handles objects that were never sanitized (no-op if attributes are missing).

### Performance Considerations

1. **Efficient Restoration:**
   - Restoration is designed to avoid deep copies. For data.table, `setDT()` modifies in-place.
   - Attribute manipulation is lightweight (metadata only, not data).

2. **Performance Test:**
   - A dedicated test validates that restoring a 10,000-row data.table completes in < 0.1 seconds, ensuring no deep copies occur.

3. **Hash Stability:**
   - Normalizing row.names to compact form reduces hash computation overhead and prevents spurious hash differences.

---

## 3. Plain-Language Overview

### Why the Code Exists

When saving and loading R objects (especially data.frames and data.tables), the `stamp` package needs to:
1. **Hash the content** to detect changes and decide whether to create a new version.
2. **Store the object** on disk in a normalized form.
3. **Restore the object** exactly as it was when loaded.

Before this refactor, the restoration logic was duplicated in two places (`st_load()` and `st_load_version()`), making the code harder to maintain and prone to inconsistencies.

This task consolidates the restoration logic into a single helper function, ensuring that both load functions restore objects identically and that the code is easier to test and debug.

### How a Teammate Should Use It

**For End Users:**
- No changes to the public API. `st_save()` and `st_load()` work exactly as before.
- Objects are saved and restored with full fidelity (custom row.names, data.table class, etc.).

**For Developers:**
- When adding new load paths or modifying the save/load cycle, use `.st_restore_sanitized_object()` to restore objects after deserialization.
- Use `.st_has_custom_rownames()` if you need to detect whether row.names should be preserved in new contexts.
- The test suite in `tests/testthat/test-restoration-helpers.R` provides examples and coverage for typical and edge-case scenarios.

### Non-Technical Explanation of the Behavior

Imagine you have a spreadsheet with row labels. Sometimes those labels are just numbers (1, 2, 3, ...), and sometimes they're custom names ("Alice", "Bob", "Charlie").

When `stamp` saves the spreadsheet, it needs to:
1. **Detect** whether the row labels are custom or just automatic numbers.
2. **Store** the labels if they're custom (so they can be restored later).
3. **Restore** the labels when loading, so the spreadsheet looks exactly like it did before saving.

Before this task, the code for detecting and restoring labels was written twice (in two different functions). Now, it's written once and shared, so it's easier to maintain and less likely to have bugs.

---

## 4. Documentation and Comments

### Confirmation of In-Code Comments and Roxygen2 Docs

1. **Helper Functions:**
   - `.st_restore_sanitized_object()`: Documented with Roxygen2 comments explaining purpose, parameters, and return value.
   - `.st_has_custom_rownames()`: Documented with Roxygen2 comments explaining the detection logic and edge cases.

2. **Sanitization Function:**
   - `st_sanitize_for_hash()`: Updated comments clarify the use of `.set_row_names(as.integer(NROW(x)))` for compact representation.

3. **Test Suite:**
   - Each test block includes a descriptive `test_that()` label explaining what is being validated.
   - Complex tests (e.g., long row.names with suffix) include inline comments explaining the expected behavior.

### Important Notes for Future Maintainers

1. **Default Row.Names Representations:**
   - R can represent default row.names in multiple ways internally:
     - Compact: `c(NA, -n)` (integer vector of length 2)
     - Expanded (integer): `1:n` (integer vector of length n)
     - Expanded (character): `c("1", "2", ..., "n")` (character vector of length n)
   - `.st_has_custom_rownames()` must recognize all of these as default to avoid false positives.
   - If R's internal behavior changes in future versions, this function may need adjustment.

2. **data.table Restoration:**
   - When restoring data.table objects, use `data.table::setDT()` for in-place conversion.
   - Do not use `data.table::as.data.table()`, which creates a copy.

3. **Attribute Cleanup:**
   - Always remove internal attributes (`st_original_rownames`, `st_original_format`, `stamp_sanitized`) after restoration to prevent leakage into user code.

4. **Test Isolation:**
   - Integration tests must use fresh temporary directories to avoid artifact reuse, which causes `st_save()` to skip and return no `version_id`.
   - Use `td <- withr::local_tempdir(); withr::local_dir(td)` before `st_init(".")`.

---

## 5. Validation Bundle

### Validation Checklist

- [x] **Helper Functions:**
  - [x] `.st_has_custom_rownames()` correctly identifies default row.names across all internal representations.
  - [x] `.st_has_custom_rownames()` correctly identifies custom row.names (character, non-sequential numeric).
  - [x] `.st_restore_sanitized_object()` restores data.frame objects with custom row.names.
  - [x] `.st_restore_sanitized_object()` restores data.table objects.
  - [x] `.st_restore_sanitized_object()` handles default row.names (no preservation needed).

- [x] **Sanitization:**
  - [x] `st_sanitize_for_hash()` uses compact row.names representation for default row.names.
  - [x] `st_sanitize_for_hash()` preserves custom row.names in `st_original_rownames` attribute.
  - [x] `st_sanitize_for_hash()` converts data.table to data.frame and stores original class.

- [x] **Integration:**
  - [x] `st_save()` + `st_load()` round-trip: tested with data.frames with custom row.names
  - [x] `st_save()` + `st_load_version()` round-trip: tested with data.table objects
  - [x] Both functions preserve all object types correctly
  - [x] No internal attributes leak to user code

- [x] **Edge Cases:**
  - [x] Empty data.frames (0 rows, 0 columns).
  - [x] Single-row data.frames.
  - [x] Very long row.names (1500+ characters).
  - [x] Special characters in row.names (dashes, dots, underscores).
  - [x] Non-data.frame objects (vectors, lists) handled gracefully.

- [x] **Performance:**
  - [x] Restoration of large data.table (10,000 rows) completes in < 0.1 seconds.

### Unit Tests and Edge Cases

**Test File:** `tests/testthat/test-restoration-helpers.R`

**Coverage:**

1. **Helper Function Tests (`.st_has_custom_rownames()`):**
   - Default row.names (integer sequence): `expect_false()`
   - Custom character row.names: `expect_true()`
   - Custom numeric row.names (non-sequential): `expect_true()`
   - Empty data.frame: `expect_false()`
   - Single-row data.frame (default): `expect_false()`
   - Single-row data.frame (custom): `expect_true()`

2. **Helper Function Tests (`.st_restore_sanitized_object()`):**
   - data.frame with custom row.names: `expect_identical(restored, original)`
   - data.table: `expect_s3_class(restored, "data.table")`
   - Default row.names: No `st_original_rownames` attribute
   - Empty data.frames (0 rows, 0 cols; cols but no rows)
   - Single-row data.frames
   - Non-data.frame objects (vectors, lists)
   - Objects with missing attributes (graceful handling)
   - data.table with keys (preservation)
   - Numeric row.names (stored as character)

3. **Round-Trip Tests:**
   - mtcars, iris, custom row.names, single-col, single-row data.frames
   - Sanitize → Restore → `expect_identical(restored, original)`
   - No internal attribute leakage

4. **Integration Tests:**
   - `st_save()` + `st_load()` with custom row.names
   - `st_save()` + `st_load_version()` with data.table
   - Version ID validation (guard against NULL)

5. **Edge Case Tests:**
   - Very long row.names (1500+ characters with suffix)
   - Special characters in row.names (dashes, dots, underscores)

6. **Performance Tests:**
   - Large data.table (10,000 rows) restoration in < 0.1 seconds

### Error-Handling Strategy

1. **Invalid Inputs:**
   - `.st_has_custom_rownames()`: Returns `FALSE` for non-data.frame objects (graceful degradation).
   - `.st_restore_sanitized_object()`: No-op for objects without sanitization attributes (idempotent).

2. **Missing Attributes:**
   - Restoration handles missing `st_original_rownames` or `st_original_format` gracefully (checks for `NULL` before restoring).

3. **Format Dependency:**
   - Integration tests using `.qs2` format were switched to `.rds` to avoid dependency on `qs2` package in test environments.
   - A guard assertion (`expect_true(!is.null(version_id) && nzchar(version_id))`) ensures `st_save()` produced a valid version ID before calling `st_load_version()`.

4. **Test Isolation:**
   - Integration tests use fresh temporary directories to prevent artifact reuse and `st_save()` skips.

### Performance-Sensitive Tests

- **Test:** "Performance: Restoration is efficient (no deep copies)"
- **Setup:** 10,000-row data.table with three columns.
- **Validation:** Restoration completes in < 0.1 seconds.
- **Purpose:** Ensure `.st_restore_sanitized_object()` uses in-place operations (e.g., `data.table::setDT()`) and does not create deep copies.

---

## 6. Dependencies and Risk Analysis

### Summary of Dependency Decisions

1. **Core Dependencies:**
   - `data.table`: Required for data.table restoration (`setDT()`).
   - `withr`: Used for test isolation (`local_tempdir()`, `local_dir()`, `defer()`).
   - `testthat`: Test framework.
   - `cli`: For user-facing messages (unchanged).

2. **Optional Dependencies:**
   - `qs2`: Not required for core functionality; tests switched to `rds` format to avoid dependency.

3. **Internal Functions:**
   - `.set_row_names()`: Base R function for setting compact row.names representation.

### Key Security and Stability Considerations

1. **Attribute Leakage:**
   - **Risk:** Internal attributes (`st_original_rownames`, `st_original_format`, `stamp_sanitized`) could leak into user code if restoration is incomplete.
   - **Mitigation:** `.st_restore_sanitized_object()` explicitly removes all internal attributes after restoration. Tests validate no leakage.

2. **Hash Stability:**
   - **Risk:** Spurious hash changes due to different row.names representations could cause unnecessary version creation.
   - **Mitigation:** Normalize default row.names to compact form using `.set_row_names(as.integer(NROW(x)))`. Detection logic treats all default representations equivalently.

3. **data.table Modification:**
   - **Risk:** `setDT()` modifies objects in-place, which could cause unexpected side effects if used incorrectly.
   - **Mitigation:** Only used during restoration, where in-place modification is intended and expected.

4. **Test Reliability:**
   - **Risk:** Tests could fail due to artifact reuse or environment contamination.
   - **Mitigation:** Integration tests use fresh temporary directories and cleanup fixtures.

5. **R Version Compatibility:**
   - **Risk:** Internal row.names representation may change in future R versions.
   - **Mitigation:** `.st_has_custom_rownames()` is designed to handle multiple representations. If R changes, this function can be updated centrally.

---

## 7. Self-Critique and Follow-Ups

### Main Issues Uncovered by Reviews and Self-Critique

1. **Duplicated Restoration Logic (Identified):**
   - **Issue:** `st_load()` and `st_load_version()` had identical restoration code.
   - **Resolution:** Consolidated into `.st_restore_sanitized_object()`.

2. **Default Row.Names Representation Inconsistency (Identified):**
   - **Issue:** R's internal representation of default row.names can vary (compact vs. expanded).
   - **Resolution:** `.st_has_custom_rownames()` treats all default representations equivalently. Sanitization uses `.set_row_names(as.integer(NROW(x)))` for compact form.

3. **Test Failures Due to Artifact Reuse (Identified):**
   - **Issue:** Integration tests failed when artifacts already existed in the working directory, causing `st_save()` to skip and return no `version_id`.
   - **Resolution:** Use fresh temporary directories (`withr::local_tempdir()` + `withr::local_dir()`).

4. **qs2 Dependency in Tests (Identified):**
   - **Issue:** Tests used `.qs2` format, which requires the `qs2` package. In environments without `qs2`, `st_save()` returned `NULL` for `version_id`.
   - **Resolution:** Switched test artifacts to `.rds` format (base R).

5. **Deprecated Teardown (Identified):**
   - **Issue:** Test cleanup used deprecated `teardown()` function.
   - **Resolution:** Replaced with `withr::defer(..., testthat::teardown_env())`.

### Remaining TODOs and Recommended Future Improvements

1. **Comprehensive Format Testing:**
   - **TODO:** Add integration tests for all supported formats (`csv`, `fst`, `json`) to ensure restoration works universally.
   - **Priority:** Medium (current tests cover `rds` and data.table; other formats likely work but should be validated).

2. **Documentation of Row.Names Behavior:**
   - **TODO:** Add a vignette or user guide explaining how `stamp` handles row.names during save/load.
   - **Priority:** Low (behavior is correct and tested; documentation would help advanced users).

3. **Benchmarking:**
   - **TODO:** Add benchmarks for sanitization and restoration on very large datasets (1M+ rows) to validate performance at scale.
   - **Priority:** Low (current performance test covers 10k rows; scaling is expected to be linear).

4. **R Version Testing:**
   - **TODO:** Test on multiple R versions (e.g., R 4.0, 4.1, 4.2, 4.3) to ensure row.names handling is consistent.
   - **Priority:** Medium (important for CRAN submission).

5. **Fuzzing Tests:**
   - **TODO:** Add property-based tests (e.g., using `quickcheck` or similar) to validate that sanitize → restore is always a no-op for arbitrary data.frames.
   - **Priority:** Low (current tests cover many edge cases; fuzzing would provide additional confidence).

6. **Error Messages:**
   - **TODO:** Review and improve error messages if restoration fails (e.g., due to corrupted metadata or unexpected attribute values).
   - **Priority:** Low (current implementation is defensive; errors are unlikely in normal use).

7. **Code Coverage:**
   - **TODO:** Run `covr::package_coverage()` to ensure all branches in `.st_restore_sanitized_object()` and `.st_has_custom_rownames()` are exercised by tests.
   - **Priority:** Medium (tests are comprehensive, but formal coverage report would confirm).

---

## Conclusion

This task successfully refactored the restoration logic in the `stamp` package, eliminating code duplication and improving maintainability. The new helper functions (`.st_restore_sanitized_object()` and `.st_has_custom_rownames()`) are well-tested, efficient, and handle edge cases robustly.

All integration tests pass, and the code is ready for production use. Future work should focus on expanding format coverage, adding benchmarks for very large datasets, and ensuring compatibility across R versions.

**Next Steps:**
- Consider adding the recommended follow-ups (format testing, benchmarking, R version testing) in future iterations.
- Update package documentation and NEWS.md to reflect the refactor.
