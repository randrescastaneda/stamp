---
date: 2026-09-30
title: "Execution report: CRAN release — unexport partitions and clear check blockers"
plan: ".cg-docs/plans/2026-09-30-cran-release-without-partitions.md"
status: in-progress
language: "R"
review-mode: "manual"
deviation-policy: "ask"
phases-total: 3
phases-completed: [1]
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
