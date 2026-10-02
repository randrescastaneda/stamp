---
date: 2026-10-02
title: "README and vignettes drift out of sync with the actual exported API"
category: "bugs"
language: "R"
tags: [documentation, readme, vignettes, pkgdown, roxygen, api-drift, cran]
root-cause: "Hand-written prose in README.Rmd/vignettes is not checked against NAMESPACE or man/*.Rd by any tool, so it silently drifts as exports are renamed, removed, or added"
severity: "P2"
---

# README and vignettes drift out of sync with the actual exported API

## Problem

Across one review-and-fix cycle on the `stamp` package, the same defect class
surfaced **five separate times**: documentation describing functions, formats,
or arguments that do not exist (or no longer exist) in the installed package.

Confirmed instances:
- `st_auto_partition` referenced in docs, never existed as an export
- `st_hash_code` / `st_hash_file` referenced in docs, never existed as exports
- A vignette live-chunk calling `st_path()` after `st_path()` was unexported
  (would have broken `R CMD check` on every rebuild)
- `st_formats()`'s own example comment omitting `parquet` from the list of
  formats it actually returns
- 8 of the package's exported functions (`st_opts_get`, `st_formats`,
  `st_register_format`, `st_restore`, `st_switch`, `st_pk`, `st_with_pk`,
  `st_builders`) had **no README entry at all**, found by a documentation
  review diffing `NAMESPACE` against `README.Rmd`

None of these are caught by `R CMD check`, `roxygen2::roxygenise()`, or
`testthat` — they only affect hand-written prose, not generated `Rd` files.

## Root Cause

`README.Rmd` and the vignettes describe the API in free-text prose that
nothing mechanically validates against the real, current export surface
(`NAMESPACE`, `man/*.Rd`, or `_pkgdown.yml`'s `reference:` index). Every time
a function is renamed, unexported, or added, there are at least four places
that can silently fall out of sync: `README.Rmd`, the vignettes, `_pkgdown.yml`
reference sections, and manual test scripts under `tests/manual/` (which
`R CMD check` does not run because it's a subdirectory).

## Solution

1. Treat "unexporting or renaming a symbol" as a **sweep**, not a single edit.
   Grep every one of these locations for the old name before considering the
   change done:
   - `R/*.R` (the actual code)
   - `README.Rmd` (prose + live chunks)
   - `vignettes/*.Rmd` (prose + live chunks)
   - `_pkgdown.yml` (`reference:` sections)
   - `tests/manual/*.R` (not run by `R CMD check`, easy to forget)
   - `NEWS.md` (stale breaking-change bullets referencing the old behavior)

2. When adding missing README entries, **never guess a signature**. Extract
   the real title/usage from the generated `man/*.Rd` files instead:
   ```powershell
   foreach ($f in 'st_opts_get','st_formats', ...) {
     $c = Get-Content "man/$f.Rd" -Raw
     $t = [regex]::Match($c,'(?s)\\title\{(.*?)\}').Groups[1].Value -replace '\s+',' '
     $u = [regex]::Match($c,'(?s)\\usage\{(.*?)\n\}').Groups[1].Value -replace '\s+',' '
     Write-Output "$f | $t | $u"
   }
   ```

3. After any documentation sweep, re-run the full verification protocol
   (`R CMD build` + `R CMD check --as-cran`) — vignette live chunks that call
   a since-unexported function will fail the build, not just look wrong.

## Prevention

- Whenever a PR/commit changes `NAMESPACE` (export added/removed/renamed),
  grep the whole repo for the symbol name before closing the task — do not
  assume IDE "find references" covers `.Rmd` prose and YAML config.
- When writing new README/vignette content, derive signatures from `man/*.Rd`
  or `args()`, never from memory or an older draft.
- A documentation review (e.g. `cg-documentation` agent) should periodically
  diff `NAMESPACE` exports against README/`_pkgdown.yml` reference entries —
  this is how the 8 missing entries in this cycle were actually found.

## Related

- `.cg-docs/reviews/2026-09-30-cran-release-without-partitions-review.md` —
  findings P2.11 (README gaps) and P2.12 (dangling pkgdown article redirect)
  from this same drift class.
