---
date: 2026-10-15
title: "Verify durable request convergence with installed R subprocesses"
category: "testing-patterns"
language: "R"
tags: [request-proofs, immutable-history, r-cmd-check, subprocess, windows]
root-cause: "Artifact versions, execution attempts and requested input pins answer different questions; result equality or in-memory tests alone cannot establish durable execution proof."
severity: "P1"
related: [".cg-docs/solutions/testing-patterns/2026-10-02-in-process-testthat-segfault.md", ".cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md", ".cg-docs/solutions/bugs/2026-10-02-st-opts-test-state-leak.md"]
plan: ".cg-docs/plans/2026-10-14-m2-stamp-generic-gaps.md"
reviewed-in: ".cg-docs/reviews/2026-10-14-m2-stamp-generic-gaps-review.md"
---

# Verify Durable Request Convergence With Installed R Subprocesses

## Problem

The stamp generic-request work needed to prove more than successful saving:
after A changes from A1 to A2, B must execute against A2, yet may retain B1 when
its result and producing proof are unchanged. C should then skip against B1.
The old B1 snapshot must still name A1, while a new execution receipt names A2.
The next identical request must perform no work, including after a fresh R
process starts.

Reviews found failures that an ordinary green save/load test did not cover:
unintended replacement of explicit historical pins, unverified same-size parent
byte edits, representation-dependent request IDs, abandoned receipt publication,
legacy metadata reinterpretation and configuration errors recorded as permanent
execution failures. These were corrected with real-store regressions.

The existing Windows in-process testthat crash lesson also made the verification
boundary important. Requiring a VM/container for ordinary trusted local package
checks proved unnecessary for this task; the user approved a disposable local
source/build/test copy instead. That is process hygiene, not OS security
containment.

## Root Cause

An artifact version records immutable producing provenance. An execution receipt
records an actual attempt against an effective request. A currentness decision
checks a new caller request against durable facts. Conflating these permits a
save comparison, a later parent selection, or a successful-looking return value
to stand in for execution that never happened.

Tests also need the same identity and persistence rules as production. Windows
path normalization can change drive-letter case after earlier normalization;
serialization-v3 ALTREP representations can differ for equal typed vectors;
JSON simplification can alter metadata container shapes. None of these should
silently change requested input identities or immutable history.

## Solution

### Use A Disposable Installed-Package Gate

Audit selected tests/helpers and source hooks for real external reads, writes,
network calls and cleanup targets. Preflight the installed runtime and required
dependencies; do not install/update packages to make an unexplained test pass.
Copy an explicit package-file allowlist into a disposable source tree, excluding
Git metadata, agent/configuration trees and execution reports. Audit the built
tarball before checking it.

Start fresh R subprocesses with temporary home/cache/temp and installation-library
paths set before R starts. Preserve observed installed dependency libraries in
the child search path. Use `NOT_CRAN=true` for the intended non-CRAN tests and
record every optional/unconditional skip. A filtered run is partial evidence,
never the final full-suite gate.

A fresh process prevents cross-run leakage, not interference between tests in
one suite. Scope package options with the actual `local_st_opts()` fixture and
restore mutable aliases/builders/formats explicitly where a test changes them.
Base `options()` cannot restore stamp's private option environment.

The following PowerShell 5.1 template assumes the preflight has defined the
runtime, disposable source/build paths and scratch library, and that the caller
runs it from the disposable build directory:

```powershell
& "$r_home/bin/R.exe" --vanilla CMD build --no-build-vignettes --no-manual $source_copy
if ($LASTEXITCODE -ne 0) { throw 'Package build failed.' }
& "$r_home/bin/R.exe" --vanilla CMD check --no-manual --no-vignettes --no-examples --library=$scratch_library $tarball
if ($LASTEXITCODE -ne 0) { throw 'Package check failed; inspect its logs.' }
```

Inspect the native exit, `00check.log` and `tests/testthat.Rout*`; a zero native
exit is not proof of a warning-free check. These exclusions establish a bounded
implementation gate, not a clean full CRAN-release check. Run new examples and
documentation chunks separately when they are outside that gate. A release
still needs its approved release-check protocol.

No in-process crash was reproduced in this run: the earlier R 4.5.1/Windows
finding informed the safe choice. The new installed-subprocess evidence used
R 4.5.2 on Windows Server 2022. Other platforms/runtime versions were not tested
by this execution.

### Assert The Durable Boundary, Not Just Equal Data

Use real temporary stores and actual registered builders. In the retained-B1
fixture, assert all of the following:

1. A1/B1/C1 exist with exact validated parent pins and persisted byte checksums.
2. Changing A's calculation/input produces A2 and invokes B exactly once.
3. Equal B content, producing components, semantic schema/values and physical
   format retain the exact B1 version ID; the new receipt binds A2.
4. Original B1 snapshot bytes, sidecars and A1 parent pin remain unchanged.
5. C has zero invocations because its effective input is still B1.
6. An identical repeat creates no version, receipt or other store-byte change.
7. A separate installed `Rscript --vanilla` process reopens the store and repeats
   the same zero-invocation, same-pin and unchanged-store assertions.
8. Changing B's own component or semantic proof instead creates a new version
   even for equal data, so the parent-only cutoff cannot mask changed code/rules.

The fresh-process test must use the run's installed library, not pkgload or a
stale globally installed package. Save only temporary fixture inputs/scripts and
return results explicitly. Check child exit status as well as its result file.
See the executable fixture in `tests/testthat/test-m2-rebuild.R`.

`st_save()` returning a retained pin is not execution proof by itself.
`st_record_outcome()` can publish externally classified failed/blocked facts,
not success. Only the actual successful rebuild path publishes reusable success
after storage/proof validation. Data-free readers may stream byte checksums;
data-free does not mean zero I/O.

### Preserve Identity And Failure Semantics

| Regression | Durable rule |
|---|---|
| Selected A skips at A2, child explicitly requests A1 | Preserve A1. Rebind concrete pins only after actual upstream execution; a skip can fill only a deferred pin. |
| Missing builder registration | Recoverable configuration block, not `failed_unknown` from an execution that never ran. |
| Deterministic failure followed by blocked observations | Keep the governing actual failure; require its review ID plus changed input/component proof. |
| External failure | At most one attempt per new analyst-started call; no internal retry. |
| Legacy parent bytes edited without changing size | Missing persisted checksums cannot certify modern parent proof; equal size is not validation. |
| Next receipt directory exists without a commit marker | Preserve it as non-authoritative pending state; publish a distinct validated attempt instead of overwriting it. |
| Equal typed values with different ALTREP representations | Canonicalize values/order before digesting; do not let representation change request identity. |
| Shared retained ancestry in a DAG | Use operation-local active/completed validation state; reject cycles and discard proof caches before/after writes. |
| Legacy descriptive lists resemble proof fields | Require an explicit modern discriminator; identified partial modern proof blocks, rather than becoming legacy recovery. |

The internal path implementation applies the existing platform normalizer after
`fs::path_norm()` to both root and artifact. Do not add unconditional lowercasing
on case-sensitive platforms or normalize test fixtures to hide registry bugs.

The typed proof codec uses serialization version 2 to materialize ALTREP while
retaining types, names and declared shape; sanitized result hashing is a separate
operation. This illustrates the representation regression:

```r
proof_bytes <- function(x) serialize(x, NULL, version = 2L)
stopifnot(identical(proof_bytes(1:3), proof_bytes(c(1L, 2L, 3L))))
stopifnot(!identical(proof_bytes(1L), proof_bytes(1)))
```

Schema descriptors carry scalar/vector meaning, and the semantic envelope keeps
optional absence, NULL, typed NA and empty vectors distinct. Caller-declared
component coverage remains a trust boundary: a matching source SHA alone does
not prove that all helpers/constants/rules were included.

### Record Exactly What Passed

The final implementation run recorded **PASS1873 / FAIL0 / WARN9 / SKIP7**.
The nine warnings and seven skips were the existing baseline cases; no required
new scenario skipped. Two R CMD check warnings remained because vignette
generation was excluded. Both new Rd examples and both new approved-vignette
chunks passed separate installed-R smoke tests. Exact baseline-plus-two exports
were checked, and the 140-file tested source-copy manifest matched the worktree.

These are dated observations, not future acceptance constants. Recompute the
counts, manifest and runtime/dependency identities for the next change. All
eight local gates were established: V1, V2, V3, V4, V5, V7, V8 and V9. Umbrella
V6/L-authority integration, whole-M2 certification, full CRAN checking, OS
containment and SMB/multiwriter guarantees were not established.

## Prevention

- Keep artifact versions, actual execution facts and requested-currentness
  decisions separate in APIs, storage and assertions.
- Validate exact request/schema/parent/byte proof before invoking a builder;
  never infer success from output equality or a status-only return.
- Test first-build deferred graphs, explicit historical pins with selected
  skipped parents, interrupted publication and same-size corruption explicitly.
- Preserve existing legacy reader behavior without treating absent/invalid modern
  proof as equivalent; require complete modern envelopes and exact pinned reads.
- Use fresh installed-process checks and byte-level real-store/restart assertions;
  do not substitute mocked persistence, a filtered test or no terminal output.
- Select isolation proportionate to trusted local package work. Environment
  variables do not prevent host/network access by arbitrary dependency hooks.
- Generate documentation in scratch, inspect the entire delta, transfer only
  approved outputs and smoke-test the real installed export surface.
- Enforce the approved write set, including line-ending-only changes. Do not
  expand documentation scope or silently count umbrella evidence as local proof.

## Related

- [Earlier in-process Windows crash](2026-10-02-in-process-testthat-segfault.md):
  historical diagnosis; this entry extends its verification pattern rather than
  claiming a new crash reproduction or superseding release checks.
- [Prevent documentation/API drift](../bugs/2026-10-02-docs-describe-nonexistent-api.md):
  still applies; the new public exports did not make private hash helpers public.
- [Restore actual package option state](../bugs/2026-10-02-st-opts-test-state-leak.md):
  process isolation does not replace correct within-suite fixture cleanup.
- [Selected plan](../../plans/2026-10-14-m2-stamp-generic-gaps.md).
- [Execution evidence](../../work-reports/2026-10-15-m2-stamp-generic-gaps.md).
- [Phase review](../../reviews/2026-10-14-m2-stamp-generic-gaps-review.md) and
  [final verification](../../reviews/2026-10-14-m2-stamp-generic-gaps-verify-review.md).
- [Real-store and fresh-process regression](../../../tests/testthat/test-m2-rebuild.R)
  and [approved user guide](../../../vignettes/builders-plans.Rmd).
