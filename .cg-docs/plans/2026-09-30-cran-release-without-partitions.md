---
date: 2026-09-30
title: "CRAN release: unexport partitions and clear check blockers"
status: active
scope: "Standard"
brainstorm: ".cg-docs/brainstorms/2026-09-28-cran-release-without-partitions.md"
language: "R"
estimated-effort: "medium"
deviation-policy: "ask"
artifact-schema-version: 1
phases: 3
completed-phases: [1, 2]
current-phase: 3
execution-report: ".cg-docs/work-reports/2026-09-30-cran-release-without-partitions.md"
tags: [cran, release, api-surface, partitions, packaging, roxygen]
---

# Plan: CRAN release — unexport partitions and clear check blockers

## Objective

Make `stamp` submittable to CRAN: clear the four mechanical `R CMD check`
findings, and remove the Hive-style partition API from the public surface
while keeping its implementation in-tree and under test.

## Context

Decided in `.cg-docs/brainstorms/2026-09-28-cran-release-without-partitions.md`
(Approach A — unexport in place). Partitions have never been run against real
data and their argument semantics are unsettled; publishing them to CRAN would
lock in an API expected to change. No current callers exist, so removal needs
no migration path.

A baseline `R CMD check --as-cran` on 2026-09-28 (`stamp 0.0.11`) returned
1 ERROR, 1 WARNING, 6 NOTEs. The ERROR and WARNING are caused by `pdflatex`
being absent locally, not by any package defect. Four findings are real.

Planning research and a `/cg-plan-review` pass found these partition couplings
the brainstorm missed:

- **Three** shipped vignettes use the partition API, not one. `stamp.Rmd`
  Section 6 and `version_retention_prune.Rmd` are both **evaluated** — after
  unexporting, each raises `could not find function` and turns the check into an
  ERROR. `builders-plans.Rmd` is saved from failure only by a global
  `eval = FALSE`, but still publicly documents an unexported API.
- `_pkgdown.yml` indexes all five partition functions (lines 33-41) and the
  `partitions` article (line 101). pkgdown fails when indexed topics vanish.
- `README.Rmd` ships a partition example annotated `# Not working`, and
  documents `st_auto_partition()`, `st_hash_code()`, and `st_hash_file()` —
  none of which exist in the package.
- `DESCRIPTION` advertises partitions in its **Title**, not just its
  Description.

Relocating `vignettes/partitions.Rmd` to `vignettes/articles/` is **not**
viable: pkgdown still builds that directory, and the article would call
unexported functions. It moves to a new Rbuildignored `dev/` folder instead.

### Verification hazard

`vignettes/stamp.Rmd` opens with `pkgload::load_all(".")`, which defaults to
`export_all = TRUE`. A local knit therefore sees unexported internals and **will
not reproduce the CRAN failure mode**. Every vignette check in this plan must
run against an installed build via `library(stamp)` — never `load_all()`.

For the same reason, do not trust the enumerated line numbers in this plan as a
complete inventory. They are starting points; the authority is a fresh
`R CMD check` on the current tree.

### Environment note

Per `r-interpreter.instructions.md`, invoke R by absolute path with the `&`
operator. That file mandates `R-4.5.1`, but six versions are installed and the
2026-09-28 baseline was produced under a different tree. Re-baseline on
`R-4.5.1` in step 16 before trusting the comparison.

```powershell
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "<code>"
```

Local checks must neutralize the user's `~/.Rprofile`, which blanks `.Library`
and hides base packages from the check subprocess: set `R_PROFILE_USER` to an
empty file and pass `.libPaths()` through `R_LIBS`.

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| R1 | The five partition functions are absent from `NAMESPACE` and `man/` | Brainstorm decision |
| R2 | No partition reference survives in any CRAN-shipped artifact | Brainstorm — "invisible" |
| R3 | Partition implementation stays in-tree and under test | Approach A |
| R4 | `.Rbuildignore` excludes every non-package root entry | Check NOTE |
| R5 | `DESCRIPTION` Description does not open with the package name | Check NOTE |
| R6 | Roxygen generates valid Rd and valid HTML | Check NOTEs |
| R7 | `st_path()` no longer accepts `partition_key` | User decision, 2026-09-28 |
| R8 | `R CMD check --as-cran` reports only the New submission NOTE | Charter constraint |
| R9 | pkgdown site builds without error | Key deliverable |
| R10 | `DESCRIPTION` Title does not advertise partitions | Review P1.2 |
| R11 | Vignette verification runs against an installed build | Review P1.1 |

## Implementation Steps

## Phase 1: CRAN blockers

Independent of partitions. Lands and verifies first.

### 1. Extend `.Rbuildignore`

- **Requirements**: R4
- **Files**: `.Rbuildignore`
- **Details**: Append `^\.kilo$`, `^\.quarto$`, `^\.Rhistory$`,
  `^roadmap\.json$`, `^compound-gpid.*\.md$`, and `^dev$`. `.kilo` currently
  ships an entire git worktree (`.kilo/worktrees/alder-port/.git`) inside the
  tarball. `^dev$` is added ahead of step 11, which creates that folder.
  `.Rproj.user` and `.current_task` are already covered — verified against the
  existing file. Do **not** treat this list as final: re-derive it from a fresh
  `R CMD build` + `R CMD check` on the current tree, because the working tree
  has changed since the 2026-09-28 baseline.
- **Test Scenarios**: tarball omits all six; a file legitimately named
  `development.R` is not caught by `^dev$` (anchored, no trailing wildcard); no
  package-essential file is excluded by an over-broad pattern.
- **Tests**: `R CMD build`, then `tar -tzf stamp_*.tar.gz | Select-String "kilo|quarto|Rhistory|roadmap|compound-gpid|^stamp/dev/"` → no matches.
- **Acceptance criteria**: "checking for hidden files" and "checking top-level
  files" NOTEs both gone, confirmed by a real check run rather than inspection.

### 2. Rewrite the `DESCRIPTION` Title and Description

- **Requirements**: R2, R5, R10
- **Files**: `DESCRIPTION`
- **Details**: Two separate defects in one file.
  **Title** (line 2) currently reads `Reproducible Artifact Store with
  Sidecars, Versions, and Partitions` — the most visible string on the CRAN
  package page, advertising a feature about to leave the public API. Retitle to
  e.g. `Reproducible Artifact Store with Sidecars and Version History`,
  observing CRAN title rules (title case, no trailing period, no "R package
  for ...").
  **Description** opens `"Stamp saves R objects with sidecar metadata..."` —
  CRAN rejects Descriptions beginning with the package name. Reword to start
  differently (e.g. "Saves R objects with sidecar metadata...") and drop
  "supports Hive-style partitions". Keep wording aligned with the charter
  `## Objective` rewritten in step 15.
- **Test Scenarios**: Title has no partition mention and satisfies CRAN title
  rules; Description's first word is not `Stamp`/`This package`; no partition
  mention; both fields still parse.
- **Tests**: `R CMD check --as-cran` incoming-feasibility section.
- **Acceptance criteria**: the "Description field should not start with" NOTE
  is gone and neither field mentions partitions.

### 3. Repair the malformed roxygen block in `version_store.R`

- **Requirements**: R6
- **Files**: `R/version_store.R` (lines 733-735)
- **Details**: The title line is duplicated *after* `@keywords internal`, so
  roxygen absorbed the whole prose block into the tag and emitted 32 junk
  entries (`\keyword{the}`, `\keyword{artifact,}`, ...). Delete the duplicated
  title on line 735 and the stray `@keywords internal` on line 734, keeping
  the real title on line 733. Add `@noRd` to `.st_catalog_record_version` to
  match its neighbour `.st_catalog_append_version`; it is internal and should
  not generate a man page.
- **Test Scenarios**: `man/dot-st_catalog_record_version.Rd` disappears after
  `document()`; no other Rd file gains or loses keywords.
- **Tests**: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::document()"`, then `git status man/`.
- **Acceptance criteria**: the `\keyword` NOTE is gone and the Rd file is
  removed.

### 4. Escape angle brackets in roxygen comments

- **Requirements**: R6
- **Files**: `R/utils.R`, `R/IO_core.R`, `R/version_store.R`, `R/hashing.R`,
  `R/format_registry.R`, `R/partitions.R`
- **Details**: Roxygen prose using bare `<root>`, `<rel_path>`, `<ext>`,
  `<lgl>` etc. renders as unknown HTML tags. **Derive the site list
  mechanically** — grep `^#'` lines matching `<[a-z_]+>` and subtract those
  already inside backticks or `\verb{}` — then let the check output be the
  authority. An earlier hand-enumerated list proved unreliable: it double-
  counted, included `R/version_store.R:68` which is already backticked, and
  missed two real sites. Confirm these two are covered:
  `R/IO_core.R:949` (on the **exported** `st_should_save()`) and
  `R/version_store.R:81` (on `.st_version_dir()`, which has `@keywords
  internal` but no `@noRd`, so it does generate an Rd page).
  Wrap each in backticks to match surrounding roxygen style.
  **Exception**: `R/utils.R:182` sits inside an `@examples \dontrun{}` block,
  where Rd content is verbatim and `<` is escaped on HTML conversion — it is
  probably not an offending site, and backticks would appear literally in
  rendered example output. Reword it or leave it; confirm from check output.
- **Test Scenarios**: HTML validation clean; rendered help still readable; no
  accidental escaping inside real Rd markup such as `\link{}`; example blocks
  render without stray backticks.
- **Tests**: `devtools::document()`, then `R CMD check --as-cran` HTML section.
- **Acceptance criteria**: "checking HTML version of manual" NOTE is gone.
  Note step 6 removes the `R/partitions.R:171` site as a side effect; fix it
  anyway so the file is correct when partitions are restored later.

### 5. Install TinyTeX

- **Requirements**: R8
- **Files**: none (environment)
- **Details**: `tinytex::install_tinytex()`. Without LaTeX the PDF-manual check
  cannot run, which is the sole cause of the baseline ERROR and WARNING.
- **Test Scenarios**: `tinytex::is_tinytex()` returns `TRUE`.
- **Tests**: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "tinytex::is_tinytex()"`.
- **Acceptance criteria**: `R CMD check` builds the PDF manual with no ERROR.
  If installation is blocked by the corporate proxy, fall back to
  `--no-manual` and record that V8 is unverified.

## Phase 2: Partition unexport

Begins only after Phase 1 verifies.

### 6. Unexport the five partition functions

- **Requirements**: R1, R3
- **Files**: `R/partitions.R`
- **Details**: Replace `#' @export` with `#' @noRd` on `st_part_path` (174),
  `st_save_part` (190), `st_write_parts` (265), `st_list_parts` (452), and
  `st_load_parts` (593). `@noRd` suppresses Rd generation entirely, so the
  `@examples` blocks in `st_write_parts`, `st_list_parts`, and `st_load_parts`
  stop being checked — leave them in place as developer documentation. Do not
  touch function bodies. Run `devtools::document()`; never hand-edit
  `NAMESPACE`.
- **Test Scenarios**: `NAMESPACE` loses exactly five lines; `man/st_*part*.Rd`
  removed; `stamp:::st_write_parts` still resolves.
- **Tests**: `git diff NAMESPACE`; `grep -i part NAMESPACE`.
- **Acceptance criteria**: V1 and V2 pass; `NAMESPACE` diff touches nothing
  else (Blocked-Stop condition if it does).

### 7. Drop `partition_key` from `st_path()`

- **Requirements**: R7, R2
- **Files**: `R/IO_core.R` (lines 121-138)
- **Details**: Remove the `partition_key` formal (127), its `@param` line
  (124), and the `partition_key = partition_key` element of the returned list
  (134). Review confirmed nothing reads the field back — it was documented "not
  used in M2", and `manifest$partition_key` in `test-write-parts.R:31`
  originates in `st_write_parts()`, not here. This narrows an exported
  signature; acceptable because the argument is inert and the package is
  pre-CRAN.
  Also retitle the roxygen block at line 121, currently `Declare a path (with
  optional format & partition hint)`, to `Declare a path (with optional
  format)`. Otherwise `man/st_path.Rd` ships a `\title{}` naming both a removed
  argument and an unexported feature.
- **Test Scenarios**: `st_path("x.qs2")` still returns a classed list;
  `st_path("x.qs2", partition_key = 1)` now errors on an unused argument;
  `print.st_path` unaffected; `man/st_path.Rd` mentions no partitions.
- **Tests**: `devtools::test()`; grep the suite for `st_path(` calls passing
  three arguments; `grep -i partition man/st_path.Rd` → no hits.
- **Acceptance criteria**: suite green; `partition_key` appears nowhere in
  `R/IO_core.R`; the regenerated Rd is clean.

### 8. Remove Section 6 from `vignettes/stamp.Rmd`

- **Requirements**: R2, R11
- **Files**: `vignettes/stamp.Rmd`
- **Details**: Three separate edits, all required:
  1. Delete the `## 6. Partitioned Workflow for Partial Re-execution` heading
     and everything through the end of the `partition-rebuild-stale` chunk
     (lines 577-783).
  2. Delete the outline entry at **line 82** — `6. Producing the same output
     using partitioned artifacts for partial re-runs.` — which sits near the
     top of the document, outside the deletion range, and renumber the
     remaining outline items.
  3. Delete the Section 7 summary bullet "A partitioned strategy enabling
     targeted re-execution for changed inputs," and renumber `## 7. Summary`
     to `## 6. Summary`.

  Do **not** rewrite the chunks with `stamp:::` — constraint C2 forbids `:::`
  in shipped vignettes. Leave `code_label = "aggregate_welfare_partitioned"`
  at lines 473 and 494 alone: those are string literals in the retained
  Builders section, not API calls.
- **Test Scenarios**: the `final-lineage` chunk still runs (it reads
  `outputs/welfare_summary.qs2`, produced in Section 3, not Section 6 —
  verified during review); no later chunk references `partition_keys`,
  `summary_parts`, or `build_partition_summary`; the vignette knits end to end;
  the outline no longer promises a removed section.
- **Tests**: knit against an **installed build**, not `pkgload`. The vignette's
  setup chunk calls `pkgload::load_all(".")`, which defaults to
  `export_all = TRUE` and would mask the failure. Use
  `R CMD build` + `R CMD check` (which rebuilds vignettes via `library(stamp)`),
  or install first and render in a clean session.
- **Acceptance criteria**: vignette rebuilds during `R CMD check` without
  error. If a later chunk breaks through a shared object, stop and report
  (Blocked-Stop condition).

### 9. Remove the partitions section from `vignettes/version_retention_prune.Rmd`

- **Requirements**: R2, R11
- **Files**: `vignettes/version_retention_prune.Rmd`
- **Details**: This vignette is **evaluated** — it has no global
  `eval = FALSE`, and its setup chunk falls back to `library(stamp)` unless
  `DEV_VIGNETTES=true`. After step 6 it raises `could not find function
  "st_part_path"`, an ERROR rather than a NOTE. Four edits:
  1. Delete the `## Partitioned datasets (Hive-style)` section — heading at
     line 307 through the closing `---` before `## Recommendations & Recipes`
     (approximately lines 307-374). Delete from the heading up to, but not
     including, the next `##` heading; do not rely on the exact numbers.
  2. Delete the key-API bullet at line 37: `* Partition helpers:
     st_part_path(), st_save_part(), st_list_parts(), st_load_parts()`.
  3. Delete the partition bullet in the intro list near line 30 (confirm its
     exact position before editing).
  4. Delete the FAQ entry near the end of the file — **"Do partition helpers
     change how retention works?"** and its answer. This sits far outside the
     main section and is easy to miss.
- **Test Scenarios**: the vignette knits with `library(stamp)` against an
  installed build; no remaining reference to any of the five functions; the
  surrounding `---` separators still delimit sections correctly; the
  Recommendations, FAQ, and retention content are otherwise untouched.
- **Tests**: `R CMD check` vignette rebuild; `grep -E "st_(part_path|save_part|write_parts|list_parts|load_parts)" vignettes/version_retention_prune.Rmd` → no hits.
- **Acceptance criteria**: vignette rebuilds without error and contains no
  partition API reference.

### 10. Remove the partitions section from `vignettes/builders-plans.Rmd`

- **Requirements**: R2
- **Files**: `vignettes/builders-plans.Rmd`
- **Details**: Delete `## Partitioned targets and partial rebuilds` — heading
  at line 112 through the blank line before `## Modes: strict vs relaxed`
  (approximately lines 112-169), including the `{r partitioned-builder}` chunk
  whose body calls `st_part_path()` at line 140. This vignette sets
  `eval = FALSE` globally at line 14, so it will not break the build — but it
  publicly documents an unexported API, which R2 forbids and V5 detects. Its
  cross-reference to "see `vignettes/stamp.Rmd` for an end-to-end example"
  points at content removed in step 8, so the section is stale regardless.
- **Test Scenarios**: the vignette knits; `## Modes: strict vs relaxed` follows
  the preceding section cleanly; no dangling reference to the removed chunk.
- **Tests**: `R CMD check` vignette rebuild; `grep -E "st_(part_path|save_part|write_parts|list_parts|load_parts)" vignettes/builders-plans.Rmd` → no hits.
- **Acceptance criteria**: no partition API reference remains.

### 11. Relocate `vignettes/partitions.Rmd`

- **Requirements**: R2, R3
- **Files**: `vignettes/partitions.Rmd` → `dev/partitions.Rmd`
- **Details**: `git mv` to a new top-level `dev/` folder, already Rbuildignored
  in step 1. This hides it from both the tarball and pkgdown while preserving
  the content for restoration when partitions are re-exported. Its code calls
  now-unexported functions, so it will not knit as-is — acceptable for a parked
  document; add a one-line note at the top recording why it was parked.
- **Test Scenarios**: `vignettes/` contains no partition file; `dev/` is absent
  from the tarball; `Meta/vignette.rds` and `doc/` regenerate without a
  partitions entry.
- **Tests**: `R CMD build`; inspect tarball contents.
- **Acceptance criteria**: no partitions vignette in the build; the stale
  `doc/partitions.*` and `doc/partitions.html` artifacts are removed too.

### 12. Update `_pkgdown.yml`

- **Requirements**: R9
- **Files**: `_pkgdown.yml`
- **Details**: Delete `st_part_path` (33), `st_list_parts` (34), `st_save_part`
  (38), `st_write_parts` (39), `st_load_parts` (41) from the "Core I/O"
  reference contents, and `partitions` (101) from the "Advanced Usage" article
  list. pkgdown errors when the index names topics that no longer exist, and
  warns when an exported topic is missing from the index — after step 6 these
  five are neither exported nor documented, so they must be removed rather than
  moved.
- **Test Scenarios**: `pkgdown::check_pkgdown()` reports no missing or extra
  topics; the "Core I/O" section still lists its remaining 11 functions.
- **Tests**: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "pkgdown::check_pkgdown()"`.
- **Acceptance criteria**: check passes; V6 deferred to step 16.

### 13. Rewrite partition tests to use `stamp:::`

- **Requirements**: R3
- **Files**: `tests/testthat/test-partitions.R`,
  `tests/testthat/test-write-parts.R`, `tests/testthat/test-vignette-issues.R`
- **Details**: Prefix every call to the five functions with `stamp:::`. In
  `test-vignette-issues.R` the calls are on lines **28, 35, 52, 53, 65, 66**;
  lines 18, 42, and 64 are `test_that()` description strings, not calls, and
  must not be touched. The rest of the file tests unrelated behaviour and must
  be left alone. Test count must not drop — these tests are the only thing
  keeping the parked code honest.
- **Test Scenarios**: all previously passing partition tests still pass; no
  test is silently skipped; `R CMD check` raises no `:::` NOTE (calls to a
  package's own internals from its own tests are permitted).
- **Tests**: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "devtools::test()"`.
- **Acceptance criteria**: V3 passes — 0 failures, and the partition test files
  report the same number of passing assertions as before the change.

### 14. Scrub partitions from `README.Rmd` and re-knit

- **Requirements**: R2
- **Files**: `README.Rmd`, `README.md`
- **Details**: Remove the tagline clause "and Hive-style partitions" (23); the
  `# Partitions (under development)` quickstart chunk **in full — lines 59-72
  inclusive**, from the opening ` ```{r} ` fence through the closing fence, not
  just the 62-71 body, or an orphan fence wrapping an empty chunk is left
  behind; the "advanced features like partitions" clause (128); the entire
  "Partitioned and Pruning Data (under development)" reference section
  (176-182); the partition clause in the `st_filter` description (203); and the
  Partitions vignette link (212). Preserve the pruning content if it is
  genuinely about `st_prune_versions`; check before deleting the combined
  heading.

  While in this file, fix two further documented-but-nonexistent exports in the
  "Metadata & Inspection" section: **`st_hash_code(code)`** (line 167) and
  **`st_hash_file(path)`** (line 168). `NAMESPACE` exports only `st_hash_obj`.
  Same defect class as `st_auto_partition()` at line 179. README is
  Rbuildignored so this is not a check failure, but it renders as the pkgdown
  home page and the GitHub landing page — the first thing a CRAN reviewer sees.

  Re-knit with `devtools::build_readme()`.
- **Test Scenarios**: `README.md` regenerates; no broken internal anchors; no
  orphan code fences; the remaining quickstart still runs; every function named
  in the reference sections actually exists in `NAMESPACE`.
- **Tests**: `grep -i partition README.md` → no hits; cross-check each
  documented function name against `NAMESPACE`.
- **Acceptance criteria**: V5 passes for `README.md`, and no nonexistent
  function is documented.

## Phase 3: Documentation and verification

### 15. Update `NEWS.md` and the project charter

- **Requirements**: R2
- **Files**: `NEWS.md`, `compound-gpid.md`
- **Details**: Add a `NEWS.md` entry for the release noting that the partition
  API is internal pending validation. Rewrite the charter `## Objective` to
  drop "and supports Hive-style partitions", matching the `DESCRIPTION` Title
  and Description wording from step 2, and set `last-reviewed` to the current
  date.
- **Test Scenarios**: charter Objective, `DESCRIPTION` Title, and `DESCRIPTION`
  Description all agree; `NEWS.md` parses as valid Markdown.
- **Tests**: manual read; `R CMD check` NEWS parsing.
- **Acceptance criteria**: no partition claim survives in either file.

### 16. Full verification run

- **Requirements**: R8, R9, R11
- **Files**: none
- **Details**: Re-baseline on `R-4.5.1` (the 2026-09-28 run may have used a
  different tree). Run the full suite, a clean `--as-cran` check, and a pkgdown
  build. The check must run against a built tarball so vignettes rebuild via
  `library(stamp)`. Compare every finding against the baseline; any new NOTE is
  a stop condition.
- **Test Scenarios**: check status is `1 NOTE`; the only NOTE is
  "New submission"; all vignettes rebuild; pkgdown completes; tarball contents
  are clean.
- **Tests**: `devtools::test()`, then `rcmdcheck::rcmdcheck(args = "--as-cran")` with `R_PROFILE_USER` neutralized, then `pkgdown::build_site()`.
- **Acceptance criteria**: V4, V6, V7, V9 all pass.

## Testing Strategy

The suite is the safety net for the parked partition code, so coverage must not
regress. Run `devtools::test()` after every phase and confirm the partition test
files still report their original assertion counts.

Vignette rebuilding is the second net, and the one most easily faked. Steps 8
and 9 are the highest-risk edits in the plan: removing a mid-document section
can break later chunks through shared objects, and
`version_retention_prune.Rmd` is evaluated, so an error there fails the check
outright. **Verification must use an installed build** — `pkgload::load_all()`
defaults to `export_all = TRUE` and will happily resolve `st_part_path()` after
it has been unexported, reporting success on a package that cannot pass CRAN.
Use `R CMD build` + `R CMD check`, which rebuilds vignettes through
`library(stamp)`.

Reserve the full `--as-cran` run for phase boundaries; it takes roughly two
minutes and provides no extra signal per-step.

## Documentation Checklist

- [ ] `DESCRIPTION` Title and Description rewritten (step 2)
- [ ] Roxygen valid in 6 files (steps 3-4)
- [ ] `man/` regenerated, partition Rd files gone (step 6)
- [ ] `st_path()` Rd title no longer mentions partitions (step 7)
- [ ] `vignettes/stamp.Rmd` Section 6, outline entry, and summary bullet
      removed; sections renumbered (step 8)
- [ ] `vignettes/version_retention_prune.Rmd` partitions section, two bullets,
      and FAQ entry removed (step 9)
- [ ] `vignettes/builders-plans.Rmd` partitions section removed (step 10)
- [ ] `_pkgdown.yml` reference and article indexes updated (step 12)
- [ ] `README.Rmd` scrubbed, nonexistent exports corrected, re-knitted (step 14)
- [ ] `NEWS.md` entry added (step 15)
- [ ] `compound-gpid.md` Objective aligned with `DESCRIPTION` (step 15)

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| A **fourth** shipped document calls the partition API, unfound in review | Medium | High | V5 greps all of `vignettes/`, `man/`, `README.md`, `DESCRIPTION`; the step-16 check is the backstop. Blocked-Stop condition if one appears |
| Verification passes locally but fails on CRAN because `load_all()` masked the unexport | Medium | High | C6 forbids `pkgload` in verification; all vignette checks run against an installed build |
| Removing a mid-document section breaks a later chunk in `stamp.Rmd` or `version_retention_prune.Rmd` | Medium | High | Rebuild each vignette immediately after its edit; review confirmed `final-lineage` depends on Section 3 output only |
| `devtools::document()` reorders or drops unrelated `NAMESPACE` entries | Low | High | Inspect `git diff NAMESPACE` after every `document()`; stop if non-partition lines move |
| Enumerated line numbers drift as earlier steps edit the same files | High | Medium | Treat all line numbers as hints; locate by heading or symbol, and re-derive the angle-bracket set mechanically (step 4) |
| Dropping `partition_key` breaks an unfound consumer | Low | Medium | Review confirmed `manifest$partition_key` originates in `st_write_parts()`, not `st_path()`; full suite run in step 7 |
| TinyTeX install blocked by corporate proxy | Medium | Low | Fall back to `--no-manual`; V8 is marked not required |
| `README.Rmd` re-knit fails because the quickstart writes to the working directory | Medium | Low | README is Rbuildignored, so this blocks nothing in the check; fix opportunistically |
| Baseline was produced on a different R version than 4.5.1 | Medium | Medium | Re-baseline in step 16 and compare like with like |
| Parked `dev/partitions.Rmd` silently rots | High | Low | Accepted; the post-CRAN roadmap milestone owns its restoration |

## Out of Scope

- Fixing partition correctness, performance, or integration with
  versioning/sidecars/retention — deferred to the `post-cran-partitions`
  roadmap milestone.
- Testing partitions against real PIP-scale data.
- Implementing `st_auto_partition()`; the README text is deleted, not honoured.
- The actual CRAN submission.
- Any change to the 38 non-partition exported functions.
- Updating the stale `r-interpreter.instructions.md`.

## Completion Contract

### Outcome

`stamp` builds and passes `R CMD check --as-cran` with a single "New
submission" NOTE. The five partition functions are internal-only — absent from
`NAMESPACE`, the manual, the pkgdown site, and every CRAN-shipped document —
while remaining in-tree and fully covered by tests.

### Verification Surface

| ID | Evidence Required | Command/Artifact | Phase | Required |
|----|-------------------|------------------|-------|----------|
| V1 | No partition exports in `NAMESPACE` | `grep -i part NAMESPACE` returns nothing | 2 | yes |
| V2 | No partition man pages | `man/st_*part*.Rd` does not exist | 2 | yes |
| V3 | Suite green, partition tests still executing | `devtools::test()` — 0 failures, partition files at original assertion counts | 2 | yes |
| V4 | Clean check | `R CMD check --as-cran` → `Status: 1 NOTE` (New submission only) | 3 | yes |
| V5 | No partition **API-symbol** references in shipped artifacts | no hits for the five function names, nor partition prose, in `DESCRIPTION`, `README.md`, `vignettes/*.Rmd`, `man/*.Rd`. Retained `code_label = "...partitioned"` string literals do not count | 2 | yes |
| V6 | pkgdown builds | `pkgdown::build_site()` completes without error | 3 | yes |
| V7 | Tarball excludes dev/tooling dirs | `tar -tzf stamp_*.tar.gz` shows no `.kilo`, `.quarto`, `.Rhistory`, `roadmap.json`, `compound-gpid*.md`, `dev/` | 1 | yes |
| V8 | Rd/LaTeX valid | PDF manual builds after TinyTeX install | 3 | no |
| V9 | Vignette verification used an installed build | all three edited vignettes rebuild during `R CMD check` via `library(stamp)`, not a `pkgload::load_all()` knit | 2 | yes |

### Constraints

| ID | Constraint | Check | Phase |
|----|------------|-------|-------|
| C1 | No behavioural change to partition logic — visibility only | `git diff R/partitions.R` shows only roxygen tag changes | 2 |
| C2 | No `stamp:::` in CRAN-shipped vignettes | partition sections removed outright, not rewritten with `:::` | 2 |
| C3 | Source and `NAMESPACE` never silently diverge | `NAMESPACE` regenerated by `document()`, never hand-edited | 2 |
| C4 | Partition code stays under test | Partition test files present and running via `stamp:::` | 2 |
| C5 | R >= 4.1 compatibility preserved | No new syntax or dependencies introduced | all |
| C6 | Verification never relies on `pkgload::load_all()`, which exports internals and masks the failure | Vignette validation runs `library(stamp)` against an installed build | 2 |

### Boundaries

- **Allowed**: roxygen tag edits in `R/partitions.R`; deletion of generated
  `man/` files; removing `partition_key` from `st_path()` and retitling its Rd;
  edits to `DESCRIPTION` (Title and Description), `README.Rmd`/`README.md`,
  `_pkgdown.yml`, `.Rbuildignore`, `NEWS.md`, `vignettes/stamp.Rmd`,
  `vignettes/version_retention_prune.Rmd`, `vignettes/builders-plans.Rmd`,
  `compound-gpid.md`; relocating `vignettes/partitions.Rmd` to `dev/`; roxygen
  fixes across 6 R files.
- **Out of scope**: everything listed under "Out of Scope" above.

### Iteration Policy

1. Phase 1 lands and verifies before Phase 2 begins — it is independent and
   moves check status on its own.
2. Run `devtools::document()` after every roxygen change; never hand-edit
   `NAMESPACE`.
3. Re-run `devtools::test()` after each phase; a red suite halts progress.
4. Run the full `--as-cran` check only at phase boundaries, not per-step.
5. After each vignette edit (steps 8, 9, 10), rebuild that vignette against an
   installed build before moving on — never via `pkgload::load_all()`.
6. If a check surfaces a NOTE absent from the 2026-09-28 baseline, diagnose
   before continuing.
7. Treat every line number in this plan as a hint, not a fact. Locate targets
   by heading or symbol and confirm before editing.

### Blocked-Stop Conditions

- `devtools::document()` produces a `NAMESPACE` diff touching non-partition
  exports.
- Removing a partition section from `vignettes/stamp.Rmd` or
  `vignettes/version_retention_prune.Rmd` breaks a later chunk through a shared
  object dependency.
- A shipped document outside the three known vignettes turns out to call the
  partition API.
- `R CMD check` surfaces an ERROR or WARNING unrelated to the known
  missing-LaTeX issue.
- Dropping `partition_key` from `st_path()` reveals a consumer not found during
  planning research.
