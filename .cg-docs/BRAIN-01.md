# 🧠 Project Brain — Part 1

_Generated 2026-10-15_

## 2026-09-28-Cran-Release-Without-Partitions.Md / Partition / Partitions

_Keywords: `2026-09-28-cran-release-without-partitions.md` · `partition` · `partitions`_ · 23 entities

- **[Unexport partition API](roadmap.json#unexport-partition-api)** · `feature` · _done_ · `—`
  > Unexport partition API
- **[Fix .Rbuildignore gaps](roadmap.json#fix-rbuildignore-gaps)** · `feature` · _done_ · `—`
  > Fix .Rbuildignore gaps
- **[Rewrite DESCRIPTION Description](roadmap.json#rewrite-description-description)** · `feature` · _done_ · `—`
  > Rewrite DESCRIPTION Description
- **[Fix malformed roxygen in version_store.R](roadmap.json#fix-malformed-roxygen-in-version-store)** · `feature` · _done_ · `—`
  > Fix malformed roxygen in version_store.R
- **[Escape angle brackets in roxygen](roadmap.json#escape-angle-brackets-in-roxygen)** · `feature` · _done_ · `—`
  > Escape angle brackets in roxygen
- **[Install TinyTeX for local PDF manual check](roadmap.json#install-tinytex-for-local-pdf-manual-check)** · `feature` · _done_ · `—`
  > Install TinyTeX for local PDF manual check
- **[Validate partitions against real data](roadmap.json#validate-partitions-against-real-data)** · `feature` · _idea_ · `—`
  > Validate partitions against real data
- **[Settle partition API semantics](roadmap.json#settle-partition-api-semantics)** · `feature` · _idea_ · `—`
  > Settle partition API semantics
- **[Integrate partitions with versioning, sidecars, and retention](roadmap.json#integrate-partitions-with-versioning-sidecars-and-retention)** · `feature` · _idea_ · `—`
  > Integrate partitions with versioning, sidecars, and retention
- **[Benchmark partition performance](roadmap.json#benchmark-partition-performance)** · `feature` · _idea_ · `—`
  > Benchmark partition performance
- **[Re-export partition API](roadmap.json#re-export-partition-api)** · `feature` · _idea_ · `—`
  > Re-export partition API
- **[Fix warned_formats globalenv leak in st_load_parts](roadmap.json#fix-warned-formats-globalenv-leak)** · `feature` · _idea_ · `—`
  > Fix warned_formats globalenv leak in st_load_parts
- **[Fix Windows case-folding of partition key values and the mislabelled test skips](roadmap.json#fix-windows-case-folding-of-partition-keys)** · `feature` · _idea_ · `—`
  > Fix Windows case-folding of partition key values and the mislabelled test skips
- **[Use drop=TRUE in partition split\(\) and interaction\(\) to avoid NA partitions](roadmap.json#use-drop-true-in-partition-split-and-interaction)** · `feature` · _idea_ · `—`
  > Use drop=TRUE in partition split() and interaction() to avoid NA partitions
- **[Validate partition folder key against file contents instead of overwriting the column on load](roadmap.json#validate-partition-folder-key-against-contents)** · `feature` · _idea_ · `—`
  > Validate partition folder key against file contents instead of overwriting the column on load
- **[Abort instead of silently discarding unreadable partitions in st_load_parts](roadmap.json#abort-on-unreadable-partitions-in-st-load-parts)** · `feature` · _idea_ · `—`
  > Abort instead of silently discarding unreadable partitions in st_load_parts
- **[Propagate save failures in st_write_parts instead of downgrading them to warnings](roadmap.json#propagate-save-failures-in-st-write-parts)** · `feature` · _idea_ · `—`
  > Propagate save failures in st_write_parts instead of downgrading them to warnings
- **[Scope partition expression filters to baseenv and pre-validate filter variable names](roadmap.json#scope-partition-expression-filters-to-baseenv)** · `feature` · _idea_ · `—`
  > Scope partition expression filters to baseenv and pre-validate filter variable names
- **[Replace quadratic Reduce\(rbind\) with rbindlist in partition combine](roadmap.json#replace-quadratic-reduce-rbind-in-partition-combine)** · `feature` · _idea_ · `—`
  > Replace quadratic Reduce(rbind) with rbindlist in partition combine
- **[Replace six recursive tree walks with a single walk in st_list_parts](roadmap.json#single-tree-walk-in-st-list-parts)** · `feature` · _idea_ · `—`
  > Replace six recursive tree walks with a single walk in st_list_parts
- **[Harden partition key value sanitation for backslash, reserved names, NA and empty string](roadmap.json#harden-partition-key-value-sanitation)** · `feature` · _idea_ · `—`
  > Harden partition key value sanitation for backslash, reserved names, NA and empty string
- **[Preserve partition key column types on load instead of flattening to character](roadmap.json#preserve-partition-key-column-types-on-load)** · `feature` · _idea_ · `—`
  > Preserve partition key column types on load instead of flattening to character
- **[Wire st_path\(\) through all path-taking functions, then re-export](roadmap.json#wire-st-path-through-path-taking-functions)** · `feature` · _idea_ · `—`
  > Wire st_path() through all path-taking functions, then re-export

## R Cmd Check / Readme.Rmd / _Pkgdown.Yml

_Keywords: `r cmd check` · `readme.rmd` · `_pkgdown.yml`_ · 3 entities

- **[README and vignettes drift out of sync with the actual exported API](.cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md)** · `solution` · _—_ · `2026-10-02`
  > Across one review-and-fix cycle on the `stamp` package, the same defect class surfaced **five separate times**: docum…
- **[options\(\)/on.exit\(\) does not restore st_opts\(\) state — it's a no-op](.cg-docs/solutions/bugs/2026-10-02-st-opts-test-state-leak.md)** · `solution` · _—_ · `2026-10-02`
  > Ten `test_that()` blocks in `tests/testthat/test-write-parts.R` (and one in `test-hash-sanitize.R`) opened with: inte…
- **[In-process testthat::test_local\(\) segfaults silently — verify via R CMD check instead](.cg-docs/solutions/testing-patterns/2026-10-02-in-process-testthat-segfault.md)** · `solution` · _—_ · `2026-10-02`
  > Three separate attempts to run `testthat::test_local()` / `testthat::test_file()` directly in the development termina…
