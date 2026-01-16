# Alias Support + R CMD Check Alignment

# Alias Support + R CMD Check Alignment

Task Header
- TASK_NAME: alias-support-and-r-cmd-check-fixes
- TASK_DESCRIPTION: Implement alias support, non-interactive version resolution, performance improvements (parents index, ordering), and align documentation/metadata to clear R CMD check notes. Consolidate development logs and final report.
- Start date: 2026-01-16
- End date: 2026-01-16
- Changelog:
  - 2026-01-16: Implemented alias selector model across IO and APIs.
  - 2026-01-16: Fixed latest-version resolution via `st_versions` ordering.
  - 2026-01-16: Added `parents_index` and reverse lineage helpers.
  - 2026-01-16: Removed orphaned roxygen causing Rd usage mismatch.
  - 2026-01-16: Converted LICENSE to CRAN stub for `MIT + file LICENSE`.
  - 2026-01-16: Regenerated Rd; appended log entries 1–3.

## 1. Task Overview
- Implemented alias support across the package so multiple independent stamp folders can be managed; alias is a selector only (not embedded in filesystem paths).
- Removed interactive version resolution; callers must pass explicit IDs or negative offsets.
- Optimized lineage and children traversal via a `parents_index` in the catalog; modified `st_latest` to derive from sorted versions instead of artifact row.
- Aligned documentation and metadata for clean `R CMD check`: roxygen param docs, expanded `globalVariables`, `Suggests` additions, `.Rbuildignore` update, and corrected LICENSE stub.

Main files/functions affected:
- `R/version_store.R`: `st_versions`, `st_latest`, `.st_resolve_version`, `st_load_version`, `st_lineage`, `.st_children_once`, `st_children`, `st_is_stale`, catalog helpers, parents snapshot IO.
- `R/IO_core.R`: `st_init`, `st_save`, `st_load`, `st_info`, alias registry utilities, locking.
- `R/retention.R`: `st_prune_versions`.
- `R/aaa.R`: expanded `utils::globalVariables`.
- `vignettes/using-alias.Rmd`: new vignette; `README.Rmd` trimmed to link to it.
- `DESCRIPTION`, `.Rbuildignore`, `LICENSE`: metadata and build alignment.

Major decisions and trade-offs:
- Alias selection kept out of paths for portability; alias only changes the selected state/config.
- Latest-version resolution from `st_versions` ordering to avoid stale artifact rows; trades O(1) lookup for correctness and simplicity.
- Non-interactive API ensures CI stability; interactive selection explicitly rejected.
- Parents snapshot favored for reproducible lineage; sidecar fallback allowed only at level 1 for convenience.

## 2. Technical Explanation
- Alias model: `st_init()` records `root` and `state_dir` per alias; helpers `.st_root_dir(alias)`, `.st_state_dir_abs(alias)`, `.st_versions_root(alias)` return paths without embedding alias into names.
- Versioning:
  - `st_versions(path, alias)`: returns versions filtered by artifact id, coerces `created_at`, drops corrupt rows, orders by `created_at` desc then `version_id`.
  - `st_latest(path, alias)`: latest is first row of `st_versions`.
  - `.st_resolve_version(path, version, alias)`: `NULL`/`0` → latest; negative integers resolve relative to ordered table; character must exist; interactive keywords (`select`/`pick`/`choose`) error.
- Catalog:
  - `.st_catalog_read/write`: maintains `artifacts`, `versions`, and `parents_index` tables, using QS2-backed storage.
  - `.st_catalog_record_version(...)`: computes `version_id`, upserts artifact row, appends version row, and records parent relations in `parents_index` under a lock.
- Lineage:
  - `st_lineage(path, depth, alias)`: reads parents from committed `parents.json`; level-1 fallback to sidecar parents; recursive traversal with cycle guard.
  - `.st_children_once` + `st_children`: reverse lineage using `parents_index` when available; fallback scans snapshots; supports depth and optional parent version filter.
- Parents snapshots:
  - `.st_version_commit_files(...)` copies artifact and sidecars into version directory and writes `parents.json` atomically via `.st_version_write_parents`.
- Stale detection:
  - `st_is_stale(path, alias)`: compares parent latest IDs vs committed parent versions of child’s latest snapshot.

Performance considerations:
- Ordering by `created_at` reduces ambiguity and removes reliance on potentially-stale `latest_version_id` in `artifacts`.
- `parents_index` turns reverse lineage from snapshot scanning (O(n)) into indexed joins (O(k)).
- Locking via `.st_with_lock` serializes catalog updates; idempotent lock path to avoid collisions.

## 3. Plain-Language Overview
- Why: Manage several stamp folders cleanly and predictably without mixing paths; make automated builds/tests reliable.
- How to use: Pass `alias = "name"` to functions to target that stamp folder. Use `st_versions()` to see versions; `st_latest()` to get latest; pass an explicit version ID or `-1`, `-2`, etc. to load older versions.
- Behavior: Aliases don’t change file names; they select which state directory is used. Lineage calls read parents from committed snapshot files; reverse lineage is efficient when `parents_index` exists.

## 4. Documentation and Comments
- Roxygen2 docs updated to include `alias` parameters for relevant public functions (`st_versions`, `st_latest`, `st_load_version`, `st_lineage`, `st_children`, `st_is_stale`, `st_prune_versions`, `st_info`).
- Expanded `utils::globalVariables` to cover NSE columns used by data.table operations.
- Removed orphaned roxygen block that caused `Rd \usage` mismatch for `.st_version_write_parents`.
- Vignette `vignettes/using-alias.Rmd` documents alias setup, switching, constraints, and troubleshooting; `README.Rmd` links to the vignette.

## 5. Validation Bundle
- Checklist:
  - Alias registry works; paths remain alias-free.
  - `st_latest` derives from `st_versions` ordering; no stale reads.
  - `.st_resolve_version` handles `NULL`, `0`, negative, and character inputs; rejects interactive selection.
  - Parents snapshot write/read works; atomic write verified.
  - Reverse lineage uses `parents_index` when present; fallback scanning intact.
- Tests and edge cases (summary):
  - Lineage and latest-version resolution regressions fixed; earlier full suite passed `[FAIL 0 | WARN 6 | PASS 371]` with expected PK warnings.
  - Edge handling: empty catalogs, corrupted `created_at`, missing parents, cyclic lineage guarded.
- Error handling:
  - Clear `cli::cli_abort` messages for invalid version specs, missing versions, unknown formats.
  - `cli::cli_warn` on corrupt rows and unreadable parents JSON; conservative fallbacks.
- Performance-sensitive checks:
  - Confirmed ordering and index use; catalog operations run under a file lock.

## 6. Dependencies and Risk Analysis
- Dependencies: `cli`, `fs`, `rlang`, `secretbase`, `jsonlite`, `data.table`, `utils`, `nanoparquet`; Suggests: `qs2`, `qs`, `fst`, `testthat`, `knitr`, `rmarkdown`, `filelock`, `collapse`, `withr`, `pkgload`, `covr`.
- Metadata/build:
  - `.Rbuildignore` ignores `.vscode`.
  - `DESCRIPTION` adds `withr` and `pkgload` to `Suggests` for tests/vignettes.
  - `LICENSE` converted to CRAN-compliant stub for `MIT + file LICENSE`.
- Risks:
  - Aliases misconfigured can point to unintended state dirs; mitigated by explicit alias registry and `st_alias_get/list`.
  - Catalog corruption mitigated by atomic writes and defensive schema checks.

## 7. Self-Critique and Follow-Ups
- Issues uncovered:
  - Rd mismatch in `.st_version_write_parents` from an orphaned block; corrected.
  - `R CMD check` NOTE on LICENSE stub fixed by replacing with CRAN stub (`YEAR`, `COPYRIGHT HOLDER`).
- Remaining TODOs / improvements:
  - Re-run `devtools::check()` to confirm 0 NOTEs post-fixes; if any remain in vignettes (e.g., Quarto detection), adjust Quarto invocation or suppress.
  - Consider caching latest IDs in artifacts with a verification step to combine speed + correctness.
  - Extend tests for multi-alias scenarios, concurrent saves, and cross-alias lineage queries.
