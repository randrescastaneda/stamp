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

### Keep versions, execution facts and requested currentness separate

An unchanged raw save is not proof of builder execution. A new execution receipt
may bind A2 to retained B1, but B1's original sidecars and A1 provenance remain
immutable. A selected skipped parent must not replace a child's explicit
historical input pin. Modern certification requires persisted byte references,
not equal file size. Missing builder configuration is a recoverable block, not
an actual unknown execution failure. Declared helper/constants/rules remain a
caller coverage responsibility; source SHA alone is insufficient.

Use typed proof encoding separately from sanitized result hashing. Apply the
existing platform path normalizer after fs normalization; do not lowercase
case-sensitive platforms or hide production identity mismatches in fixtures.
See `.cg-docs/solutions/testing-patterns/2026-10-15-installed-r-checks-for-durable-request-convergence.md`.

### Distinguish bounded local checks from release certification

For ordinary trusted local package work, use a disposable package-file copy and
fresh installed-R build/check subprocesses with scratch temp/home/cache/library
settings established before startup. Inspect exits, test summaries, explicit
skips and the tested-source manifest. These settings are process hygiene, not
OS/network enforcement. Real-store receipt/pin/byte assertions and a separate
installed-R restart establish persistence; pkgload or output equality do not.

The earlier `--as-cran` guidance remains a release protocol. A bounded gate with
`--no-build-vignettes`, `--no-manual`, `--no-vignettes` or `--no-examples` is not a
clean full release check; separately smoke-test new excluded examples/chunks.
The historical in-process crash was observed on R 4.5.1; the 2026-10-15 installed
checks used R 4.5.2 without attempting another in-process crash reproduction.
Passing assertions do not erase warnings/skips or establish umbrella V6,
producer integration, SMB/multiwriter safety or whole-M2 certification. Fresh
processes do not isolate tests within one suite: use `local_st_opts()` and
restore changed registries explicitly; base `options()` cannot restore the
package's private option state.

## Work in Progress
<!-- Modules, features, or migrations currently underway -->

## Workspace Notes
<!-- Related folders, dependencies on other projects in the VS Code workspace -->

## Wiki Configuration
<!-- folder: wiki -->
<!-- audience: developers | researchers | end-users -->
<!-- tone: technical | conversational | formal -->
