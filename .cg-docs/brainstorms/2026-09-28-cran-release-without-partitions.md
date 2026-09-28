---
date: 2026-09-28
title: "Ship stamp to CRAN without partitions"
status: decided
scope: "Standard"
artifact-schema-version: 1
chosen-approach: "Approach A — Unexport in place"
tags: [cran, release, api-surface, partitions, packaging]
---
<!-- Valid status values: decided, in-progress, abandoned -->

# Ship stamp to CRAN without partitions

## Context

`stamp` is being prepared for a first CRAN submission on the `ready_cran`
branch. The sidecar-metadata and versioning features are considered solid,
but the Hive-style partition feature is not.

Publishing to CRAN establishes a public API contract. Shipping
`st_write_parts()` and friends now would lock in argument names and
semantics that are still expected to change, forcing a breaking change in a
later release.

Partition surface area at the time of this brainstorm:

- 5 exported functions (`st_part_path`, `st_save_part`, `st_write_parts`,
  `st_list_parts`, `st_load_parts`) out of 43 total exports
- `R/partitions.R` (~700 lines, 6 internal helpers)
- `tests/testthat/test-partitions.R`, `tests/testthat/test-write-parts.R`,
  and partition tests mixed into `tests/testthat/test-vignette-issues.R`
- `vignettes/partitions.Rmd`
- Mentions in `DESCRIPTION`, the README tagline, and the project charter
- An inert `partition_key` argument on `st_path()`, documented as
  "not used in M2"

## Requirements

**Why partitions are not ready.** The stated concerns were unsettled API
design, suspected correctness bugs, missing integration with the
versioning/sidecar/retention machinery, and untested performance. On
challenge, the author clarified that the correctness concern is a **hunch,
not a known defect** — the tests pass. The substantive issue is that
partitions have only ever been exercised by agent-generated tests and have
**never been run against real data**. This is a confidence gap, not a
correctness claim.

**Blast radius.** Nobody uses the partition functions — not in production,
not in the author's own PIP/analysis code, not by teammates. Removal
therefore breaks no existing caller and needs no migration path.

**Visibility.** Partitions should be *invisible* in the CRAN release: no
mention in README, DESCRIPTION, vignettes, or documentation. Not
"experimental", not "coming soon" — simply absent.

**Timeline.** Submission targeted within days.

**Dependencies.** `nanoparquet` stays in Imports regardless; it also backs
the general `.parquet` handler in `R/format_registry.R`.

## Approaches Considered

### Approach 1: Unexport in place — CHOSEN

Keep `R/partitions.R` in the package but strip it from the public API:
drop `@export` in favour of `@noRd`, delete the generated man pages, move
the vignette to `vignettes/articles/` (already covered by `.Rbuildignore`),
rewrite tests to call `stamp:::`, and scrub partition references from
prose.

- **Pros**: single reversible commit; no branch divergence; partition code
  keeps running in CI so the dev work stays honest; `@noRd` means CRAN never
  checks those examples.
- **Cons**: ~700 lines of unexported code ship in the tarball; `:::` in
  tests is mildly ugly.
- **Effort**: Small.

### Approach 2: Full excision on the release branch

`git rm` the partition source, tests, and vignette from `ready_cran`; keep
them on a dev branch and merge back after acceptance.

- **Pros**: minimal tarball; no dead code.
- **Cons**: two diverging histories during CRAN review, when every reviewer
  fix would have to land twice; loses CI coverage of partitions exactly
  while they are being fixed.
- **Effort**: Medium, plus an ongoing merge tax.

### Approach 3: `.Rbuildignore` exclusion — rejected as non-viable

`NAMESPACE` is generated from source and would still export functions whose
definitions were excluded, so `R CMD check` on the tarball fails. Making it
work requires a hand-maintained `NAMESPACE` that silently disagrees with the
source tree, violating the charter constraint "fail loudly, never silently".

## Decision

**Approach A (unexport in place).** With zero current users, the cost of
removal is near zero, while the cost of publishing an API that is expected
to change is a breaking release. Keeping the code in-tree and under test
preserves the work and makes re-export a one-line change once partitions
have been validated against real data.

### Supporting evidence: `R CMD check --as-cran` baseline

Run on 2026-09-28 against `stamp 0.0.11` (R 4.5.2). Result:
**1 ERROR, 1 WARNING, 6 NOTEs.**

Note: the local check initially failed outright because the user's personal
`~/.Rprofile` calls a `set_lib_paths()` helper that blanks `.Library` and
`.Library.site`, hiding base packages from the check subprocess. Workaround:
set `R_PROFILE_USER` to an empty file and pass the session's `.libPaths()`
through `R_LIBS`.

Environment-only, not package defects:

| Finding | Cause |
|---|---|
| ERROR: PDF manual, `pdflatex is not available` | No LaTeX installed locally |
| WARNING: LaTeX errors creating PDF | Echo of the above |
| NOTE: `stamp-manual.tex` in check dir | Debris from the aborted LaTeX run |
| NOTE: unable to verify current time | Corporate proxy blocks the time endpoint |

Real package issues, all mechanical:

1. `.Rbuildignore` gaps — `.kilo` is not ignored, so an entire git worktree
   (`.kilo/worktrees/alder-port/.git`) ships in the tarball; the
   `compound-gpid*.md` files also sit at top level. Needs `^\.kilo$` and
   `^compound-gpid.*\.md$`.
2. `DESCRIPTION` Description starts with the package name ("Stamp saves R
   objects with...") — CRAN rejects this.
3. Malformed roxygen at `R/version_store.R:733-735`: the title line is
   duplicated after `@keywords internal`, so the whole prose block was
   swallowed into the tag and emitted 32 junk `\keyword{}` entries. The
   function also lacks `@noRd`, unlike its neighbour, so it generates a man
   page at all.
4. Unescaped `<...>` in roxygen produces invalid HTML — 19 sites across
   `R/utils.R`, `R/IO_core.R`, `R/hashing.R`, `R/version_store.R`,
   `R/format_registry.R`, `R/partitions.R`. Wrap in backticks or `\verb{}`.

**Key finding**: there are no filespace violations, example failures, test
failures, or vignette failures. Partition removal was expected to be on the
critical path to CRAN; it is not. Nothing is blocked. The decision therefore
rests purely on the API-contract argument, which is where it was made.
Minor synergy: unexporting removes `st_part_path.Rd` and with it one of the
19 invalid-HTML sites.

Expected post-fix status: 1 NOTE (New submission), which is normal.

## Next Steps

Handoff to `/cg-plan`. Two workstreams, independent of each other:

**Partition removal (Approach A)**

1. Replace `#' @export` with `#' @noRd` on the five partition functions;
   re-run `devtools::document()` so they leave `NAMESPACE`.
2. Delete the generated `man/st_*part*.Rd` files.
3. Move `vignettes/partitions.Rmd` to `vignettes/articles/`.
4. Rewrite `tests/testthat/test-partitions.R`,
   `tests/testthat/test-write-parts.R`, and the partition tests inside
   `tests/testthat/test-vignette-issues.R` to call `stamp:::`.
5. Decide the fate of the inert `st_path(partition_key=)` argument.
6. Scrub "partitions" from `DESCRIPTION`, the README tagline, and the
   `## Objective` section of `compound-gpid.md`.

**CRAN blockers (independent of partitions)**

7. Add `^\.kilo$` and `^compound-gpid.*\.md$` to `.Rbuildignore`.
8. Rewrite the `DESCRIPTION` Description so it does not open with the
   package name (combine with step 6).
9. Fix the malformed roxygen block at `R/version_store.R:733-735`.
10. Escape the 19 unescaped `<...>` sites in roxygen comments.
11. Install TinyTeX locally so the PDF-manual check actually runs.
12. Re-run `R CMD check --as-cran` and confirm 1 NOTE.

**Deferred to post-CRAN dev**

13. Add partitions to the roadmap as a post-CRAN milestone. The concrete
    exit criterion for re-export is: `st_write_parts()` exercised against a
    real PIP-scale dataset, plus settled argument semantics and integration
    with versioning/sidecars/retention.
