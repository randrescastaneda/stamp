---
date: 2026-09-30
title: "Execution report: CRAN release — unexport partitions and clear check blockers"
plan: ".cg-docs/plans/2026-09-30-cran-release-without-partitions.md"
status: in-progress
language: "R"
review-mode: "manual"
deviation-policy: "ask"
phases-total: 3
phases-completed: [1, 2, 3]
---

# Execution Report

Plan: [.cg-docs/plans/2026-09-30-cran-release-without-partitions.md](../plans/2026-09-30-cran-release-without-partitions.md)

## Run 1 — 2026-09-30

Invocation: `/cg-work` (no phase argument, `review:manual`).
User constraint: leave `~/.Renviron` untouched. Honoured — not read or modified.

Preflight: `cg-render-artifact --validate-only` → exit 0.
Roadmap: six `cran-v0-1-0-submission` features moved `planned` → `active`;
milestone derived status `in-progress`.

### Environment resolution

`devtools` and `rcmdcheck` are not installed under R-4.5.1. User approved native
equivalents: `roxygen2::roxygenise()`, `testthat::test_local()`,
`R CMD build` + `R CMD check --as-cran`. The `R CMD` route is what CRAN runs, so
acceptance criteria are met at equal or greater strictness.

The user's `~/.Rprofile` calls `set_lib_paths()`, which blanks `.Library` and
hides base packages from any subprocess. User approved `--no-init-file` on all R
invocations (plus `R_PROFILE_USER` pointed at an empty file, and `R_LIBS`
carrying both library trees, for `R CMD` calls). No user dotfile was modified.

Two missing external tools were found and installed, neither anticipated by the
plan:

- **TinyTeX** (step 5, planned).
- **`makeindex`** — not in TinyTeX's default scheme. This, not any Rd defect,
  was the true cause of the baseline PDF-manual ERROR and WARNING. Installed via
  `tinytex::tlmgr_install(c("makeindex", "xindy"))`.

`pandoc` is present only inside the RStudio install and must be **prepended** to
`PATH` (appending was insufficient) at
`C:\Program Files\RStudio\resources\app\bin\quarto\bin\tools`.

### Step log — Phase 1

| Step | Outcome | Evidence |
|------|---------|----------|
| 1. Extend `.Rbuildignore` | done | Root listing confirmed all six gaps. Tarball top level now: `build`, `DESCRIPTION`, `inst`, `LICENSE`, `man`, `NAMESPACE`, `NEWS.md`, `R`, `README.md`, `tests`, `vignettes` — nothing else. "hidden files and directories" NOTE → OK |
| 2. `DESCRIPTION` Title + Description | done | Title now `Reproducible Artifact Store with Sidecars and Version History`; Description no longer opens with "Stamp". Incoming-feasibility NOTE reduced to "New submission" alone |
| 3. Malformed roxygen in `version_store.R` | done | `man/dot-st_catalog_record_version.Rd` deleted (71 lines); 32 junk `\keyword{}` entries gone |
| 4. Escape angle brackets | done | Derived mechanically: 29 candidate lines across **8** files. 12 were already backticked (all 5 in `R/retention.R`, plus `IO_core.R:171-172,415-416`, `version_store.R:65,68`). 16 fixed. `utils.R:182` left alone — inside `@examples \dontrun{}`, verbatim. "HTML version of manual" NOTE → OK |
| 5. Install TinyTeX | done | `tinytex::is_tinytex()` → `TRUE`; PDF manual now builds |

Plan correction confirmed: the plan's file list for step 4 omitted
`R/retention.R`, and its claim that `version_store.R:68` was a false positive was
correct. Mechanical derivation was the right call.

### Check status — Phase 1 boundary

Baseline 2026-09-28: **1 ERROR, 1 WARNING, 6 NOTEs**.
After Phase 1 (R-4.5.1, tarball check): **0 ERROR, 0 WARNING, 3 NOTEs**.

| Remaining NOTE | Real? |
|---|---|
| `checking CRAN incoming feasibility` — "New submission" | Expected; this is the single allowed NOTE (V4 target) |
| `checking for future file timestamps` — "unable to verify current time" | Environment only — corporate firewall blocks the time API. Does not occur on CRAN |
| `checking top-level files` — "cannot be checked without 'pandoc'" | Environment only. **Different cause** from the baseline NOTE of the same name, which listed non-package files and is resolved |

Accepted exception: the two environment NOTEs are not package defects and cannot
be cleared on this machine. Re-confirm on a clean machine or via win-builder
before submission.

### Test baseline (captured before Phase 2 edits, for V3)

| File | Passed | Failed | Skipped |
|------|--------|--------|---------|
| `test-partitions.R` | 9 | 0 | 0 |
| `test-vignette-issues.R` | 11 | 0 | 0 |
| `test-write-parts.R` | 21 | 0 | 5 |
| **Suite total** | **394** | **0** | **7** |

## Phase 2 — Unexport the partition API (steps 6–14)

### Step log

**6. Unexport the five partition functions.** Replaced `#' @export` with
`#' @noRd` at `R/partitions.R` lines 174, 190, 265, 452, 593 (`st_part_path`,
`st_save_part`, `st_write_parts`, `st_list_parts`, `st_load_parts`). Function
bodies and `@examples` blocks untouched. `roxygen2::roxygenise()` rewrote
`NAMESPACE` and deleted the five Rd files. **`git diff --stat NAMESPACE` →
`5 deletions(-)`, zero insertions** — no Blocked-Stop.

**7. Dropped `partition_key` from `st_path()`.** Removed the formal, its
`@param`, and the returned list element in `R/IO_core.R`; retitled the block to
"Declare a path (with optional format)". Verified by grep that every surviving
`partition_key` reference in `R/` lives inside `st_write_parts()`'s manifest
construction (lines 231, 323, 386, 408, 417), confirming the plan's finding that
`test-write-parts.R:31` asserts on the manifest, not on `st_path()`.

**8. `vignettes/stamp.Rmd`.** Deleted Section 6 (lines 577–784) including the
`partition-save`, `partition-builder`, `partition-summary-build`,
`partition-summary-list`, `partition-update-cpi` and `partition-rebuild-stale`
chunks; removed outline item 6; removed the Section 7 summary bullet and
renumbered `## 7. Summary` → `## 6. Summary`. Retained the
`code_label = "aggregate_welfare_partitioned"` string literals in the Builders
section per plan. Post-edit grep confirms sections 1–6 contiguous and no orphaned
variables (`partition_keys`, `summary_parts`, `build_partition_summary` all gone).

**9. `vignettes/version_retention_prune.Rmd`.** Four edits as specified: removed
the `## Partitioned datasets (Hive-style)` section, the key-API bullet, the intro
bullet, and the "Do partition helpers change how retention works?" FAQ entry.
This vignette is evaluated, so these removals were load-bearing.

**10. `vignettes/builders-plans.Rmd`.** Removed
`## Partitioned targets and partial rebuilds` (lines 112–169) including the
`partitioned-builder` chunk.

**11. Relocated `vignettes/partitions.Rmd` → `dev/partitions.Rmd`** via `git mv`,
with a "Parked, not shipped" note at the top. Deleted the stale untracked
`doc/partitions.{html,R,Rmd}` build artifacts.

**12. `_pkgdown.yml`.** Removed the five partition entries from "Core I/O" and
the `partitions` article from "Advanced Usage". `pkgdown::check_pkgdown()` →
**"No problems found."**

**13. Partition tests rewritten to `stamp:::`.** All call sites prefixed across
`test-partitions.R`, `test-vignette-issues.R` and `test-write-parts.R`.
`test_that()` description strings left untouched. A regex sweep for unqualified
calls across `tests/**` returns zero hits.

**14. `README.Rmd` scrubbed and re-knitted.** Removed the tagline clause, the
full "Partitions (under development)" chunk (fences included), the "advanced
features like partitions" clause, the partition vignette link, and the partition
parenthetical on `st_filter`. Converted "Partitioned and Pruning Data (under
development)" to "Pruning Data", retaining `st_prune_versions`. **Also fixed two
nonexistent exports** documented alongside the partition defects:
`st_hash_code(code)` and `st_hash_file(path)` — `NAMESPACE` exports only
`st_hash_obj`. Re-knitted to `README.md`.

### Phase 2 evidence gate

| ID | Result | Evidence |
|----|--------|----------|
| V1 | **PASS** | `Select-String -Path NAMESPACE -Pattern 'part'` → 0 matches |
| V2 | **PASS** | `Get-ChildItem man -Filter '*part*'` → 0 files; roxygen reported deleting all five Rd files |
| V3 | **PASS** | 9 / 11 / 21 per file; suite 394 passed, 0 failed, 7 skipped — **identical to baseline** |
| V5 | **PASS** | Scan of `DESCRIPTION`, `README.md`, `_pkgdown.yml`, `vignettes/*.Rmd`, `man/*.Rd` returns only the retained `code_label = "aggregate_welfare_partitioned"` literal and an adjacent comment, both explicitly permitted |
| V9 | **PASS** | `R CMD INSTALL` then `R CMD build .` → `creating vignettes ... OK`. Vignettes built against `library(stamp)` with the API unexported, not via `pkgload` (constraint C6) |

### Deviations — Phase 2

None. All fourteen sub-edits landed as planned; the plan's line numbers and its
`partition_key` consumer analysis both proved accurate.

## Phase 3 — Documentation and verification (steps 15–16)

### Step log

**15. `NEWS.md` and the project charter.** Added a `## Breaking Changes` block
under `# stamp 0.0.11` recording that the five partition helpers are now
internal (behaviour unchanged, still under test, reachable via `stamp:::` with
no stability guarantee) and that `st_path()` no longer accepts `partition_key`.
Rewrote the charter `## Objective` to match the step-2 `DESCRIPTION` wording
verbatim and bumped `last-reviewed` to 2026-09-30. Confirmed by grep that no
partition *feature claim* survives in `compound-gpid.md`, `NEWS.md` or
`DESCRIPTION` — the surviving NEWS mentions are historical notes about the
change itself, which is the intent.

**16. Full verification run.** Re-baselined on R-4.5.1 against a freshly built
tarball, with `stamp.Rcheck/` removed first so no state carried over.

### Phase 3 / final evidence gate

| ID | Result | Evidence |
|----|--------|----------|
| V4 | **PASS** | `R CMD check --as-cran stamp_0.0.11.tar.gz` → **`Status: 1 NOTE`**; the sole NOTE is `checking CRAN incoming feasibility` / "New submission" |
| V6 | **PASS** | `pkgdown::build_site()` → "Finished building pkgdown site for package stamp"; 8 articles, partitions absent |
| V7 | **PASS** | Tarball top level is exactly `build`, `DESCRIPTION`, `inst`, `LICENSE`, `man`, `NAMESPACE`, `NEWS.md`, `R`, `README.md`, `tests`, `vignettes`. No `dev/`, `roadmap.json`, `compound-gpid*.md`, `.kilo`, `.quarto`, `.Rhistory` |
| V8 | **PASS** (optional) | `checking PDF version of manual ... OK` |
| V9 | **PASS** | `R CMD build .` → `creating vignettes ... OK`; the 8 shipped vignettes rebuilt through `library(stamp)` |
| V3 | **PASS** | Full suite re-run after step 15: **394 passed, 0 failed, 7 skipped** — unchanged from baseline |

### Check status — final

Baseline 2026-09-28: **1 ERROR, 1 WARNING, 6 NOTEs**.
Phase 1 boundary: **0 ERROR, 0 WARNING, 3 NOTEs**.
Final: **0 ERROR, 0 WARNING, 1 NOTE**.

The two NOTEs recorded as accepted environment exceptions at the Phase 1
boundary — `checking for future file timestamps` and `checking top-level files`
("cannot be checked without 'pandoc'") — **both cleared on this run**. The
timestamp API succeeded, and prepending the Quarto `tools` directory to `PATH`
made pandoc visible to the checker. The accepted exception is therefore no
longer needed: the package reaches the V4 target of a single "New submission"
NOTE on this machine, unaided.

### Observations

Stale pkgdown pages for the removed topics remain under `docs/`
(`docs/reference/st_*part*.html`, `docs/articles/partitions.*`). No action
taken: `.gitignore:5` ignores `docs/` wholesale, so these are local build
output and are never published from this repository. They will disappear on the
next clean site deploy.

### Deviations — Phase 3

None.

`get_errors` on all seven touched files: clean.

### Evidence ledger

| ID | Required | Status | Notes |
|----|----------|--------|-------|
| V1 | yes | pending | Phase 2 |
| V2 | yes | pending | Phase 2 |
| V3 | yes | baseline captured | 9 / 11 / 21 must not drop |
| V4 | yes | pending | Phase 3; 3 NOTEs now, 2 are environment-only |
| V5 | yes | pending | Phase 2 |
| V6 | yes | pending | Phase 3 |
| V7 | yes | **pass** | Tarball top level clean |
| V8 | no | **pass** | PDF manual builds after TinyTeX + makeindex |
| V9 | yes | pending | Phase 2 |

### Deviations

| # | Deviation | Policy | Resolution |
|---|-----------|--------|------------|
| 1 | `devtools`/`rcmdcheck` absent; used `roxygen2`/`testthat`/`R CMD` | ask | User approved |
| 2 | `--no-init-file` to bypass user `.Rprofile` | ask | User approved; no dotfile modified |
| 3 | `makeindex` install not in plan | ask | Blocking for step 5's acceptance criterion; installed as part of step 5 |
| 4 | roxygen2 8.0.0 replaced `RoxygenNote: 7.3.2` with `Config/roxygen2/version: 8.0.0` in `DESCRIPTION` | — | Generated field, written by the tool the plan mandates |
