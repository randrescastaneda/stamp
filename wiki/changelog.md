# Changelog

<!-- cg:auto:version-history -->
## Version History

### 2026-10-15 — Feature-Branch Snapshot (Not A Release)

`DESCRIPTION` version: `0.0.11`. Source: `feat/m2-stamp-generic-gaps`, commit [`9a894f7ed2982424a5bd1a131df5867600029399`](https://github.com/randrescastaneda/stamp/commit/9a894f7ed2982424a5bd1a131df5867600029399). This feature work is not merged or released to CRAN.

- Adds public `st_execution_info()` and `st_record_outcome()` for data-free execution inspection and failed/blocked facts; the public surface has 39 exports.
- Adds explicit request-aware planning and revalidation, immutable execution receipts, retained-output convergence, failure/review gates and typed semantic history.
- Keeps raw saves separate from execution proof and exact historical metadata separate from current sidecars. Preserves explicit historical input pins when a selected parent skips.
- Initializes this four-page wiki with managed sections and automatic API-reference ownership.

Wiki enrichment followed the requested commit/push → wiki initialization → Compound sequence. Wiki/Compound documentation was generated after feature commit `9a894f7ed2982424a5bd1a131df5867600029399` and is versioned separately from that feature SHA. The [publication and ownership record](../.cg-docs/solutions/git-workflows/2026-10-15-publish-before-wiki-compound.md) explains this boundary and the preserved manual/user-owned content rules. Explicitly authorized follow-up maintenance resolved the missing build exclusion by adding `^wiki$` to `.Rbuildignore`. A source wiki is not automatically hosted as a GitHub Wiki; neither this exclusion rule nor this entry establishes a fresh package-check result or successful follow-up push.

The [dated verification record](../.cg-docs/solutions/testing-patterns/2026-10-15-installed-r-checks-for-durable-request-convergence.md) reports **PASS 1873 / FAIL 0 / WARN 9 / SKIP 7** from installed-R subprocess checks on R 4.5.2 / Windows Server 2022. It also reports two check warnings from excluded vignette generation and separate smoke tests for new Rd examples and approved-vignette chunks. These are historical observations, not checks run during wiki initialization.

That bounded check excluded vignette generation, manuals, vignettes and examples from parts of the build/check gate. It is not a clean full CRAN check or certification of whole-M2, producer integration, OS containment or SMB/multiwriter safety. See [NEWS.md](../NEWS.md) for the package's broader development history.
<!-- cg:auto:end -->

← [Home](README.md)
