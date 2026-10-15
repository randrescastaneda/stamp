---
date: 2026-10-15
title: "M2 Stamp Generic Gaps: Contracts, Safe Gates, and Conditional Implementation"
status: completed
completed-date: 2026-10-15
completed-phases: [1, 2, 3, 4, 5]
current-phase: 5
execution-report: .cg-docs/work-reports/2026-10-15-m2-stamp-generic-gaps.md
scope: "Deep"
brainstorm: "E:/PovcalNet/01.personal/wb384996/PIP/pipsystem/.cg-docs/brainstorms/2026-10-13-m2-stamp-contracts.md"
language: "R"
estimated-effort: "large"
deviation-policy: "ask"
artifact-schema-version: 1
artifact-html: false
phases: 5
tags: [m2, stamp, contracts, fingerprints, receipts, metadata, currentness, test-safety]
---

# Plan: M2 Stamp Generic Gaps

## Objective

Prepare the stamp-local work for task `m2-stamp-local-plan-2026-10-14`, milestone `m2-walking-skeleton`, feature `close-stamp-gaps-for-skeleton`. Cover `create-engine-skeleton` only at the generic producer/consumer interface boundary. Stamp remains domain-neutral and the sole rebuild authority.

The current deliverable is this planning document, not implementation. No implementation Plan/phase is approved. The user approved the completion-contract preview with `Approve Save And Validation`, authorizing this new Markdown and the listed no-output document checks only. That approval does not settle the proposed D5/D8 contracts, authorize tests, or authorize lifecycle outputs. The filename retains the requested task date; frontmatter records the actual preparation date.

After separate execution approval, implement only the applicable approved generic contracts and prove L-stamp/V2-V5 locally. Do not execute the central umbrella as a `/cg-work` target or claim engine/whole-M2 completion from local evidence.

## Context

### Execution Revision: Minimal Local Verification

On 2026-10-15 the user requested execution of all phases with automatic review and final verification. During execution the user approved exact D5 R1 and corrective R2 text in `.cg-docs/work-reports/2026-10-15-m2-stamp-generic-gaps.md`. After WSL discovery failed, the user explicitly permitted changing the approach and Plan, asked for a minimal solution, and rejected the complicated environment handoff.

This revision supersedes the planning-time approval/containment restrictions below only as follows:

- The current assistant owns execution in the existing feature worktree. The named report, active-state pointer, allowed progress fields, phase/final review reports, and enumerated implementation files are authorized by the execution request. Earlier statements that only Plan creation is authorized describe the previous planning task, not this execution approval.
- D8 uses a disposable local source copy and fresh Windows R subprocesses, not a VM/container or OS-enforced filesystem/network sandbox. Process-local temporary/home/cache/library settings and temporary test fixtures reduce accidental state leakage but are not security enforcement. Do not claim otherwise. No exhaustive transitive dependency-hook certification is required for ordinary local package tests.
- Disposable root: `C:/Users/wb384996/AppData/Local/Temp/2/kilo/m2-stamp-generic-gaps/`, with `source/stamp`, `build`, `library`, `tmp`, `home`, and `cache` subdirectories. Scratch harness scripts and build/check logs may be created only below this root. Original sources remain unchanged by build/check/generation; implementation edits remain in the worktree.
- Runtime candidate: `C:/Program Files/R/R-4.5.2/bin/R.exe`, with sibling `Rscript.exe`. A bounded `--vanilla` preflight may report R/dependency versions and library paths. Use installed dependencies only; do not install/update dependencies, enable WSL, alter ACLs/profiles/configuration, or use production data/network APIs.
- Audit package tests/helpers and source hooks for external resource paths and destructive cleanup. Build from an explicit package-file copy excluding `.git`, `.kilo`, `.compound-gpid`, `.cg-docs` and unrelated untracked/configuration files. Inspect tar contents before checking. Use process-local `NOT_CRAN=true`, isolated TMPDIR/TMP/TEMP and user/cache settings, and a scratch install library; record actual dependency source locations and skips without claiming complete OS containment.
- Candidate commands, executed separately from scratch `build`: `& "C:/Program Files/R/R-4.5.2/bin/R.exe" --vanilla CMD build --no-build-vignettes --no-manual "C:/Users/wb384996/AppData/Local/Temp/2/kilo/m2-stamp-generic-gaps/source/stamp"` and `& "C:/Program Files/R/R-4.5.2/bin/R.exe" --vanilla CMD check --no-manual --no-vignettes --no-examples "C:/Users/wb384996/AppData/Local/Temp/2/kilo/m2-stamp-generic-gaps/build/stamp_0.0.11.tar.gz"`. Confirm flags/runtime and record exact environment/outputs in the report before coding. A targeted red test runs through a fresh subprocess, never the crashing in-process editor harness; final acceptance includes the entire installed-package test suite.
- Phase 2 must establish the executable, available dependencies, disposable paths, inspected fixture safety and runnable subprocess gate. Missing dependencies or real safety failures still block; absence of virtualization alone no longer blocks. No core evidence is waived. Retain the exact D5 contracts, immutable-history guarantees, package compatibility and stamp-local scope.
- Generated docs remain limited to the approved allowlist. Run available roxygen tooling only against the disposable source copy and transfer only reviewed allowed generated deltas. No Git staging/commit/push or unrelated configuration/roadmap changes.

### Repository, Ownership, and Permissions

| Field | Fresh observation / limit |
|---|---|
| Repository | `E:/PovcalNet/01.personal/wb384996/Rpackages/stamp` |
| Active worktree | `E:/PovcalNet/01.personal/wb384996/Rpackages/stamp/.kilo/worktrees/feat-m2-stamp-generic-gaps-a89fbd2d335aef42` |
| Common Git directory | `E:/PovcalNet/01.personal/wb384996/Rpackages/stamp/.git` |
| Branch | `feat/m2-stamp-generic-gaps`, already present; no branch created or switched by this worker |
| Observed task base and save-preflight HEAD | `ad9a483b6261166a6feefc64baea5d602198977b`; original branch-creation baseline is UNKNOWN |
| Root checkout | Separate checkout on `ready_cran` at the same observed HEAD; not switched, modified, or cleaned |
| Existing dirty paths | Modified `.gitignore`, modified `compound-gpid.local.md`, untracked `.compound-gpid/`; preserve all |
| Owner | User-started stamp planning worker for this task; future implementation owner must be explicitly confirmed |
| Native session ID | UNKNOWN, permitted by the request |
| Conflict inventory | Git worktree listing shows this branch in this worktree; plan-directory reads show target absent. This is not proof of absent concurrent writers or complete session inventory |
| Loaded project identity | Stamp charter/local configuration and stamp `.kilo/AGENTS.md`; no active instruction restricts writes to pipsystem |
| Instruction limits | Root `AGENTS.md` was not found. The central brainstorm's historical pipsystem-only permission is reference data, not this session's instructions |
| Current writes | Only this new plan; no replacement, package/configuration change, report, active state, view, index, or roadmap write |

`compound-gpid.md:10-35` requires immutable traceable storage, loud failure, R >= 4.1, CRAN compatibility, and data.table/collapse style. This work aligns with those objectives. The charter's current CRAN focus requires a separate branch and explicit compatibility checks; it does not authorize changing `ready_cran` or broadening this task.

The Compound GPID workflow is available: `.kilo/commands/cg-plan.md`, `.kilo/commands/cg-work.md`, and the context-loading, goal-execution, artifact-view, and active-state contracts were read. Local configuration identifies an R package with standard review depth; absent `suites` defaults to `[cg]`. No tooling was installed or configuration changed. Successful bounded reads/Git checks and exposed tools establish practical access for this task, not universal permission enforcement or a negative sandbox test.

### Central Inputs and Source Identity

Central repository root: `E:/PovcalNet/01.personal/wb384996/PIP/pipsystem`. Fresh observed HEAD: `f1863d2e80471616842aebfa5918651c947ba50d`. A targeted Git status check was limited to these three inputs.

| Input path, relative to that root | Identity and use |
|---|---|
| `SYSTEM_DESIGN.md` | Tracked, no targeted status entry at inspection. Working source read at the observed HEAD; sections 4, 6-7, 9-11, and 14 supply policy and open boundaries |
| `.cg-docs/plans/2026-10-10-m2-walking-skeleton.md` | UNTRACKED working document, not content attributable to that HEAD. Read its context/contracts and targeted local-handoff/testing/completion sections; the initial large read was capped, and unrelated later implementation bodies were not fully loaded |
| `.cg-docs/brainstorms/2026-10-13-m2-stamp-contracts.md` | UNTRACKED working document, read in full; `status: in-progress`, `scope: Deep`. Option 1 is the bounded selected discussion approach, not blanket D5/D8 approval |

All central documents are read-only design references. Their historical package pins, approval claims, and test outcomes are not fresh runtime evidence. No other central source cited inside them was automatically opened or promoted to independently verified authority. No pipsystem file is a runtime dependency of stamp.

### Fresh Stamp Source Evidence

The short-status checks showed no package source, NAMESPACE, DESCRIPTION, or test modifications. The following are inspected working sources at observed stamp HEAD `ad9a483b6261166a6feefc64baea5d602198977b`, not tested dependencies. DESCRIPTION reports stamp `0.0.11`; installed stamp version/location is UNKNOWN.

| Surface | Inspected behavior / planning consequence |
|---|---|
| `NAMESPACE:3-40` | Public save/load/version/lineage/planning APIs exist. Partition helpers and `st_hash_code` are not exported; do not infer public support from historical notes or an Rd file |
| `R/IO_core.R:195-271,312-410,954-997` | Save predicate receives object/code, not custom metadata or new parents. Unchanged return has path/skipped/reason but no version. Publication crosses artifact/sidecar/catalog/snapshot/retention and can return a failure fallback. Existing code changes can create versions |
| `R/rebuild.R:161-342` | Executes level/path order, refreshes parent versions, saves builder results, and treats a missing save version as failure. No durable outcome contract or required post-outcome downstream cutoff is established |
| `R/rebuild.R:378-530` | Propagate frontier handling can stop before a full chain; strict traversal lacks a general visited/cycle guard. Level order is not sufficient for every multi-target DAG |
| `R/version_store.R:122-191,452-489,629-659,1170-1212` | Catalog stores versions/parents, not the proposed durable state/receipts. Snapshot copies include artifact/sidecars/parents. Staleness only compares immediate parent versions and returns FALSE in several missing states |
| `R/hashing.R:318-342` | Function code hash covers formals/body, not arbitrary closure contents or transitive helper discovery |
| `R/format_registry.R:267-347` | Current sidecar access has no version selector. JSON auto-unboxing/simplification requires explicit typed round-trip rules |
| `R/retention.R:264-435` | Pruning deletes snapshots and updates the catalog. Receipt retention and retained-output dependencies need a contract; no release-aware protection is inferred |
| `R/IO_core.R:1001-1046` | Write helpers delete/move destinations; filelock use is best-effort and has an advisory fallback. This is not a transactional/multiwriter guarantee |

Public compatibility baseline: preserve existing positional/default behavior for `st_save`, `st_load`, `st_load_version`, `st_read_sidecar`, `st_info`, `st_is_stale`, `st_plan_rebuild`, `st_rebuild`, builders, alias and version access. New request-aware behavior must not silently reinterpret old callers as fully proven modern requests.

### Prior Work and Learnings

No matching local plan exists. The two existing plan titles concern verbose suppression and CRAN release/partition unexport; neither matches the feature. The local decided CRAN brainstorm confirms partitions are parked internally, not an approved R1 solution. No phase history is being restructured.

The Brain-query skill was loaded; `.cg-docs/BRAIN.md` is absent, so no Brain traversal or query command ran. Solution directories were inspected directly. Relevant local learnings are:

- `.cg-docs/solutions/testing-patterns/2026-10-02-in-process-testthat-segfault.md:15-68`: recorded Windows R 4.5.1 crashes from direct testthat execution; use the build/check subprocess harness for authoritative verification. Its reported historical passes are not this task's results.
- `.cg-docs/solutions/bugs/2026-10-02-st-opts-test-state-leak.md:29-92`: base `options()` restoration does not restore stamp's private option store. Reuse `local_st_opts` and separately restore other mutable registries.
- `.cg-docs/solutions/bugs/2026-10-02-docs-describe-nonexistent-api.md:34-79`: verify documentation against installed exports, not remembered names or `pkgload`'s export-all behavior. Rechecked NAMESPACE controls where historical prose conflicts.

## Requirements

These R IDs are local requirements, not the unresolved central M1 R1 decision.

| ID | Requirement | Source |
|---|---|---|
| R1 | Separate exact D5 API/contract preparation from gated implementation; keep choices unresolved where necessary | Direct request; central brainstorm:244-256 |
| R2 | Approve D8 owner/write/lifecycle/runtime/containment and exact safe suite gate before coding | Direct request; umbrella:419-431 |
| R3 | Compare complete requested calculation/known-helper proof before execution; distinguish missing requested from missing saved proof | Design:203-205; brainstorm:118-150 |
| R4 | Retain B's output only in the selected unchanged-content/fingerprint/semantic-metadata parent-change case, preserving immutable execution proof and old history | Direct Option 1; brainstorm:94-108,154-158 |
| R5 | Persist missing/failed/success facts and interpret currentness durably, with analyst-started recovery and no retry loops | Design:190,209-223; brainstorm:142-150 |
| R6 | Validate, publish, retain, and retrieve execution receipts without artifact-data deserialization; reject partial or contradictory proof | Direct request; brainstorm:108,138 |
| R7 | Version semantic metadata changes and retrieve same-version historical typed metadata without loading data | Design:135-139; brainstorm:139,154-158 |
| R8 | Validate finite graph traversal/cycles and dependency-safe ordering; recheck downstream work after actual results | Umbrella:199-205,272-276,476 |
| R9 | Preserve generic public interfaces, formats, historical stores, and separate adapter/engine authority boundaries | Direct boundaries; current NAMESPACE; brainstorm:130-140 |
| R10 | Enumerate exact proposed code/test/export/generated-doc and lifecycle paths, without authorizing them now | Direct request; umbrella:426 |
| R11 | Prove L-stamp/V2-V5 with real isolated storage, separately from L-authority/V6 and whole-M2 T1-T12 | Umbrella:450-476,550-555 |
| R12 | Create/read back only this plan, report actual document validation, preserve source identities and nonempty Gaps | Direct acceptance; approved preview |

## Proposed Contracts and Decision Gates

Everything in this section is a proposal unless identified as a direct boundary or existing behavior. Approval to save is not API approval. Phase 1 may refine proposals in its separately authorized report; body changes to this plan require separate planning/revision authority, not `/cg-work` frontmatter permissions.

### D5 Decision Register

| Gate | Preferred bounded proposal | Exact approval needed / consequence |
|---|---|---|
| D5-A Request/API | Extend existing planning/rebuild/save surfaces with explicit desired requests; add two neutral access/outcome exports only if necessary | Approve exact signatures, schemas, reasons, return types, and legacy route; no illustrative signature becomes final automatically |
| D5-B Fingerprints | Required component IDs/hash/algorithm/schema cover calculation plus known result-affecting helpers/constants/rules; source SHA stored separately | Approve coverage responsibility, canonicalization, comparability and asymmetric recovery policy. Missing requested hash blocks; missing saved proof alone may permit one valid recovery build |
| D5-C Durable state | Immutable attempt/outcome records plus a recoverable current pointer; stamp interprets facts | Approve precedence, failure taxonomy, review acknowledgement and changed-input/rule eligibility. Unknown classification blocks for review; no D4/Force decision |
| D5-D Receipt | Immutable committed success proof binds exact request/input pins to a validated retained output and semantic metadata pin | Approve storage/versioning/commit format, reference integrity, idempotency, publication failure handling and data-free access |
| D5-E Metadata | Caller-declared semantic field schema; semantic changes version even when content matches; old snapshots remain unchanged | Approve reserved names, types, NA/null/empty rules, schema migration and descriptive-edit behavior |
| D5-F Code compatibility | Preserve current code-change-driven output versioning; do not extend retained-pin cutoff to changed B fingerprints | Approve this compatibility route. Any broader equivalence behavior requires another decision and revised tests/write set |
| D5-G Retention | Keep all fixture pins; refuse pruning proof dependencies still needed for reusable committed state until an approved safe policy exists | Approve exact protected-reference scope, dry-run/error behavior and invalidation of already dangling legacy state; no release registry or production retention framework |

### Proposed Interface and Path Mapping

The preferred minimal API direction below provides concrete review targets. Phase 1 must approve exact formals and decide whether new exports are necessary before Phase 3. Reject unapproved alternatives instead of silently generating more files.

| Surface | Proposed change | Implementation / generated documentation |
|---|---|---|
| `st_plan_rebuild` | Add optional named `requests = NULL`; explicit request route returns run/skip/blocked facts plus reasons and request references; preserve legacy columns/default calls | `R/rebuild.R`; `man/st_plan_rebuild.Rd` |
| `st_rebuild` | Consume approved request-bearing decisions, revalidate before each invocation, return usable retained/new version and receipt/outcome references; preserve existing required columns | `R/rebuild.R`; `man/st_rebuild.Rd` |
| `st_is_stale` | Optional named requested-proof comparison while preserving the old parent-only call as legacy inspection, never as complete new-request proof | `R/version_store.R`; `man/st_is_stale.Rd` |
| `st_save`, `st_should_save` | Approved optional request and semantic-schema inputs; unchanged successful route returns a usable version; no proof of execution from a raw no-op save alone | `R/IO_core.R`; `man/st_save.Rd`, `man/st_should_save.Rd` |
| `st_read_sidecar` | Optional explicit `version_id` selecting exactly that snapshot; NULL keeps current-reader behavior; no historical latest fallback | `R/format_registry.R`; `man/st_read_sidecar.Rd` |
| `st_execution_info` (new candidate) | Proposed `st_execution_info(path, receipt_id = NULL, alias = NULL)` returns validated immutable proof/outcome metadata, not artifact data | New `R/execution_state.R`; new `man/st_execution_info.Rd`; conditional `NAMESPACE` addition |
| `st_record_outcome` (new candidate) | Proposed `st_record_outcome(path, outcome, request, failure = NULL, alias = NULL)` records caller execution facts; success requires validated storage proof and cannot be manufactured by a status string | New `R/execution_state.R`; new `man/st_record_outcome.Rd`; conditional `NAMESPACE` addition |
| `st_prune_versions` | Enforce approved proof-reference safety and observable refusal/dry-run behavior | `R/retention.R`; `man/st_prune_versions.Rd` |
| Fingerprint/storage internals | Canonical comparison/encoding, catalog compatibility, snapshot/receipt validation; no new public hashing/discovery API | `R/hashing.R`, `R/version_store.R`, `R/format_registry.R`, `R/execution_state.R`; internal helpers use `@noRd` |

New named arguments must not capture existing positional writer arguments or change `...` forwarding. Exact placement/default behavior and export additions require D5-A approval. Prefer existing exports where possible; if an approved contract eliminates a candidate new export, omit its Rd and NAMESPACE change. Any new name/path beyond this table requires explicit amendment. Do not hand-edit NAMESPACE or generated Rd; approve the exact roxygen generation command and inspect its entire delta. No DESCRIPTION dependency/version change is proposed.

### Request, Proof, and State Shapes

Proposed request: normalized logical artifact path; explicit parent path/version pairs; explicit root declaration for no parents; component IDs/hashes/algorithms/schema; semantic schema and values; physical format; optional audit source SHAs. Keys must be nonempty, nonmissing, unique and well typed. Canonical sorting/encoding must preserve meaningful scalar/vector, integer/double, null/NA and empty distinctions. Hash algorithms/schema must be comparable; never equate NA with NA, omit a required helper, or substitute package SHA equality for calculation proof.

The caller declares known dependency coverage; stamp validates structure and compares it. No general code discovery or hidden closure capture is promised. A missing requested component blocks before builder execution. Complete requested proof plus valid parents and missing saved legacy proof may trigger recovery only after D5-B approval; successful recovery persists full reusable proof. Legacy unprovable state cannot be labeled current.

Proposed durable outcomes distinguish successful new output, successful unchanged output, deterministic failure, external failure, blocked prerequisite, and invalid/unknown proof. Stamp owns interpretation, not the event log or consumer manifest. Existing immutable success and a later failed attempt are separate facts: a failed request must not be satisfied by an older success against other inputs.

Proposed precedence: validate request/required parents first; block contradictory/partial proof and unknown failure classification; suppress unchanged deterministic failure until approved review acknowledgement plus input/rule change; external failure is eligible on the next analyst-started call with valid prerequisites; missing output without a suppressing failure is eligible only with valid inputs; verified matching success skips; changed valid inputs/fingerprints select work and trigger downstream rechecks. Decide how an initial absent outcome differs from corrupt/missing previously committed state. No automatic run, timer, retry loop, or Force override.

### Receipt Publication, Access, and Retention

Preferred layout proposal under each artifact's existing storage folder: `executions/<receipt-id>/receipt.json` with a final `COMMITTED` marker; a small current-execution reference is an index, not independent authority. Exact on-disk names/schema and collision policy need D5-D approval. Failed attempts must be durable without creating a successful artifact-version reference.

Bind the receipt ID/schema to artifact identity, output version, sanitized content hash and algorithm, persisted byte checksum, same-version semantic metadata proof/schema, requested component proof, exact parent pins, outcome and audit source identity. Timestamp/source SHA are audit fields, not equality inputs. An ID/hash is an integrity reference, not a claim of cryptographic authenticity. Do not accept success by nonempty version ID alone.

Validate outputs/snapshot/sidecar/catalog consistency before publishing reusable success. Stage files locally; expose committed proof only after every required component is complete. Pending directories, missing markers, wrong-artifact/version bindings, dangling parents/output, corrupt payloads and inconsistent indexes cannot establish currentness. Recovery can ignore incomplete staged state or report it; do not add automatic cleanup of unknown files. The serial publication guarantee must be explicit; it does not certify concurrent or SMB atomicity.

When A1 becomes A2, B may execute against A2. If B content, B calculation fingerprint and semantic metadata remain unchanged, preserve B1 and its original A1 provenance, append exactly one committed proof for the A2 request, and return B1 as a usable output pin. Keep original B1 sidecars/parents intact. A fully satisfied repeat writes no new receipt or output version. Validate this across fresh processes, not just an in-memory cache. Concurrent duplicate publication is outside the serial scope and must not be claimed safe.

Data-free receipt/metadata access means no artifact deserialization or result calculation. Metadata parsing and file-byte checksum verification may read bytes without invoking the data reader; this distinction must be explicit in API docs/tests. A receipt without a valid available output never authorizes reuse. An old retained receipt must remain accessible by its own ID rather than substituting the latest execution.

Default no-prune fixtures retain both original and latest execution dependencies. Extend `st_prune_versions` only enough for the approved generic proof-reference contract, testing dry-run and protected-output refusal. Do not silently allow a prune to turn a receipt into valid-looking success with missing output. Missing legacy dependencies are explicit invalid/unavailable state, not proof or latest fallback. Production release-aware retention remains outside scope.

### Semantic Metadata

Use generic caller-declared semantic names/types, not built-in domain fields. Equal content with changed declared semantic metadata creates a new immutable artifact version. Original provenance is not replaced by a latest receipt's parent list. Descriptive edits need not create versions; decide whether they update only current descriptive presentation or are ignored on an unchanged save, and document that historical metadata remains immutable.

Reject collisions with stamp-owned keys such as path/format/hashes/parents/version/receipt identities. Test missing required fields, duplicates, malformed schemas, scalar versus vector, integer versus double, zero-length, NA/null and JSON/QS2/both-mode disagreement. Historical reads select the exact pinned version and fail if required metadata is unavailable; no current-sidecar substitution. Existing legacy snapshots require explicit compatibility/error behavior, not a silent in-place migration.

### Graph and Engine Boundary

Requests must provide enough explicit recipe/parent information for missing outputs; reverse lookup through saved descendants alone cannot discover an unsaved recipe. Validate the relevant current dependency graph, not obsolete historical reverse edges. Resolve normalized identities/aliases consistently, visit nodes finitely, reject self/general cycles before execution, and topologically order overlapping multi-target/diamond graphs with stable tie-breaking.

Planning is side-effect-free. Candidate descendants are not commands to execute blindly: after each upstream result, stamp refreshes eligibility using actual committed output/proof. Changed B output/semantic version may invalidate C; retained B1 in the bounded case must not. Failed or invalid B blocks C while unrelated valid work can continue. Missing required parents never count as current. Revalidation must detect changed inputs between preview and execution rather than execute an obsolete plan as a commitment.

Consumer contract: callers supply recipes, fingerprints, semantic declarations and classified outcome facts; stamp returns selection/reasons/pins. A consumer may not construct snapshot paths or independently reinterpret currentness. No pipdata/pipload source changes or new runtime dependency on them. Those repositories need separate approved local Plans and tested producer pins. D4 feedback/Force, D6 manifest reference choices, D7/M1 R1 and survey-specific decisions remain external gates for their own units.

## Exact Proposed Future Write Sets

All paths are relative to this stamp worktree. Listing a path does not authorize writing it in this planning task or guarantee every path needs a change.

| Kind | Exact proposed paths | Approval limit |
|---|---|---|
| Existing source | `R/IO_core.R`, `R/version_store.R`, `R/rebuild.R`, `R/hashing.R`, `R/format_registry.R`, `R/retention.R` | Phase-specific D5/D8 approval before coding |
| New source | `R/execution_state.R` | Only approved durable-state/receipt APIs/internal helpers |
| Existing tests | `tests/testthat/test-should-save.R`, `tests/testthat/test-save-load.R`, `tests/testthat/test-info-retention-children.R`, `tests/testthat/test-sidecar-verify.R`, `tests/testthat/test-pruning.R`, `tests/testthat/helper-opts.R` | Minimal regressions/isolation extensions, no blanket suite rewrite |
| New tests | `tests/testthat/test-m2-rebuild.R`, `tests/testthat/test-m2-state.R`, `tests/testthat/test-m2-metadata.R` | Only cases not coherently housed in existing tests |
| Export file | `NAMESPACE` | Generated delta only for exact D5-A-approved exports; do not export partitions/hash helpers |
| Existing generated docs | `man/st_plan_rebuild.Rd`, `man/st_rebuild.Rd`, `man/st_is_stale.Rd`, `man/st_save.Rd`, `man/st_should_save.Rd`, `man/st_read_sidecar.Rd`, `man/st_prune_versions.Rd` | Generated from approved roxygen changes; other generator deltas require review/approval, not cleanup |
| New generated docs | `man/st_execution_info.Rd`, `man/st_record_outcome.Rd` | Conditional on approval of those exact exports |
| User docs | `vignettes/builders-plans.Rmd`, `NEWS.md` | Explain generic receipts/legacy boundaries and additive API behavior; no site/README regeneration |
| Execution report proposal | `.cg-docs/work-reports/2026-10-15-m2-stamp-generic-gaps.md` | Date is a proposed execution-date instance, not approval or an existing report. If execution starts another date, obtain exact replacement path approval before writes |
| Active-state proposal | `.cg-docs/active-state/current.json` | Confirm ownership before creation/update; no snapshots or automatic alternate names |
| Plan progress | This plan's `status`, `current-phase`, `completed-phases`, `execution-report`, `completed-date`, `failing-steps` | Only with separate `/cg-work` lifecycle approval; no body rewrite under progress permissions |

No `.gitkeep`, raw log, review artifact, HTML, index, coordination record, roadmap or protected configuration output is included. Report collisions block for explicit path approval; no automatic suffix. Active state contains compact schema-v1 pointers/evidence statuses only, not copied logs. Source/test generation writes to scratch need their own D8 roots. The report must record approvals, deviations, actual commands/exits/skips, R/runtime versions, observed versus tested commits, constraints and remaining uncertainty.

## Implementation Steps

All nine steps are future work. Preparatory phases are not executed by this planning task. Even a read-only preparation run using `/cg-work` requires explicit selected-Plan and report/active-state/progress authority before lifecycle mutation. No phase automatically rolls into the next without approval.

## Phase 1: Exact D5 API and Contract Preparation

### 1. Resolve the Bounded Public and Storage Contracts

- **Requirements**: R1, R3, R4, R5, R6, R7, R9, R10
- **Files**: Read the source/API paths above; record proposed exact decisions in the separately approved execution report. Change this plan body only with separate revision permission.
- **Details**: Re-pin source/ownership, approve D5-A through D5-G as applicable, exact formals/schema/reasons, root recipes, legacy stores, changed-fingerprint boundary, descriptive metadata policy and receipt/reference layout. Preserve current code-driven version behavior unless separately changed. Confirm new exports are necessary and lock the generated-doc list. Do not implement to answer the API questions.
- **Test Scenarios**: Complete request; missing requested helper; missing legacy saved proof; unknown status; code-changed equal output; semantic-only change; conflicting reserved name; unavailable historical metadata.
- **Tests**: Future executed contract/table/schema checks in the approved report; no package tests in this preparatory phase. Approval must reference exact text, not a generic acceptance of the brainstorm.
- **Acceptance criteria**: V1; every contract needed by the first implementation unit is approved or explicitly blocks that unit, and unresolved unrelated engine decisions are not made prerequisites for drafting this Plan.

## Phase 2: D8 Ownership and Safe Verification Preparation

### 2. Approve the Exact Execution and Test Arrangements

- **Requirements**: R2, R9, R10, R11
- **Files**: Read helpers/hooks/test resources and workflow contracts; only separately approved lifecycle paths may record results. No test runner/helper source file is authorized implicitly.
- **Details**: Confirm implementation owner, current checkout/HEAD/dirty state and disjoint write set. Approve exact lifecycle paths and source reads needed for dependency hooks. Resolve R executable, library/source locations, OS/runtime requirements, build/check commands, scratch roots, environment/profile isolation, containment, cleanup, exclusions and skip policy. Inspect all automatically loaded helpers and tests selected by the final command, not just a filter. Do not run package tests in this preparation phase.
- **Test Scenarios**: Missing dependency; native crash; path escaping scratch; stale alias to another root; lock timeout/advisory fallback; cleanup after failed setup; core test skipped; report collision or active-state owner conflict.
- **Tests**: Explicitly approved non-package containment/runtime preflight only; no execution until its own permission and roots are agreed. The exact future suite gate is approved before any coding. See Testing Strategy for the preferred subprocess candidate and limits.
- **Acceptance criteria**: V7; a named owner and executable, enforceable roots, tested-dependency recording rules, exact approved gate/substitute and outputs exist. UNKNOWN runtime or unresolved safety blocks Phase 3, not permission to use an unsafe default.

## Phase 3: Immutable Execution Proof and Metadata History

### 3. Add Validated Durable Outcomes and Execution Receipts

- **Requirements**: R4, R5, R6, R9, R10
- **Files**: `R/execution_state.R`, `R/IO_core.R`, `R/version_store.R`, `R/retention.R`; `tests/testthat/test-m2-state.R`, `tests/testthat/test-should-save.R`, `tests/testthat/test-info-retention-children.R`, `tests/testthat/test-pruning.R`.
- **Details**: Implement only approved schemas/publication/access/retention. Resolve usable skipped-save pins and separate raw unchanged save from proof of an actual successful build. Commit outcomes only after validating artifacts and exact proof bindings. Preserve old snapshots and support data-free receipt access. Implement serial idempotency and protected-proof pruning behavior. Keep failed and successful requests distinct.
- **Test Scenarios**: First success; unchanged successful B; satisfied duplicate request; failed save; partial catalog/snapshot/receipt marker; corrupt/wrong-artifact proof; missing output; process restart; direct no-op save without execution; protected prune/dry-run.
- **Tests**: Real temporary stores in approved suite; compare snapshot bytes/metadata/parents, output versions, receipt counts, restart reads and failure eligibility. No mocked storage as sole evidence.
- **Acceptance criteria**: V3 storage/proof subcases pass, with durable records usable after restart, unchanged B1 preserved, and no reusable partial success. V3 graph-integrated counts are rechecked in Step 7; do not mark it fully passed early.

### 4. Version Semantic Metadata and Expose Pinned Data-Free Reads

- **Requirements**: R7, R9, R10
- **Files**: `R/IO_core.R`, `R/format_registry.R`, `R/version_store.R`; `tests/testthat/test-m2-metadata.R`, `tests/testthat/test-save-load.R`, `tests/testthat/test-sidecar-verify.R`.
- **Details**: Add approved semantic schema comparison, reserved-key/type validation and version selector. Preserve the old current-sidecar default; historical mode never falls back. Keep result metadata/provenance separate from later receipt facts. Integrate semantic proof into success validation.
- **Test Scenarios**: Equal data with semantic change; descriptive-only edit under chosen policy; historical version after newer save; malformed schema/collision; scalar/vector and NA/null round trips; missing old sidecar; JSON/QS2/both behavior; no data-reader invocation.
- **Tests**: Actual storage and version round trips, reader spies that fail on data deserialization, original/new pin comparisons, semantic/type assertions.
- **Acceptance criteria**: V5 passes and Phase 3's required V3 evidence is satisfied to its stated scope; historical content/provenance stays immutable. Run the approved suite gate before phase completion.

## Phase 4: Requested Currentness and Dependency-Safe Execution

### 5. Compare Requested Calculation and Helper Fingerprints

- **Requirements**: R3, R9, R10
- **Files**: `R/hashing.R`, `R/rebuild.R`, `R/version_store.R`, `R/execution_state.R`; `tests/testthat/test-m2-rebuild.R`, `tests/testthat/test-m2-state.R`.
- **Details**: Normalize approved explicit request components, compare before execution, expose run/skip/blocked reasons and preserve source SHA as audit only. Separate unavailable requested proof from missing saved proof. Retain legacy public hashing behavior unless its change is explicitly approved; do not discover arbitrary helpers.
- **Test Scenarios**: Body/helper/constant/rule change; unrelated source edit; absent/NA requested calculation/helper; missing saved legacy proof; algorithm/schema mismatch; helper order normalization; recovered proof used on next request.
- **Tests**: Decision traces and builder counters before execution, valid recovery persisted to real storage, no equality from missing components.
- **Acceptance criteria**: V2 fingerprint subcases pass; affected requests select work and unrelated source changes alone do not. Changed B fingerprint follows the approved compatibility route, not parent-only retained-pin cutoff.

### 6. Apply Durable Availability and Failure Precedence

- **Requirements**: R5, R6, R8, R9, R10
- **Files**: `R/execution_state.R`, `R/rebuild.R`, `R/version_store.R`; `tests/testthat/test-m2-state.R`.
- **Details**: Validate inputs/output/proof and interpret persisted attempts under D5-C. Missing output is not automatically runnable if an unchanged deterministic failure suppresses it. Block failed/missing parents and unknown classification; preserve unaffected work. Keep selection pure and persist outcomes through the approved record path.
- **Test Scenarios**: Absent versus corrupt prior state; deleted output/snapshot/parent; unchanged deterministic failure; review without required change; changed input/rule with approved review; next analyst-started external-failure run; failure after older success; interrupted publication.
- **Tests**: Separate process/session requests with real persisted state, explicit reasons/counters, no timer/retry worker, no child execution after a failed prerequisite.
- **Acceptance criteria**: V4 state subcases pass; missing/ambiguous/partial facts never certify currentness and no older success masks failure of the current request.

### 7. Order the Graph and Recheck After Each Actual Outcome

- **Requirements**: R4, R8, R9, R10, R11
- **Files**: `R/rebuild.R`, `R/version_store.R`, `R/execution_state.R`; `tests/testthat/test-m2-rebuild.R`, `tests/testthat/test-m2-state.R`, `tests/testthat/test-info-retention-children.R`.
- **Details**: Use approved explicit recipes/current edges, finite visited traversal, cycle rejection and topological order. Revalidate requests between preview and execution; refresh descendants after actual committed upstream outcomes. Do not execute a propagated candidate merely because it was listed before B's result was known.
- **Test Scenarios**: Chain/diamond/overlapping targets and unsaved output recipe; self/general cycle with no writes; obsolete historical reverse edge; parent changes after preview; failed B blocks C; changed B result selects C; unchanged B content/fingerprint/semantic metadata retains B1 and skips C.
- **Tests**: Real storage A1-B1-C1 then A2 fixture, ordered invocation trace, old B1 readback, exactly one new success receipt for A2, immediate second/third satisfied request zero execution/new-receipt counts. Repeat after a fresh process. Also exercise aliases and stable tie-breaking.
- **Acceptance criteria**: V2, V3 and V4 pass in integrated L-stamp cases; no false currentness or out-of-order success. Run the approved suite gate before phase completion.

## Phase 5: Public Compatibility and Local Acceptance

### 8. Document and Verify the Approved Public Surface

- **Requirements**: R9, R10, R11
- **Files**: Approved roxygen-bearing sources and exact generated Rd/NAMESPACE list above; `vignettes/builders-plans.Rmd`, `NEWS.md`; API assertions in `tests/testthat/test-m2-rebuild.R`, `tests/testthat/test-m2-metadata.R` and applicable existing tests.
- **Details**: Generate only approved docs/exports, explain original provenance versus latest execution, metadata version selection and no-op semantics. Verify installed exports/formals, positional/default/ellipsis compatibility, legacy store reads, format overrides and existing return columns. Do not use export-all namespace loading as compatibility proof. No new dependency, config or adapter change.
- **Test Scenarios**: Existing callers without requests; new request-aware callers; rds/qs2 and fst compatibility; custom format forwarding; missing historical proof; unexported partition/hash helper remains unexported; generated doc drift.
- **Tests**: Approved installed-build suite plus exact API/document delta inspection. Vignette execution requires additional containment/read audit if not included in the approved gate.
- **Acceptance criteria**: Public contracts match D5-A, listed docs are coherent, only approved generated deltas exist, and compatibility failures are not hidden by weakening assertions.

### 9. Collect L-Stamp Evidence and Return the Producer Handoff

- **Requirements**: R2, R10, R11, R12
- **Files**: Approved execution report, active-state record and this plan's allowed progress fields only; approved scratch outputs for suite evidence.
- **Details**: Execute the approved complete test gate/substitute at the exact recorded source tree and runtime. Map every V2-V5 local case to executed assertions, counts and storage readbacks. Record all skips/exclusions, process exit/native crashes, installed producer locations and observed versus actually tested pins. Source tree changes must be reported alongside HEAD; do not attribute uncommitted implementation to HEAD alone. Do not commit without separate user permission.
- **Test Scenarios**: Core case skipped; absent log/exit; native crash; wrong installed stamp; uncommitted source at recorded HEAD; downstream consumer requests premature engine certification.
- **Tests**: Approved build/check subprocess gate and explicit local case matrix; no new command or extra evidence output without exact scope approval.
- **Acceptance criteria**: V9 and all required contract evidence pass. Handoff is stamp-local producer evidence, not L-authority/V6, a tested pipdata/pipload pin, or M2 completion. No central roadmap/umbrella status is changed.

## Testing Strategy

### Planning Checks Only

No R/package test, R executable probe, dependency installation, pipeline, network API or data processing ran in this task. Source/test inspection is not a pass. Approval permits readback, structural/source-reference review and renderer validation only, with results in the conversation rather than another artifact.

After save, verify the exact path, frontmatter, five phase headings, global step sequence 1-9, unique R1-R12 IDs and step coverage, required completion subsections, nonempty Gaps, proposal/approval distinctions, and sole intended output. Re-read the artifact-view contract. Run the approved no-output command with Python bytecode disabled:

```text
cg-render-artifact --validate-only .cg-docs/plans/2026-10-14-m2-stamp-generic-gaps.md
```

The installed launcher was located at `C:/Users/wb384996/.compound-gpid/bin/cg-render-artifact.cmd` and read; it calls its local Python renderer. No HTML is authorized, regardless of automatic-render defaults. Expected optional view path: `.cg-docs/views/plans/2026-10-14-m2-stamp-generic-gaps.html`. If validation fails, preserve Markdown/prior views, report exact error and view state, and give `cg-render-artifact .cg-docs/plans/2026-10-14-m2-stamp-generic-gaps.md` as recovery guidance only; view generation still requires separate permission. Repeat scoped root/branch/HEAD/status and whitespace checks. Do not claim an untracked new file was covered by ordinary `git diff --check` alone.

### Inspected Test Setup, Hooks, Cleanup, and Resources

| Evidence | Fresh finding and limitation |
|---|---|
| `tests/testthat.R:9-12` | Loads testthat/stamp and calls `test_check("stamp")`; build/check runs this installed-package test surface |
| `tests/testthat/` directory | 23 existing test files and one helper, `helper-opts.R`; no setup/teardown file listed. New approved files must be included by the final suite |
| `helper-opts.R:12-19` | Restores private option store with `withr::defer`; does not by itself restore aliases, builders, formats, extension map, base options or working directory |
| `R/zzz.R:81-109`, `R/aaa.R:183-219`, `R/options.R` | Load initializes private defaults, mirrors base options, seeds extension map and modifies CLI theme; unload restores the prior theme conditionally. No stamp load-hook disk write observed, but dependency hook behavior is not inspected |
| `R/IO_core.R:16-115` | Explicit initialization creates state/temp/log directories and registers aliases. Default root is current working directory; aliases must never point outside disposable roots |
| `test-sidecar-verify.R:1,30-62` | Top-level stamp option mutation; deliberate snapshot deletion to test lineage fallback. Diagnostic fallback must not become reusable success proof |
| `test-should-save.R:36-61`; `test-edgecases.R` search | Disabled missing-sidecar case; negative tests delete catalog/versions. Skips and destructive fixtures must be recorded and confined |
| `test-folder-structure.R`, `test-vignette-issues.R` searches | Temporary-root working-directory changes and recursive cleanup; helper naming alone does not prove failure-safe restoration |
| `test-save-load.R:20-28,138-148` | Some explicit alias cleanup; custom format registration mutates registry. Fresh-process isolation and per-test state cleanup remain necessary |
| `test-pruning.R`, `test-write-parts.R` searches | Existing unconditional skips include automatic-retention and partition cases. They cannot stand in for required receipt retention/missing-proof evidence |
| Source-wide/test resource searches | Inspected snippets use temporary fixtures. No external fetch/configured shared path was identified by the targeted testthat search; this is not a whole dependency/resource audit or filesystem containment proof |
| `R/format_registry.R:40-108`, DESCRIPTION | Actual storage uses qs2/rds/json/data.table/fst/nanoparquet; catalog needs qs2 even with rds result fixtures. Some legacy format tests optionally require `qs`, not declared in DESCRIPTION |
| `.Rbuildignore:19-27` | Excludes `.cg-docs`, `.kilo`, charter/local/context and dev artifacts. Untracked `.compound-gpid/` is not explicitly excluded; audit candidate tar contents before any install/check, without editing ignores under this task |

Mandatory D8 containment: a fresh process and disposable source/build/test root; separate approved library; process-start TMPDIR/TMP/TEMP and user/cache roots; disabled network/shared-drive access; no production aliases or credentials; read-only original sources; writes/deletes confined by an approved enforcement mechanism. Environment variables alone do not prove containment. Cleanup may remove only the worker's confirmed disposable subtree, never broad parent temp paths. Restore private options, aliases/builders/formats and working directory or discard the contained process; do not alter real user profiles/configuration.

Additional source-read scope needed before certification: exact installed sources/load hooks/transitive initialization used by testthat, withr, pkgload if invoked, cli, rlang, fs, secretbase, jsonlite, data.table, qs2, nanoparquet, fst, filelock and optional collapse/qs where selected. Their actual installation/source paths are UNKNOWN. Obtain exact root approval before reading outside current permitted scope, or approve an isolated environment whose enforcement demonstrably contains their effects. Do not read unrelated package repositories, private profiles, credentials or production data to bypass this gap.

### Proposed Subprocess Suite Gate, Not Executed or Approved

Prefer the local learning's `R CMD build`/`R CMD check` subprocess harness, not direct `testthat::test_local()`/`test_file()` as acceptance authority. A bounded compatible substitute may run the entire testthat suite while excluding examples/vignettes/manuals. It requires direct D8 approval; it is not a clean CRAN check claim.

Candidate source is an approved disposable copy of this worktree's approved package files, including every test and new source/doc change. Copy rules/hash ledger must exclude tool/config/unrelated untracked trees without silently changing package/test behavior. Candidate scratch root for approval is `C:/Users/wb384996/AppData/Local/Temp/2/kilo/m2-stamp-generic-gaps/`; it is not created here. Propose `source/stamp`, `build`, `library`, `tmp`, `home`, `cache` beneath it, with build/check working directory `build`.

Command template for D8 resolution, PowerShell 5.1, each run separately in that approved build directory:

```powershell
& "<approved-absolute-R.exe>" --vanilla CMD build --no-build-vignettes --no-manual "<approved-scratch>/source/stamp"
& "<approved-absolute-R.exe>" --vanilla CMD check --no-manual --no-vignettes --no-examples "<approved-scratch>/build/stamp_0.0.11.tar.gz"
```

Placeholders are NOT an exact approved runnable command. D8 must replace them with verified executable/root/tarball paths, confirm command flags against that runtime without running package tests prematurely, approve every environment setting and output, and inspect package-copy/build contents. Version `0.0.11` is the current DESCRIPTION value; a version change requires scope approval and a revised exact command, not a guessed tarball. No dependency install/update is permitted. Use process-local `NOT_CRAN=true` for the required non-CRAN suite cases and neutralize profiles/startup environment for child processes through approved settings; `--vanilla` alone is not a whole containment mechanism. Do not use `--as-cran` without approving its wider checks/resource requirements.

The candidate gate selects the complete installed `tests/testthat` suite through `tests/testthat.R`, including internal partition tests (not a public partition API), plus approved new tests. It excludes manual scripts, example execution, vignette rebuild/execution, PDF manuals, pkgdown, benchmarks and all external engine/production/SMB/multiwriter tests. Retain exported-API tests against the installed package. Record full test summaries, every skip/warning and native exit status; no-output/native crash is failure/unknown, never a pass. Core L-stamp cases must execute without skips. The compatible substitute does not waive the charter's eventual clean full `R CMD check`/CRAN obligation; broad packaging/vignette checks remain pending until separately audited/approved. If the user requires the wider gate for these phases, inspect those resources before implementation rather than silently narrowing it.

Runtime requirements from source: R >= 4.1; testthat >= 3.1.5, edition 3; all DESCRIPTION Imports, withr and the required format/lock packages installed beforehand. Keep R >= 4.1 source compatibility; a later combined engine runtime may need a higher R version but is not selected here. Exact R build/library paths, dependency versions, loaded stamp location/source identity, filelock behavior and working host are UNKNOWN. Record them when actually tested. No tested package/dependency pin exists in this task.

### Local Acceptance Matrix

| Local case | Evidence | Umbrella mapping |
|---|---|---|
| Fingerprints and graph | Complete requested components; changed relevant versus unrelated source; missing/NA asymmetry; chain/diamond/targets/cycles | L-stamp / V2; later T4/T5/T12 integration remains separate |
| Retained output and convergence | A2 execution -> B1 receipt, immutable B1 provenance, C count zero, repeated request no new execution/receipt, fresh-process confirmation | L-stamp / V3; bounded local part of later T8 |
| Durable state/integrity | Missing/corrupt output/proof/parent, deterministic and external failure, review/change gate, blocked child, interrupted serial publication | L-stamp / V4; later T6/T12 engine evidence separate |
| Metadata/history | Semantic versions, descriptive rule, type/collision checks, exact pinned read, data-free reader trace | L-stamp / V5; later adapter/release T7/T11 separate |

L-authority/V6 requires separately approved actual pipload/pipdata integration and tested stamp producer identity. Whole-M2 T1-T12 require actual integrated stages/fixtures and cannot be completed, waived or inferred from this local Plan. Option 1 is not consumed-row CPI selectivity, R1 selection or proof that every unrelated source edit avoids B execution.

## Documentation Checklist

- [ ] D5 signatures/schema/reasons are approved, distinguish legacy/new proof and match installed exports.
- [ ] Original snapshot provenance, latest execution proof and output pins are described separately.
- [ ] Missing-requested versus missing-saved behavior and deterministic/external failure gates are explicit.
- [ ] Semantic/descriptive metadata, type/null rules and exact-version/data-free access are documented.
- [ ] Only enumerated generated Rd/NAMESPACE deltas occur; no parked partition/hash helpers become public.
- [ ] D8 exact executable/roots/commands/output paths, cleanup and skip/exclusion ledger are recorded.
- [ ] Execution report and active-state scope/progress fields are approved before `/cg-work` writes.
- [ ] Actual L-stamp V2-V5 evidence and tested-source/runtime identity are distinct from proposals and later integration.
- [ ] This saved Plan is read back and document validation is actually reported; no implementation completion is inferred.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Draft approval promoted to D5/D8 or implementation approval | Unauthorized mutation | Separate contract, write/lifecycle, safe-gate and phase approvals |
| Receipt treated as a log/status label | False currentness | Validate committed exact request/output/metadata bindings and availability |
| Old B provenance overwritten to reflect A2 | Lost history | Separate immutable receipt, pinned snapshot hash/readback tests |
| Code-changed equal output silently inherits cutoff | Unapproved compatibility change | Preserve code-driven versions and require explicit extension decision |
| Missing helper hash or schema mismatch ignored | Stale output reused | Block incomplete requested proof; tested legacy recovery only with approved policy |
| Pruning erases a retained output/proof dependency | Dangling success | No-prune fixture plus approved protected-reference refusal and negative tests |
| Topological candidate list executed without recheck | Extra or invalid descendant work | Stamp-owned per-outcome revalidation, failure blocks and convergence counters |
| JSON simplification merges semantic types | Lost meaning/history | Typed schema and JSON/QS2 round trips with reserved-key rejection |
| Native harness crash or leaked registries masks failures | Invalid acceptance | Build/check subprocess, fresh contained runtime, private-state cleanup and exit/skip accounting |
| Tool/untracked files enter build tarball | Wrong package or unsafe effects | Explicit approved disposable source manifest and tar-content audit |
| Generator changes unrelated docs/config | Write-set violation | Exact generated allowlist; stop before retaining unapproved deltas |
| Local source pin called a tested consumer dependency | Premature engine/M2 completion | Separate source/runtime ledger and local versus integration evidence |

## Gaps

- Full D5-A through D5-G and D8 execution approvals are absent. Exact API signatures, export necessity, receipt layout/publication checks, failure/review rules, metadata types/migration and prune protection remain decisions, not facts.
- Owner/conflict checks cover the affected checkout/target only. Native session identity, other worker liveness/write sets and original feature-branch creation baseline are UNKNOWN; reverify before future writes.
- R executable/build, installed dependency versions/source paths, dependency hooks, containment enforcement, exact safe suite command/output roots and cleanup safety are UNKNOWN. No package/runtime test ran; dependencies actually tested: NONE.
- Historical Windows crash reports inform the gate but do not prove this runtime's behavior. The proposed build/check substitute excludes wider CRAN/example/vignette checks; no safe gate is yet certified. `.compound-gpid/` build inclusion needs audit without an unapproved ignore/config edit.
- Existing disabled tests do not supply core missing-proof/retention evidence. New receipt/state behavior and legacy compatibility are unimplemented and untested.
- Equal-output cutoff after changed B calculation fingerprints is not approved. Current code-driven versioning is the preferred compatibility proposal, not a new blanket equivalence policy.
- Consumer adapter/engine commits and interface round trips are not tested. D4/Force/feedback, D6 membership/receipt links, D7/M1 R1, survey/numerical choices and whole-M2 evidence remain outside this task.
- Serial isolated evidence will not certify SMB/parallel writes, production retention, target-scale performance, cryptographic authenticity or release guarantees.

## Out of Scope

- Current implementation, package/R tests, dependency installation, runtime setup, private configuration reads, production data, network/API/DLW calls and helpers/extra workers.
- Any present write other than this exact Plan, including reports, active-state files, views, indexes, roadmap, pipsystem, adapters, configuration, ignore rules, source or tests.
- Git staging/commit/push/merge/stash/reset/cleanup; no branch operation was needed. Future Git writes require direct approval.
- PIP vocabulary/runtime logic in stamp; schedulers outside stamp; release registry; variable-level tracking; general dependency discovery; automatic retries; Force/D4; M1 R1 selection; platform selection.
- Engine, pipload/pipdata changes, mean/deflation/release work, full T1-T12 certification, site rebuild or broad package cleanup.

## Completion Contract

This is a future local implementation contract. Saving/validating this active Plan completes only the document deliverable. Required runtime evidence cannot be passed by planning, static inspection, a skipped test or a blanket exception; missing core local evidence leaves execution incomplete/blocked.

### Outcome

After separately approved implementation, stamp alone determines generic artifact currentness from requested fingerprints, valid inputs, durable outcomes and validated execution proof. In the bounded A-B-C case, unchanged B content/calculation fingerprint/semantic metadata retains B's output pin, immutable proof records new inputs without changing old history, repeated requests converge and C does not rerun merely because A advanced.

### Verification Surface

| ID | Phase | Evidence Required | Command/Artifact | Required |
|---|---|---|---|---|
| V1 | 1 | Exact applicable D5 APIs/schemas/missing-proof/compatibility decisions approved | Explicit approvals and contract matrix in approved execution report | yes |
| V7 | 2 | Owner/write/lifecycle, runtime, containment, exact safe gate/output scope approved | D8 approval and approved preflight evidence | yes |
| V2 | 4 | Requested calculation/helper changes detected before execution; unrelated source alone does not blanket-invalidate; graph order/cycles correct | L-stamp fingerprint/chain/diamond/multi-target/cycle tests with real storage | yes |
| V3 | 3 | Storage proof retains B pin, validates publication/retention, preserves old history and idempotent satisfied requests | Receipt inventories, historical readback, restart storage tests; graph counts completed under V8 | yes |
| V8 | final | Integrated bounded A-B-C converges, C skips, repeat requests create no execution/receipt across restart | Step 7 real-storage trace/counters and old-pin readback | yes |
| V4 | 4 | Missing/corrupt/failed/success/blocked facts follow durable precedence and downstream rechecks | Persisted state, failure, partial-publication and failed-parent tests | yes |
| V5 | 3 | Semantic versions and pinned typed metadata agree; metadata/receipt reads do not deserialize data | Real metadata/version round trips, collision tests and data-reader spies | yes |
| V9 | final | Required L-stamp cases and approved suite gate pass at identified source/runtime pins; compatibility/exclusions recorded | Approved build/check results, installed-API checks, skip ledger and execution report | yes |

V8 makes the storage-versus-graph sequencing explicit: Phase 3 does not wait for Phase 4's graph implementation. This preserves the approved outcome and evidence obligation without prematurely passing the full A-B-C claim. V2-V5 map to the umbrella's local obligations; V9 is not umbrella V6.

### Constraints

| ID | Phase | Constraint | Check |
|---|---|---|---|
| C1 | final | Stamp remains neutral/sole selector; no pipsystem runtime reads | Neutral fixtures and public boundary review |
| C2 | 3 | Old pinned data/metadata/original provenance remain unchanged | Before/after snapshot hashes and exact-version readback |
| C3 | final | No changed-B-fingerprint cutoff extension without approval | Code-change compatibility regression |
| C4 | 4 | Missing requested proof cannot establish currentness; missing saved proof is distinct | Complete decision matrix and negative/recovery tests |
| C5 | final | No automatic retry, Force decision, R1, release registry or variable-level tracking | Scope review and outcome tests |
| C6 | final | No implementation without applicable contract, owner, lifecycle/safe-gate and phase approval | Approval records checked before mutation |
| C7 | final | Planning creates only named Markdown; future work respects exact approved write set | Readback, scoped Git/delta evidence and future report |

### Boundaries

- Allowed now: only this new Plan plus approved no-output document checks in the verified stamp worktree.
- Allowed later only after direct approval: enumerated stamp code/tests/docs, exact report/active-state/progress scope and contained scratch outputs for the selected phase.
- Out of scope: other repository changes, engine implementation, current tests/runtime setup/install, roadmap/helpers/Git writes, configuration/adapters and production/SMB/multiwriter certification.

### Iteration Policy

1. Saving approves the planning artifact only, not D5 choices or implementation.
2. Finish the applicable contract preparation before coding. Preserve unresolved choices in Gaps; do not demand unrelated engine decisions before drafting.
3. Approve D8's exact runtime, enforced roots, commands, outputs and exclusions before implementation. Use the local native-crash learning; no unsafe default gate.
4. Recheck descendants inside stamp after actual outcomes; validate before reuse and before invocation.
5. Under `ask`, stop before deviations/write-set expansion. Do not count skipped core cases or static inspection as executed runtime passes.
6. Phase completion requires its actual evidence; final completion requires all local evidence including V8 and V9. No automatic next-phase start or umbrella/roadmap completion.

### Blocked-Stop Conditions

- Required D5 decision, named owner/conflict check, phase approval or exact write/lifecycle permission is missing.
- Safe approved gate, runtime identity, containment/cleanup boundary or required additional source-read permission is unavailable.
- History/proof is ambiguous, corrupt, missing or partly published and no approved safe recovery applies.
- Required evidence fails/is skipped, native process crashes, output is absent, or the loaded package does not match the recorded tested tree.
- Work needs another repository, an unapproved output/configuration/adapter change or broader cutoff semantics.
- Renderer validation fails: preserve canonical Markdown and prior views, report exact error/view state and recovery guidance. Do not hand off as validated.
- Report collision, active-state ownership conflict or inability to durably record execution evidence prevents safe `/cg-work` lifecycle writes.

## Handoff Record

| Required field | Planning record |
|---|---|
| Feature/task ID | `close-stamp-gaps-for-skeleton`; `m2-stamp-local-plan-2026-10-14`; milestone `m2-walking-skeleton`; `create-engine-skeleton` interface only |
| Repository, worktree, and session ID | Stamp repository and active worktree above; native session ID UNKNOWN |
| Branch, base SHA, and current SHA | `feat/m2-stamp-generic-gaps`; observed task base/save baseline `ad9a483b6261166a6feefc64baea5d602198977b`; original branch-creation base UNKNOWN; final current SHA reported in response |
| Approved scope, plan, and completed phase | This one-file planning deliverable and approved no-output document checks; no implementation Plan/phase approved or completed |
| Worker status | Plan saved after preview approval; actual readback/validation outcome supplied in response |
| Changed files | This Plan only by this worker; preserve pre-existing dirty paths |
| Executed checks and evidence paths | Read-only Git identity/status/worktree checks, named references, API/helper/hook/resource and learning inspection; this Plan is the sole evidence artifact; actual final checks reported in response |
| Dependency versions/SHAs actually tested | NONE; inspected stamp/central HEADs are source observations only |
| Checks not run | All R/package/pipeline/API/runtime tests, dependency installs, storage containment/SMB/multiwriter/production checks, consumer integration, complete M2 and helper/session inventory |
| Remaining blockers or required decisions | D5-A through D5-G as applicable, D8 exact owner/write/lifecycle/runtime/safe gate approvals, future selected-phase execution approval; Gaps above |
| Commit and PR | None created; no Git writes |
| Recommended next action | Review this local Plan and resolve applicable D5/D8 gates; do not start `/cg-work` under current approval |
