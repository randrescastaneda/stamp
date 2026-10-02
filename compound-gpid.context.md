# Project Context

Additional context for Copilot and the Compound GPID plugin. Edit freely —
this file is committed to git and shared with the team.

## Data Sources
<!-- Where does data come from? File paths, databases, APIs, vintage conventions -->

## Domain Rules
<!-- Project-specific rules that Copilot should always follow -->

### Sweep documentation when an export changes

Renaming, removing, or unexporting a symbol requires checking `README.Rmd`,
`vignettes/*.Rmd` (including live chunks), `_pkgdown.yml` `reference:`
sections, `tests/manual/*.R` (not run by `R CMD check`), and `NEWS.md` — not
just `R/` and `NAMESPACE`. This drift has recurred five times in one session
(`st_auto_partition`, `st_hash_code`/`st_hash_file`, `.qs` format,
`st_formats()`'s own example comment, and 8 README gaps found only by a
documentation review). When adding doc entries, extract signatures from
`man/*.Rd`, never from memory. See
`.cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md`.

### Verify with R CMD check, not in-process testthat

In-process `testthat::test_local()`/`test_file()` segfaults R (exit
`0xC0000005`) with zero output in this environment's terminal — this is a
harness artifact, not a package defect; the same suite passes cleanly inside
`R CMD check`'s subprocess every time. Treat `R CMD build` + `R CMD check
--as-cran` as the verification protocol, and never read "no terminal output"
as "nothing executed" — a crash can discard a buffered test summary. See
`.cg-docs/solutions/testing-patterns/2026-10-02-in-process-testthat-segfault.md`.

## Work in Progress
<!-- Modules, features, or migrations currently underway -->

## Workspace Notes
<!-- Related folders, dependencies on other projects in the VS Code workspace -->

## Wiki Configuration
<!-- folder: wiki -->
<!-- audience: developers | researchers | end-users -->
<!-- tone: technical | conversational | formal -->
