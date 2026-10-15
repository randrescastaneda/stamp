# 🧠 Project Brain — Chronological Log

_Generated 2026-10-15 · 12 artifacts (newest first) + 23 roadmap features_

## 2026-10-15

- **[2026-10-14-m2-stamp-generic-gaps-review](.cg-docs/reviews/2026-10-14-m2-stamp-generic-gaps-review.md)** · `review` · _—_ · `2026-10-15`
  > Review mode: standard. Auto route: documentation-only changes, raised from light by more than 50 non-test lines. Eigh…
- **[2026-10-14-m2-stamp-generic-gaps-verify-review](.cg-docs/reviews/2026-10-14-m2-stamp-generic-gaps-verify-review.md)** · `review` · _—_ · `2026-10-15`
  > Executed `/cg-review mode:verify` after all five Plan phases. Confirmed the parent exists and is the newest standard …
- **[Initialize a managed wiki without confusing post-push files with published work](.cg-docs/solutions/git-workflows/2026-10-15-publish-before-wiki-compound.md)** · `solution` · _—_ · `2026-10-15`
  > An earlier Compound capture correctly skipped wiki enrichment because `wiki/_wiki.yml` did not exist. The user then r…
- **[M2 Stamp Generic Gaps: Contracts, Safe Gates, and Conditional Implementation](.cg-docs/plans/2026-10-14-m2-stamp-generic-gaps.md)** · `plan` · _completed_ · `2026-10-15`
  > Prepare the stamp-local work for task `m2-stamp-local-plan-2026-10-14`, milestone `m2-walking-skeleton`, feature `clo…
- **[Verify durable request convergence with installed R subprocesses](.cg-docs/solutions/testing-patterns/2026-10-15-installed-r-checks-for-durable-request-convergence.md)** · `solution` · _—_ · `2026-10-15`
  > The stamp generic-request work needed to prove more than successful saving: after A changes from A1 to A2, B must exe…

## 2026-10-02

- **[In-process testthat::test_local\(\) segfaults silently — verify via R CMD check instead](.cg-docs/solutions/testing-patterns/2026-10-02-in-process-testthat-segfault.md)** · `solution` · _—_ · `2026-10-02`
  > Three separate attempts to run `testthat::test_local()` / `testthat::test_file()` directly in the development termina…
- **[options\(\)/on.exit\(\) does not restore st_opts\(\) state — it's a no-op](.cg-docs/solutions/bugs/2026-10-02-st-opts-test-state-leak.md)** · `solution` · _—_ · `2026-10-02`
  > Ten `test_that()` blocks in `tests/testthat/test-write-parts.R` (and one in `test-hash-sanitize.R`) opened with: inte…
- **[README and vignettes drift out of sync with the actual exported API](.cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md)** · `solution` · _—_ · `2026-10-02`
  > Across one review-and-fix cycle on the `stamp` package, the same defect class surfaced **five separate times**: docum…

## 2026-09-30

- **[2026-09-30-cran-release-without-partitions-review](.cg-docs/reviews/2026-09-30-cran-release-without-partitions-review.md)** · `review` · _—_ · `2026-09-30`
  > **Review mode**: standard (8 agents) **Scope**: `324ece4..HEAD` — commits `8dc5c67`, `3bed3e0`, `e26edfc`; 42 files, …
- **[CRAN release: unexport partitions and clear check blockers](.cg-docs/plans/2026-09-30-cran-release-without-partitions.md)** · `plan` · _completed_ · `2026-09-30`
  > Make `stamp` submittable to CRAN: clear the four mechanical `R CMD check` findings, and remove the Hive-style partiti…

## 2026-09-28

- **[Ship stamp to CRAN without partitions](.cg-docs/brainstorms/2026-09-28-cran-release-without-partitions.md)** · `brainstorm` · _decided_ · `2026-09-28`
  > <!-- Valid status values: decided, in-progress, abandoned -->

## 2026-03-23

- **[Fix verbose suppression in st_init, st_save, st_load](.cg-docs/plans/2026-03-23-fix-verbose-suppression.md)** · `plan` · _active_ · `2026-03-23`
  > Ensure that `st_init()`, `st_save()`, and `st_load()` emit zero informational messages or warnings when `verbose = FA…

## Roadmap Features

- **[Abort instead of silently discarding unreadable partitions in st_load_parts](roadmap.json#abort-on-unreadable-partitions-in-st-load-parts)** · `feature` · _idea_ · `—`
  > Abort instead of silently discarding unreadable partitions in st_load_parts
- **[Benchmark partition performance](roadmap.json#benchmark-partition-performance)** · `feature` · _idea_ · `—`
  > Benchmark partition performance
- **[Escape angle brackets in roxygen](roadmap.json#escape-angle-brackets-in-roxygen)** · `feature` · _done_ · `—`
  > Escape angle brackets in roxygen
- **[Fix malformed roxygen in version_store.R](roadmap.json#fix-malformed-roxygen-in-version-store)** · `feature` · _done_ · `—`
  > Fix malformed roxygen in version_store.R
- **[Fix .Rbuildignore gaps](roadmap.json#fix-rbuildignore-gaps)** · `feature` · _done_ · `—`
  > Fix .Rbuildignore gaps
- **[Fix warned_formats globalenv leak in st_load_parts](roadmap.json#fix-warned-formats-globalenv-leak)** · `feature` · _idea_ · `—`
  > Fix warned_formats globalenv leak in st_load_parts
- **[Fix Windows case-folding of partition key values and the mislabelled test skips](roadmap.json#fix-windows-case-folding-of-partition-keys)** · `feature` · _idea_ · `—`
  > Fix Windows case-folding of partition key values and the mislabelled test skips
- **[Harden partition key value sanitation for backslash, reserved names, NA and empty string](roadmap.json#harden-partition-key-value-sanitation)** · `feature` · _idea_ · `—`
  > Harden partition key value sanitation for backslash, reserved names, NA and empty string
- **[Install TinyTeX for local PDF manual check](roadmap.json#install-tinytex-for-local-pdf-manual-check)** · `feature` · _done_ · `—`
  > Install TinyTeX for local PDF manual check
- **[Integrate partitions with versioning, sidecars, and retention](roadmap.json#integrate-partitions-with-versioning-sidecars-and-retention)** · `feature` · _idea_ · `—`
  > Integrate partitions with versioning, sidecars, and retention
- **[Preserve partition key column types on load instead of flattening to character](roadmap.json#preserve-partition-key-column-types-on-load)** · `feature` · _idea_ · `—`
  > Preserve partition key column types on load instead of flattening to character
- **[Propagate save failures in st_write_parts instead of downgrading them to warnings](roadmap.json#propagate-save-failures-in-st-write-parts)** · `feature` · _idea_ · `—`
  > Propagate save failures in st_write_parts instead of downgrading them to warnings
- **[Re-export partition API](roadmap.json#re-export-partition-api)** · `feature` · _idea_ · `—`
  > Re-export partition API
- **[Replace quadratic Reduce\(rbind\) with rbindlist in partition combine](roadmap.json#replace-quadratic-reduce-rbind-in-partition-combine)** · `feature` · _idea_ · `—`
  > Replace quadratic Reduce(rbind) with rbindlist in partition combine
- **[Rewrite DESCRIPTION Description](roadmap.json#rewrite-description-description)** · `feature` · _done_ · `—`
  > Rewrite DESCRIPTION Description
- **[Scope partition expression filters to baseenv and pre-validate filter variable names](roadmap.json#scope-partition-expression-filters-to-baseenv)** · `feature` · _idea_ · `—`
  > Scope partition expression filters to baseenv and pre-validate filter variable names
- **[Settle partition API semantics](roadmap.json#settle-partition-api-semantics)** · `feature` · _idea_ · `—`
  > Settle partition API semantics
- **[Replace six recursive tree walks with a single walk in st_list_parts](roadmap.json#single-tree-walk-in-st-list-parts)** · `feature` · _idea_ · `—`
  > Replace six recursive tree walks with a single walk in st_list_parts
- **[Unexport partition API](roadmap.json#unexport-partition-api)** · `feature` · _done_ · `—`
  > Unexport partition API
- **[Use drop=TRUE in partition split\(\) and interaction\(\) to avoid NA partitions](roadmap.json#use-drop-true-in-partition-split-and-interaction)** · `feature` · _idea_ · `—`
  > Use drop=TRUE in partition split() and interaction() to avoid NA partitions
- **[Validate partition folder key against file contents instead of overwriting the column on load](roadmap.json#validate-partition-folder-key-against-contents)** · `feature` · _idea_ · `—`
  > Validate partition folder key against file contents instead of overwriting the column on load
- **[Validate partitions against real data](roadmap.json#validate-partitions-against-real-data)** · `feature` · _idea_ · `—`
  > Validate partitions against real data
- **[Wire st_path\(\) through all path-taking functions, then re-export](roadmap.json#wire-st-path-through-path-taking-functions)** · `feature` · _idea_ · `—`
  > Wire st_path() through all path-taking functions, then re-export
