---
date: 2026-10-15
depth: standard
type: standard
plan: .cg-docs/plans/2026-10-14-m2-stamp-generic-gaps.md
findings:
  P1.1: fixed
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: fixed
  P2.5: fixed
  P3.1: fixed
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P2.6: fixed
  P2.7: fixed
  P2.8: fixed
  P2.9: fixed
  P2.10: fixed
  P2.11: fixed
  P2.12: fixed
  P1.5: fixed
  P1.6: fixed
  P2.13: fixed
  P2.14: fixed
  P2.15: fixed
  P2.16: fixed
  P2.17: fixed
---

# Phase 1 Review Report

Review mode: standard. Auto route: documentation-only changes, raised from light by more than 50 non-test lines. Eight required specialist reviews completed with usable output. Scope is the execution contract report, active-state pointer, and permitted Plan frontmatter, not package implementation. Six unique findings: P0 0, P1 1, P2 5, P3 0. Duplicate documentation/testing findings are merged below. All findings are manual contract decisions; none was automatically promoted to approved behavior.

## Findings

- **[P1.1] [cg-architecture] [manual]** `.cg-docs/work-reports/2026-10-15-m2-stamp-generic-gaps.md`, D5-B/D5-F: mandatory available parent version pins cannot represent the initial A -> B build when A has no snapshot. Define a strictly preview-only deferred parent representation and require fully resolved pins before execution/success publication.
- **[P2.1] [cg-testing, cg-documentation] [manual]** Same report, D5-A: request-aware `st_should_save` has no exact return/blocked contract. Define typed fields, usable retained pins, and the distinction between save eligibility and rebuild execution/currentness.
- **[P2.2] [cg-testing, cg-documentation] [manual]** Same report, D5-C: persisting a later blocked attempt leaves its effect on deterministic/external-failure recovery undefined. Preserve the governing execution failure across blocked observations and specify restart behavior.
- **[P2.3] [cg-data-quality] [manual]** Same report, D5-C/D5-D: missing-output recovery conflicts with invalid committed-proof blocking. Distinguish absent current materialization, missing retained snapshot, and corrupt metadata/receipt proof, and assign one decision to each.
- **[P2.4] [cg-data-quality] [manual]** Same report, D5-E: metadata/request-semantic containers lack duplicate-name and undeclared-field rules. Reject ambiguous semantic values before comparison/writes while preserving legacy calls.
- **[P2.5] [cg-data-quality] [manual]** Same report, D5-B: request `format` lacks type/registry/normalization rules. Require a canonical registered physical format and agreement with save/receipt proof before invocation.

## Passed

- cg-code-quality: no issues found in the document-only scope; no runtime claim.
- cg-version-control: no issues found; `.Rbuildignore` excludes `.cg-docs`; pre-existing dirty paths preserved.
- cg-reproducibility: no issues found; proposal/approval/runtime evidence remained distinct.
- cg-performance: no issues found at the approved serial local scope.
- cg-testing, cg-documentation, cg-architecture, cg-data-quality: usable findings returned and merged above.

## Resolution Status

Parsed six finding IDs. The user selected `Approve D5 R2`, approving the exact `Phase 1 Contract Amendment R2` in the execution report. Its six numbered clauses resolve P1.1 and P2.1-P2.5 respectively; R1 is preserved and superseded only at those explicit points. All six contract findings are fixed; no findings are skipped or open. No package source/test change was made and no package test was run. The requested final `/cg-review mode:verify` remains pending until the remaining work is executable/completed.

## Phase 2 Automatic Review

Standard route, eight specialists, all usable. Seven returned no substantive gate issue; reproducibility/data-quality reported the same metadata defect, merged below. Scope: Minimal Local Verification revision, Run 3 runtime/fixture/baseline evidence, active-state and disposable runner. The new user-approved approach deliberately does not certify OS containment or a clean CRAN check.

- **[P3.1] [cg-reproducibility, cg-data-quality] [safe_auto]** `.cg-docs/active-state/current.json:12`: V7 still said `preflight-pending` after the baseline gate completed. Fixed by synchronizing V7 evidence to passed at the Phase 2 boundary and refreshing the timestamp. No runtime/source behavior changed.

Phase 2 review: one unique P3 finding, fixed; no remaining findings. Baseline suite evidence remains 402 passes, zero failures, nine warnings, seven existing skips; known excluded-vignette check warnings recorded in the execution report.

## Phase 3 Automatic Review

Full route for durable storage and semantic wire schema: eight standard specialists plus adversarial and prior-learnings review, all usable. Ten unique findings after merging duplicates. Prior learnings/Git review found no additional defect. Pending Phase 4 scheduling and Phase 5 generated docs/exports were excluded from findings, as planned.

- **[P1.2] [cg-reproducibility, cg-architecture, cg-adversarial] [manual]** `R/execution_state.R:210-214,320-322`: unchecksummed legacy parent snapshots can be changed with equal byte length without invalidating modern child proof. Require a persisted validated byte reference for modern parent certification; do not rewrite original snapshots. Severity P1, not the adversarial P0 proposal: this is a bounded legacy-input integrity defect, not an unconditional system-wide failure.
- **[P1.3] [cg-testing, cg-reproducibility] [manual]** `R/execution_state.R:440-464`: an abandoned actual next sequence/digest directory prevents retry publication, despite not being committed authority. Preserve pending files and allocate a distinct valid attempt identity; regression must use the actual colliding name.
- **[P1.4] [cg-adversarial] [safe_auto]** `R/format_registry.R:418-427`: modern both-sidecar output followed by a legacy single-format write can leave a stale contradictory counterpart. Remove obsolete current counterparts on that transition without touching history.
- **[P2.6] [cg-reproducibility] [safe_auto]** `R/execution_state.R:155-156`: serialization-v3 ALTREP representations can produce unequal IDs for identical typed values. Use a representation-independent canonical encoding and test compact sequence versus ordinary vector.
- **[P2.7] [cg-performance] [manual]** `R/execution_state.R:263-272`: repeated traversal of shared snapshot ancestors is exponential in layered DAGs. Use operation-local active/completed traversal state, preserving cycle rejection and no stale cross-call cache.
- **[P2.8] [cg-data-quality] [safe_auto]** `R/execution_state.R:277`: converting raw JSON schema/sequence before validation accepts fractional/character/logical records. Validate exact numeric-integral/range structure before coercion and test checksum-valid malformed records.
- **[P2.9] [cg-testing, cg-documentation, cg-data-quality, cg-architecture] [manual]** `R/format_registry.R:308-320`: arbitrary legacy semantic/execution descriptive lists can be mistaken for typed proof. Add reliable modern-format discrimination and nested legacy regressions while still rejecting identified corrupt modern proof.
- **[P2.10] [cg-code-quality] [manual]** `R/IO_core.R:1081-1114`: partial modern execution envelopes become legacy missing-proof recovery. Known modern records with incomplete execution proof must block before writes, including raw saves without receipts.
- **[P2.11] [cg-code-quality, cg-architecture] [manual]** `R/format_registry.R:495-498`: legacy JSON-first reads eagerly parse an unused corrupt QS2 counterpart. Preserve lazy legacy access; modern proof still requires complete dual-sidecar validation.
- **[P2.12] [cg-testing] [manual]** `R/version_store.R:472-479`: historical data loading selects filename extension rather than the pinned saved physical format. Read the exact snapshot's format, with explicit legacy fallback only where needed; test actual format override/change with real readers.

All ten fixed and regression-tested by the execution owner. P1.2: strict persisted checksums for certified effective/original inputs; legacy diagnostics remain available. P1.3: non-authoritative pending-directory collision preserves files and selects a distinct validated suffix. P1.4: stale current counterpart removed on single-sidecar writes. P2.6: serialization-v2 materializes ALTREP, retaining typed equality. P2.7: operation-local active/completed and strict-pin memoization. P2.8: raw scalar numeric/integral/range validation precedes coercion. P2.9/P2.10: independent explicit protocol marker under existing reserved `attrs` distinguishes modern proof and rejects damaged envelopes without reinterpreting legacy nested descriptions. P2.11: legacy JSON-first short-circuit preserved. P2.12: historical loads use the pinned saved physical format.

Added 20 focused regression cases before the remediation source patches; no assertions weakened or skips added. Full unfiltered disposable installed-package run `build/run-20261015-122016854/stamp.Rcheck` passed **FAIL0 / WARN9 / SKIP7 / PASS1382**, native exit 0, no new static NOTE. Three known check warnings remain: deferred Phase 5 Rd mismatch plus the two approved excluded-vignette warnings. `git diff --check` passed. No open Phase 3 findings remain; final verification review is still scheduled after all phases.

## Phase 4 Automatic Review

Full route: ten agents, all usable, six unique findings. The primary convergence/full-suite PASS1788 evidence predates these new corner-case regressions. No Phase 3 finding was reopened. Scope and prior-learnings/performance checks found no additional defect.

- **[P1.5] [cg-code-quality, cg-testing, cg-reproducibility, cg-architecture, cg-adversarial] [safe_auto]** `R/rebuild.R:699-704`: a selected skipped parent overwrites the child's explicit historical pin, although no upstream execution occurred. Preserve explicit pins on skip; fill only deferred pins or rebind after built/unchanged execution. Test selected A2 skip with child explicitly pinned to A1. Classified P1 rather than proposed P0 because the defect is a bounded input-substitution case, not universal catastrophic failure.
- **[P1.6] [cg-data-quality, cg-adversarial] [safe_auto]** `R/rebuild.R:747-775`: missing/invalid builder configuration is classified as an actual unknown execution failure and permanently suppresses recovery. Validate/resolve builders before actual execution classification; use argument rejection or recoverable blocked observation. Test registration repair and invalid explicit function.
- **[P2.13] [cg-testing, cg-documentation, cg-reproducibility, cg-architecture, cg-adversarial] [safe_auto]** `R/rebuild.R:602-617`: included target without a supplied recipe can vanish into an empty successful plan. Reject incomplete included-target boundaries before execution; test empty/unrelated/partial request lists and zero writes.
- **[P2.14] [cg-architecture] [manual]** `R/rebuild.R:750-755`: relative builder registration uses working-directory identity while modern recipes use alias-root identity, so valid registrations cannot resolve. Preserve the original registration path internally and resolve it consistently for modern lookup without changing legacy registry behavior or public formals.
- **[P2.15] [cg-data-quality] [safe_auto]** `R/rebuild.R:759-781`: `$x` partially matches `x_backup` and accepts duplicated x fields. Require one exact x field and use exact extraction; malformed invoked builders must not publish success.
- **[P2.16] [cg-documentation] [safe_auto]** `R/rebuild.R:383`: source docs imply mode propagate/strict changes request-aware selection, but mode applies only to the legacy route. Clarify explicit-request graph and visible skip/block behavior now; generate docs in Phase 5.

All six fixed with ten additional regressions written before corrective source changes. Explicit historical pins survive selected-parent skips, actual-execution rebinding is separate, configuration blocks are recoverable without false actual failures, incomplete included targets reject before writes, private original registration paths resolve relative builders against alias roots, required x extraction is exact/unique, and source mode documentation now separates legacy/request-aware planning. No public registry columns/formals or legacy body semantics changed.

Full unfiltered installed run `build/run-20261015-131252401/stamp.Rcheck` passed **FAIL0 / WARN9 / SKIP7 / PASS1864**, native exit 0. The primary V8 and separate installed-R process convergence still pass. No new runtime warning/skip/static NOTE. Known Phase 5 documentation generation and excluded-vignette warnings remain. No open Phase 4 finding or accepted evidence exception.

## Phase 5 Automatic Review

Architecture route for public-interface surfacing: all eight specialists returned usable output. Seven found no defect; one scope finding is resolved below. Public/source/generated/API tests are consistent; exact baseline-plus-two exports and examples/chunks were independently exercised by the execution owner.

- **[P2.17] [cg-reproducibility] [manual]** `vignettes/lineage-rebuilds.Rmd`, `vignettes/hashing-and-versions.Rmd`: documentation was initially written outside the Plan's approved user-doc path. Fixed without widening scope: restored only this execution's edits in those two files, verified exact zero Git diff for both, and consolidated the tested guidance into the approved `vignettes/builders-plans.Rmd`. Corrected its obsolete legacy mode/plan descriptions while adding the request and typed-history examples. No new permission, filename or artifact exception was inferred.

The consolidated approved-vignette chunks and both Rd examples passed the fresh installed-R smoke again (`ALL_DOC_SMOKE_OK`). All 24 cumulative findings are now fixed; none skipped or open. Phase 5 final packaging rerun and final verify report are recorded in the execution report.
