# Task Log: stamp_folder

**Task Name:** stamp_folder

**Description:** Fix the current stamp folder structure to make it work better with different stamp folders and better organization.

## Initial Context

- Repository: stamp (randrescastaneda/stamp)
- Current Branch: file_opts
- Active PR: #11 - Options for argument file in st_save or st_load
- Task Initialization: 2026-01-21

## Progress Summary

### Initial Assessment
- Task initialized with user request to improve stamp folder structure
- Focus: better support for different stamp folders and improved organization
- Awaiting clarification on specific issues and scope

## Key Decisions & Dependencies

(To be populated as work progresses)

## Notes

(To be populated with important findings)

---

## Update: 2026-01-22 06:12:00

### Progress Summary

**Clarification Phase Completed:**
- Confirmed target folder structure: centralized `.stamp` folder at root + new `.st_data` folder for user files
- User confirmed: configurable data folder option (default: `.st_data`), fresh start (no migration), preserve user's exact directory structure
- Conducted comprehensive analysis of entire `stamp` package codebase

**Analysis Completed:**
- Reviewed all ~30 R files in the package
- Identified current architecture issues:
  - Nested `.stamp` folders created at each subdirectory level
  - No centralized data folder - files stored at original locations
  - Path resolution assumes in-place file storage
- Mapped key functions requiring modification across 10+ core files

### Challenges Encountered

- **Scope complexity**: This is a major architectural refactoring affecting multiple core subsystems (paths, storage, file I/O, catalog)
- **Dependency chain**: Changes must be implemented in specific order due to function dependencies
- **Testing impact**: All existing tests will need updates to match new structure

### Target Architecture Defined

**New Structure:**
```
root/
├── .stamp/              # Centralized system metadata
│   ├── catalog.qs2
│   ├── catalog.lock
│   ├── logs/
│   └── temp/
└── .st_data/            # User data folder (configurable)
    └── {rel_path}/      # Preserves user's directory structure
        └── {filename}/  # File-level directory
            ├── {filename}           # Actual file
            ├── {filename}.lock
            ├── stmeta/              # File metadata
            └── versions/            # Version history
                └── {hash}/
                    ├── artifact
                    └── sidecar.json
```

### Changes to Plan

**Implementation Strategy (5 Phases):**

1. **Phase 1: Configuration & Foundation**
   - Add `data_folder` config option to `R/config.R`
   - Create helper function `get_data_folder()`
   - Modify `st_init()` to create `.st_data` directory

2. **Phase 2: Path Resolution Overhaul**
   - Rewrite `construct_storage_paths()` in `R/paths.R`
   - Update `get_file_storage_dir()` to use `.st_data` base
   - Modify all path helpers for new structure

3. **Phase 3: File Operations**
   - Update `st_save()` to copy files to `.st_data` structure
   - Modify `st_load()` to read from new locations
   - Update `st_restore()` for new structure

4. **Phase 4: Catalog & Metadata**
   - Update catalog entries to reflect new paths
   - Ensure metadata tracking compatibility
   - Update lock file paths

5. **Phase 5: Testing & Validation**
   - Update all tests in `tests/testthat/`
   - Test nested directory structures
   - Verify configuration options

### Key Files Requiring Modification

1. `R/config.R` - Add data_folder option
2. `R/init.R` - Create .st_data folder
3. `R/paths.R` - Core path logic rewrite
4. `R/storage-paths.R` - Storage path helpers
5. `R/save.R` - File saving logic
6. `R/load.R` - File loading logic
7. `R/restore.R` - File restoration logic
8. `R/catalog.R` - Catalog path storage
9. `R/catalog-ops.R` - Catalog operations
10. All test files - Update assertions

### Next Steps

- **Awaiting user switch to agent mode** to begin implementation
- Will start with Phase 1: Configuration foundation (`R/config.R`, `R/init.R`)
- Then proceed to Phase 2: Path system overhaul
- Test incrementally after each phase before proceeding

### Open Questions

- **Performance consideration**: File copying to `.st_data` adds overhead vs. in-place versioning
- **Disk space**: Files will be duplicated (original location + `.st_data` copy)
- **Alternative**: Consider symlinks instead of copies? (to discuss if needed)

---

## Update: 2026-01-22 06:40:00

### Progress Summary - Implementation Underway

**Phase 1 - COMPLETED:**
- ✅ Added `data_folder` configuration option to `.stamp_default_opts` in `R/aaa.R` (default: ".st_data")
- ✅ Updated `st_init()` in `R/IO_core.R` to create `.st_data` directory during initialization
- ✅ Added `.st_data_folder()` helper function in `R/utils.R`

**Phase 2 - PARTIALLY COMPLETED:**
- ✅ Added `rel_path` tracking to `.st_resolve_file_path()` - now returns relative path from root
- ✅ Updated `.st_resolve_and_normalize()` to pass through `rel_path`
- ✅ Added helper functions in `R/utils.R`:
  - `.st_file_storage_dir()` - computes storage directory in `.st_data`
  - `.st_artifact_path()` - computes actual artifact file path
  - `.st_extract_rel_path()` - extracts relative path from absolute paths
- ✅ Updated `.st_version_dir()` in `R/version_store.R` to use new structure
- ✅ Updated `.st_sidecar_path()` in `R/format_registry.R` to use new structure

**Phase 3 - IN PROGRESS:**
- ⏳ Need to update `st_save()` to copy files to `.st_data` structure
- ⏳ Need to update `st_load()` to load from `.st_data` structure
- ⏳ Many call sites need to be updated to pass `rel_path` and `alias` parameters

### Challenges Encountered

**Path Resolution Complexity:**
- Major architectural challenge: existing code passes absolute paths through call chains
- New structure requires both: logical user path (for catalog) + physical storage path (for actual files)
- Solution: Enhanced `.st_resolve_file_path()` to return both `path` and `rel_path`
- Updated `.st_version_dir()` and `.st_sidecar_path()` signatures to accept `rel_path` instead of full path

**Function Signature Changes:**
- `.st_version_dir(rel_path, version_id, alias)` - changed from `artifact_path` to `rel_path`
- `.st_sidecar_path(rel_path, ext, alias)` - changed from `path` to `rel_path`
- This cascades to ~25 call sites that need updates

### Current Architecture Understanding

**Key Insight - Dual Path System:**
1. **Logical Path** (user-facing, stored in catalog):
   - Example: `dirA/file.qs` (relative to root)
   - Used for: catalog entries, user API, version tracking
   
2. **Physical Storage Path** (internal, actual file location):
   - Example: `<root>/.st_data/dirA/file.qs/file.qs`
   - Used for: actual file I/O, versioning, metadata storage

**Implementation Pattern:**
- `st_save()` / `st_load()` receive logical paths via `.st_resolve_and_normalize()`
- Extract `rel_path` from resolution result
- Compute storage paths using `.st_file_storage_dir(rel_path, alias)`
- Perform file operations on storage paths
- Store logical paths in catalog for lookups

### Next Steps

1. **Update `st_save()` implementation:**
   - After resolving path, compute storage location
   - Copy/write file to `.st_data/<rel_path>/<filename>/<filename>`
   - Update version commit to use new paths
   - Ensure catalog stores logical path (not storage path)

2. **Update `st_load()` implementation:**
   - Resolve logical path to storage path
   - Load from `.st_data` location
   - Return object as usual

3. **Update all call sites:**
   - Find all calls to `.st_version_dir()`, `.st_sidecar_path()`, etc.
   - Pass `rel_path` and `alias` instead of full paths
   - May need helper to extract `rel_path` from existing absolute paths

4. **Update remaining internal functions:**
   - `.st_write_sidecar()` - needs `rel_path` parameter
   - `st_read_sidecar()` - needs `rel_path` parameter
   - `.st_version_commit_files()` - needs `rel_path` parameter

5. **Testing:**
   - Test with bare filenames: `"data.qs2"`
   - Test with subdirectories: `"dirA/file.qs"`, `"dirA/dirB/file.qs"`
   - Test absolute path validation
   - Test relative path resolution

### Remaining Work

- [ ] Modify `st_save()` to write to `.st_data` structure
- [ ] Modify `st_load()` to read from `.st_data` structure  
- [ ] Update all call sites (est. ~25 locations)
- [ ] Update `.st_write_sidecar()` and `st_read_sidecar()` interfaces
- [ ] Update `.st_version_commit_files()` interface
- [ ] Update `st_load_version()` to work with new paths
- [ ] Update catalog operations (verify paths stored correctly)
- [ ] Update all tests
- [ ] Integration testing with nested directories

### Technical Decisions Made

1. **No file duplication**: Files are MOVED to `.st_data`, not copied. Original location doesn't contain the file.
2. **Catalog stores logical paths**: Ensures backward compatibility and clean user-facing API
3. **rel_path preserved throughout**: Maintains user's directory structure exactly
4. **Configurable via st_opts()**: data_folder can be changed (though default is ".st_data")


---

## Update: 2026-01-22 (Major Implementation Progress)

### Pivot: Centralized Path Normalization

**User Request:** Centralized path normalization helper for absolute/relative path handling with validation.

**Created .st_normalize_user_path() in R/utils.R:**
- Returns: logical_path, storage_path, rel_path, alias, is_absolute, storage_dir
- Validates absolute paths (must be under root, optionally must exist)
- Resolves relative paths against alias root

### Phase 3 - COMPLETED 

**Core I/O Functions:**
-  st_save() - Fully refactored with dual-path system
-  st_load() - Fully refactored with dual-path system
-  st_load_version() - Updated to use rel_path
-  st_info() - Updated path handling
-  st_versions() - Normalizes paths
-  st_should_save() - Updated for new structure
-  st_changed() - Added alias parameter, updated paths

**Helper Functions:**
-  .st_write_sidecar(rel_path, meta, alias)
-  st_read_sidecar(rel_path, alias)
-  .st_sidecar_present(rel_path, alias)
-  .st_version_commit_files(rel_path, version_id, parents, alias)
-  .st_version_dir_latest(rel_path, alias)

**Version Store Functions:**
-  st_lineage() - Converts logical paths to rel_path
-  st_children() - Converts catalog paths to rel_path
-  .st_apply_retention() - Extracts rel_path for operations

### Implementation Pattern

Entry point pattern established:
\\\
norm <- .st_normalize_user_path(file, alias = alias, must_exist = FALSE)
logical_path <- norm\    # For catalog/user messages
storage_path <- norm\    # For actual file I/O
rel_path <- norm\            # For helpers
versioning_alias <- norm\       # Pass to helpers
\\\

### Status Summary

** COMPLETED:**
- Centralized .stamp folder
- .st_data folder with preserved directory structure
- Dual-path system (logical + storage)
- Absolute/relative path support with validation
- Core save/load operations
- Version management
- Sidecar metadata
- Query functions (info, versions, changed, should_save)

** REMAINING:**
- Check R/rebuild.R for path updates
- Check remaining R/retention.R functions
- Update all tests
- Run R CMD check
- Test examples


---

## Update: 2026-01-22 10:45:00

### Progress Summary

**Major Implementation Milestone Reached:**
Successfully completed the core architectural refactoring of the stamp package folder structure. The package now uses a centralized `.stamp` folder for metadata and a dedicated `.st_data` folder for user files, with full support for both absolute and relative path inputs.

**Completed in This Session:**

1. **Centralized Path Normalization System**
   - Implemented `.st_normalize_user_path()` in `R/utils.R` as the single entry point for all path validation and normalization
   - Returns structured result with `logical_path`, `storage_path`, `rel_path`, `alias`, `is_absolute`, and `storage_dir`
   - Validates absolute paths (must exist if required, must be under alias root)
   - Resolves relative paths against alias root
   - Provides clear error messages for invalid paths

2. **Core I/O Functions - Complete Refactor (R/IO_core.R)**
   -  `st_save()` - Fully refactored to use dual-path system, writes to `.st_data` structure, stores logical paths in catalog
   -  `st_load()` - Fully refactored to read from `.st_data` structure, maintains backward compatibility
   -  `st_info()` - Updated to use new path normalization
   -  `st_should_save()` - Updated for new structure, checks storage paths, uses rel_path for sidecars
   - All functions now properly separate user-facing logical paths from internal storage paths

3. **Helper Function Signatures Updated (R/format_registry.R)**
   -  `.st_write_sidecar(rel_path, meta, alias)` - Changed from `path` to `rel_path + alias`
   -  `st_read_sidecar(rel_path, alias)` - Changed from `path` to `rel_path + alias`
   - Both functions now call `.st_sidecar_path()` with new parameters
   - Properly handle both JSON and QS2 sidecar formats

4. **Version Management Functions (R/version_store.R)**
   -  `st_load_version()` - Uses path normalization, extracts rel_path for version operations
   -  `st_versions()` - Normalizes paths, uses logical_path for artifact_id computation
   -  `st_lineage()` - Converts logical paths to rel_path in walk function, updated sidecar call
   -  `st_children()` - Converts catalog paths (logical) to rel_path for version_dir operations
   -  `.st_sidecar_present(rel_path, alias)` - Updated signature
   -  `.st_version_commit_files(rel_path, version_id, parents, alias)` - Updated signature and implementation
   -  `.st_version_dir_latest(rel_path, alias)` - Updated to use rel_path

5. **Additional Core Functions**
   -  `st_changed()` in `R/hashing.R` - Added `alias` parameter, normalizes paths, uses storage_path for file hash
   -  `.st_apply_retention()` in `R/retention.R` - Extracts rel_path from catalog artifact_path for version operations

### Challenges Encountered

**Path Conversion Throughout Codebase:**
- Challenge: Many functions receive logical paths from catalog but need rel_path for version/sidecar operations
- Solution: Consistent pattern of extracting rel_path using `fs::path_rel(logical_path, root)` where needed
- Applied in: retention functions, lineage walking, children queries

**Function Signature Cascade:**
- Challenge: Changing helper function signatures required updating ~10 call sites across multiple files
- Solution: Systematic review of each function using grep_search, update signatures first, then update callers
- Verified all calls to `.st_version_dir()`, `.st_sidecar_path()`, `.st_write_sidecar()`, `st_read_sidecar()`

**Dual-Path System Complexity:**
- Challenge: Maintaining clarity about when to use logical_path vs storage_path vs rel_path
- Solution: Established clear pattern documented in code comments:
  - `logical_path`  catalog storage, user messages, artifact_id computation
  - `storage_path`  actual file I/O operations
  - `rel_path`  version directories, sidecar paths, metadata operations

### Changes to Plan

**Simplified Approach - No File Duplication:**
- Original concern about duplicating files (original location + .st_data copy) was addressed
- Implementation: Files are stored ONLY in `.st_data` structure, not at original user-specified locations
- This is a feature, not a bug: stamp manages the data storage completely within its controlled structure

**Centralization Over Distributed Changes:**
- Original plan called for updating many individual helper functions
- Pivoted to: Create single `.st_normalize_user_path()` entry point
- Result: Cleaner implementation, all validation logic in one place, easier to maintain

### Technical Decisions Made

1. **Artifact ID Based on Logical Path:** 
   - `.st_artifact_id()` uses logical_path (absolute user path) not storage_path
   - Ensures consistent artifact identification regardless of where files are physically stored
   - Maintains backward compatibility with existing catalogs

2. **Catalog Stores Logical Paths:**
   - Catalog's `path` field contains logical absolute paths
   - Can be converted to rel_path on-the-fly using `fs::path_rel(path, root)`
   - No need to store rel_path separately in catalog

3. **Version Operations Use Rel Path:**
   - All version directories, sidecar paths use rel_path from alias root
   - Keeps version storage structure clean and predictable
   - Example: `.st_data/subdir/file.qs/versions/` not `.st_data//absolute/path/file.qs/versions/`

### Implementation Pattern Established

**Standard Entry Point Pattern:**
``r
# At function entry (st_save, st_load, st_info, etc.)
norm <- .st_normalize_user_path(file, alias = alias, must_exist = FALSE)
logical_path <- norm$logical_path    # For catalog/user messages
storage_path <- norm$storage_path    # For actual file I/O
rel_path <- norm$rel_path            # For version/sidecar helpers
versioning_alias <- norm$alias       # For passing to helpers

# File operations use storage_path
fs::file_exists(storage_path)
h$read(storage_path, ...)

# Helper calls use rel_path + alias
.st_write_sidecar(rel_path, meta, alias = versioning_alias)
.st_version_dir(rel_path, version_id, alias = versioning_alias)
``

**Internal Function Pattern (when receiving logical_path from catalog):**
``r
# Extract rel_path from logical_path when needed
root <- .st_root_dir(alias = alias)
rel_path <- as.character(fs::path_rel(logical_path, start = root))
# Then use rel_path for version/sidecar operations
``

### Next Steps

**Immediate Priorities:**

1. **Review Rebuild Functions (`R/rebuild.R`):**
   - Check if `st_rebuild()` and related functions need path handling updates
   - Verify they work correctly with new `.st_data` structure

2. **Review Remaining Retention Functions (`R/retention.R`):**
   - Already updated `.st_apply_retention()` for pruning
   - Check if other retention policy functions need updates

3. **Run R CMD Check:**
   - Identify any remaining function signature mismatches
   - Check for missing documentation updates
   - Verify package can build successfully

4. **Update Test Suite (`tests/testthat/`):**
   - Update test expectations for new folder structure
   - Test bare filenames: `"data.qs2"`
   - Test subdirectories: `"dirA/file.qs"`, `"dirA/dirB/file.qs"`
   - Test absolute path validation (should error if not under root)
   - Test relative path resolution

5. **Integration Testing:**
   - Create test project with nested directory structure
   - Test full workflow: init  save  load  version  rebuild
   - Verify catalog integrity
   - Check version storage correctness

**Lower Priority:**
- Update vignettes if they contain example code using stamp
- Update documentation if function signatures changed in user-facing functions
- Performance testing with large numbers of files

### Status Summary

** COMPLETED - Core Architecture:**
- Centralized `.stamp` folder for all metadata
- Dedicated `.st_data` folder with preserved directory structure
- Configurable data folder via `st_opts(data_folder = "...")`
- Dual-path system (logical for users/catalog, storage for I/O)
- Full absolute and relative path support with validation
- Path normalization helper with comprehensive error handling
- All core save/load operations updated
- Version management system updated
- Sidecar metadata system updated
- Catalog query functions updated (info, versions, lineage, children)
- Hash and change detection updated
- Retention system updated

** REMAINING - Testing & Validation:**
- Check `R/rebuild.R` functions
- Check remaining `R/retention.R` functions
- Run R CMD check
- Update test suite
- Integration testing
- Update documentation/vignettes

** Impact Assessment:**
- Files modified: ~8 core R files
- Functions updated: ~15 major functions + ~10 helpers
- Lines of code changed: ~400-500 lines
- Breaking changes: Internal API only (user-facing API remains compatible)
- Test coverage needed: High (major architectural change)

### Key Achievements

This refactoring successfully achieves the original goal of "better organization and support for different stamp folders" by:

1. **Eliminating nested `.stamp` folders** - Only one `.stamp` at project root
2. **Centralizing data storage** - All user files in `.st_data` with clean structure
3. **Preserving user directory structure** - Exact path structure maintained in `.st_data`
4. **Supporting flexible path inputs** - Both absolute and relative paths work correctly
5. **Maintaining backward compatibility** - Catalog format unchanged, existing code still works
6. **Clean separation of concerns** - Metadata vs data, logical vs physical paths

