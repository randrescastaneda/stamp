# Function Audit and Test Hardening

Date: 2026-10-15. Package: stamp 0.0.11. Baseline:
`ad9a483b6261166a6feefc64baea5d602198977b`, branch `ready_cran`.
Implementation authority: `.kilo/plans/1792071008129-exhaustive-function-audit.md`.

## Approved Reference-Save Pilot

On 2026-10-19 the user approved a limited opt-in implementation after a
scratch-only copy-boundary experiment. `reference_copy_on_save` defaults to
`FALSE` and accepts only one nonmissing logical value. When explicitly enabled,
only a root environment passed to native-RDS `st_save()` enters the pilot. The
copy is made once, after ordinary path/PK/format validation and before metadata
capture, sanitization, or filesystem writes; the existing save sequence then
operates on that owned copy. No public argument, export, hash algorithm, catalog
identity or persistent state environment was added or migrated.

The accepted graph is intentionally narrow: unclassed ordinary environments,
NULL/atomic bindings, recursively atomic attributes, ordinary parent chains,
and bounded cycles/sharing. List-valued attributes, including dimnames, are not
supported. The guard limits all visit attempts to 10000 and depth to 64. Classed
or R6 environments, active/lazy bindings, lists, closures, S4 objects, connections
and opaque resources are excluded. Special environments are rejected as roots
or binding values; actual special parents remain shared, uninspected
serialization boundaries. Their contents are not isolated or snapshotted by the
pilot. Replacement RDS writers are not automatically enrolled in native support.
Unrecognized environments with namespace bindings or package-name markers are
also rejected before copying, because R serialization can resolve such markers
to actual system environments instead of making ordinary detached copies.

Default-off saves, non-environment roots (including data.tables, lists, models
and NULL), direct `st_hash_obj()` and comparison APIs retain their existing
behavior. The general reference-object mutation finding below therefore remains
open. This is not a global reference policy, general graph isolation guarantee,
successful R6 persistence claim or authorization for default rollout.

The supporting Candidate C experiment compared 124 save cases. Return/error/
warning classes and decoded payload graphs with attribute order matched in all
124, and all 90 returned content-hash pairs matched. Independent payload bytes
matched in 120 cases; four fresh-R6 fallback cases differed despite equal
read-and-reserialized payloads. Those are failed/fallback R6 cases, not supported
pilot inputs. Copying once corrected six attribute-order differences from the
earlier per-stage copy experiment. Shallow `env_clone()` was rejected for losing
attributes/classes or retaining caller-owned self/shared/parent references.
Prototype observations do not prove arbitrary promise, resource or lock safety.
The prototype's special-boundary rows were exclusions by design, not executed
safety tests. Production pilot rejection tests provide separate evidence.

Independent implementation review reproduced an active `.__NAMESPACE__.` binding
executing twice inside the initial special-environment classifier before
rejection. The classifier now compares actual registry identities without
calling `isNamespace()` or `environmentName()` on input. Nonforcing marker
checks also reject counterfeit namespace/package environments before R can
resolve them to actual system environments. A copied system root is rejected
even if it differs from the original input. Serialization-only review probes
confirmed both spoof mechanisms; no special or counterfeit root was hashed or
sanitized. Missing/empty ordinary name attributes remain supported.

A separate parent probe found PK decoration could mutate an environment classed
as a data.frame before the pilot rejected it. Enabled root environments now
cannot enter PK decoration or attached-PK inspection through tabular class
dispatch. Ordinary tables and default-off validation keep their prior route;
the single copy still occurs after normal path/PK/format validation. This closes
the tested preflight bypass, not arbitrary user-code side effects in other
arguments or a general reference-object policy.

Scratch evidence uses prefixes `stamp-reference-compat-` and
`stamp-reference-boundary-` under the existing audit scratch parent. Source MD5s
confirmed that the experiments did not change production R sources, DESCRIPTION
or NAMESPACE. Pilot implementation verification and independent-review evidence
are recorded in the verification table below.

## Approved Artifact Contract

The separately approved scoped contract is in
`.cg-docs/plans/2026-10-19-data-products-artifact-contract.md`, with executable
examples in `tests/testthat/test-artifact-contract.R`. It defines selected value
products, reuse-relevant parameters, historical reads, original data.table keys,
and a test-local model projection. It does not impose global class rejection or
promise executable-model reconstruction. No legacy consumer pipeline was run,
modified or adopted as the new architecture.

The focused contract check passed 76 assertions. Before the reference-save
pilot, normal and shuffled full checks each passed 2225 assertions with no test
FAIL/WARN/SKIP. These are historical pre-pilot results, not verification of the
new reference-copy boundary.

## Approved Original-Key Follow-Up

On 2026-10-17 the user approved key option 1 with the explicit constraint that
stamp must preserve only keys already present on the original input. Native
RDS/QS2 saves now reserve `attrs$stamp_data_table = list(version=1, key=...)` in
sidecars and snapshots. An explicit empty key records original unkeyed state;
an absent descriptor remains legacy/unknown. Neither PK annotations, sorted
rows nor column names create a key. Ordinary data hashes and sanitized payloads
are unchanged, while key-only differences can trigger a `metadata` version.

Loading validates actual row order and key-column names before reinstating the
recorded `sorted` metadata. It never sorts the returned rows. Validation uses
an independent key-column copy, strips untrusted sorting/index hints, renames
temporary columns safely and checks their row-index order. This supports valid
original names such as `.xi` and literal backticks without changing returned
names. Malformed or order-inconsistent descriptors abort. This is not metadata
authentication: optional artifact hashes warn on mismatches but do not prove
that an externally edited, still-consistent descriptor is authentic.

Current production source has no explicit `setkey()`/`setkeyv()` calls.
data.table's existing class conversion internally uses `setkeyv(..., NULL)` to
clear state, not create a key. The regression test permits clearing but rejects
non-empty sorting-key calls during loading. Directly preserved native keys and
original descriptors are distinct from inferring new keys.

Initial regressions reproduced key loss/invisible key-only changes. A scoped
review then found stale-`sorted` validation reuse and special-name rejection;
both were reproduced (3 FAIL/329 PASS on the intermediate source), corrected,
and re-reviewed without remaining P1/P2 findings. Final focused checks pass
355 assertions; normal, same-tarball extended and shuffled full checks each pass
2149 assertions with zero test FAIL/WARN/SKIP. Test-only coverage is 94.87828%.
Legacy descriptors, unkeyed/PK-only inputs, composite/empty keys, caller
immutability, custom readers, historical states, unchanged hashes and live-PK
snapshot independence have direct assertions. Arbitrary subclasses, secondary
indices and projected/combined partitions remain outside this contract.

## Approved NULL Follow-Up

On 2026-10-16 the user approved NULL option 1: explicit `x = NULL` is a real
object comparison, while omitted `x` leaves content unchecked. The three public
comparison helpers preserve omission through forwarding. Existing callers using
explicit NULL as a sentinel must omit `x` instead; the public signatures remain
unchanged. Native RDS/QS2 replacement, unchanged-save skipping and historical NULL
restoration are implemented without changing hashes, IDs or save-failure policy.
Built-in CSV/FST/Parquet writers reject NULL before replacing a table.

Focused regression evidence: `stamp-null-red` has 21 FAIL/47 PASS against the
pre-change source; `stamp-null-green` has 181 PASS and no test FAIL/WARN/SKIP.
Fixtures cover both native formats and JSON/QS2/both sidecars, independent raw
NULL payloads and serialized hashes, old snapshots, omitted code/file checks,
digest call counts, NULL-versus-empty/NA values and failed table writes.
Full follow-up verification and fresh audit evidence are recorded below. The
historical `audit-null-policy.R` observation below is not current behavior.
Unchanged restoration append/no-op policy and experimental partition/builder
NULL support remain outside this approved change.

Final verification: normal, same-tarball extended and shuffled checks each
passed 1794 assertions with no test FAIL/WARN/SKIP. Test-only coverage is
94.85199%. Namespace reconciliation and per-site evidence were regenerated for
the updated source. An independent read-only review found no introduced P1/P2
issue. RDS/QS2 NULL fidelity is verified; this does not expand JSON's existing
serialization contract or claim arbitrary-R-object fidelity for tabular formats.

## Approved Selector Follow-Up

On 2026-10-15 the user approved option 3 for restore selectors: zero means the
latest committed snapshot and a negative offset counts retained snapshots back.
The implementation now accepts `0`, `-1`, `-2`, etc. Positive restore position
`p` keeps its existing meaning with a deprecation warning and replacement
`1 - p`; removal is deferred to a future release. `st_load()` still rejects
positive numbers. The default `version = "oldest"`, exact IDs, keywords,
snapshot identities, hashes and save/append policy remain unchanged.

Focused regression evidence: `stamp-selector-red2` fails the new assertions
against the pre-change source (9 FAIL/46 PASS); `stamp-selector-green2` passes
135 assertions with no test failures, warnings or skips. Normal, same-tarball
extended and shuffled follow-up checks each pass 1613 assertions with zero test
failures, warnings or skips. Test-only coverage was 94.65551% at that stage.
The per-site CSV and source/namespace reconciliation were refreshed then and
are now superseded by the later NULL follow-up's evidence.
The older `stamp-fc9`/`fe9`/`fs9` rows remain historical initial-audit evidence,
not verification of the subsequent selector change. An independent read-only
review found no introduced P1/P2 issue in this transition.

## Outcome

The audit and compatible fixes are complete. Final verification is **partial**:
the local normal, extended and shuffled suites pass, but unresolved semantics,
incomplete branch/backend matrices, interactive selection, the platform/minimum-R matrix and
PDF manual generation prevent a claim of complete verification.

The baseline contains **198 source function sites: 138 top-level and 60 nested**.
The plan's individual module counts are correct, but sum to 138, not 132. There
are 37 exported functions, one S3 method, two lifecycle hooks, and 98 other
top-level internals. Six nested sites are named local functions; 54 are anonymous
callbacks or returned wrappers. Twelve registered handler instances originate
from two returned-function source sites, not twelve additional source sites.

The final census is **217 sites: 142 top-level and 75 nested**, in 14
modules, with the same exports, S3 registration and hooks. Initial added callbacks are
two in formats, two in core I/O, three in rebuild planning, one in retention,
and three in historical loading. The approved key follow-up adds three private
top-level helpers. The reference-save pilot adds one private top-level helper,
three named local functions and one anonymous catch. No public function was
added, removed or re-signed.
There are now 35 test files and 275 syntactic `test_that()` cases, versus the
baseline's 23 files and 127 cases. Cases containing loops are counted once.

The companion `2026-10-15-function-audit.csv` is the per-function assessment.
Each site has its own source identity, owner, signature, visibility, contract,
test/assertion evidence or blocker, functional status, testing confidence, and
lifecycle assessment. An owner-level test reference is not automatically proof
that every nested branch is asserted. `adequate` never follows from coverage.

Final classifications are **176 verified in tested scenarios and 41
unverified/ambiguous**. Testing confidence is **4 adequate, 211 partial, 0
missing and 2 blocked**. The four adequate sites have explicit bounded scenario
sets: `%||%`, `.st_is_dt()`, `st_state_set()` and `st_state_get()`. Lifecycle is
186 supported, 28 deferred and 3 legacy candidates. These dimensions are not
interchangeable; verified examples do not remove a function's residual limits.

No exports, public signatures, successful persisted hash rules, artifact
identities, support floor, or actual user stores were migrated. The initial
audit preserved selectors; the separately approved transition is described above.
Partition helpers and `st_path()` remain internal and deferred. Pre-existing
changes in `.gitignore`, `compound-gpid.local.md`, and `.compound-gpid/` were
preserved. Nothing was committed or published.

## Severity-Ordered Findings

### P1: Persistence and History Defects Fixed

1. **Scoped pruning could erase unrelated catalog records.** Filtering the
   working catalog to artifact A and persisting it dropped B's history. Pruning
   now filters the candidate set, preserves unrelated tables/files, and removes
   only successfully deleted child-version index entries. Surviving B-owned
   edges to a deleted parent version remain historical evidence, not fabricated
   recoverable snapshots. Exact records, IDs, payloads, and automatic retention
   are checked in `test-audit-retention-rebuild.R` and `test-pruning.R`.
2. **Replacement deleted the previous file before promotion.** A failed rename
   could lose the live payload or catalog; sidecar and parent metadata writers
   had the same pattern. Same-filesystem replacement now leaves the previous
   destination in place until promotion succeeds and cleans temporary files.
   Actual promotion and writer failures are injected, not just round trips.
3. **Catalog entries were published before snapshot completion.** A failed
   snapshot left a dangling new version in the catalog, including after restart.
   `st_save()` now finishes the snapshot before recording it, using exactly the
   existing SipHash identity formula. Snapshot staging refuses to overwrite an
   existing version directory. Invalid catalog confirmation is a failed save,
   not a fabricated fallback version ID.
4. **Lock timeout entered the critical section.** `filelock::lock()` returns
   `NULL` on timeout; the result was unchecked. The lock helper now aborts before
   evaluating the expression. Tests use a real child lock holder, two competing
   same-artifact writers, two different-artifact writers, exact catalog IDs and
   snapshot contents. The no-filelock fallback is tested separately and has no
   concurrency-safety claim.
   Repeated checks also exposed an actual Windows `EPERM` replacement failure:
   one writer's change-detection read ran outside the artifact lock while another
   replaced the live payload. Save decisions now hold the same artifact lock as
   publication, including unchanged skips. A deterministic child process proves
   that the decision is protected; a separate injected decision-error assertion
   preserves the original propagation rather than converting it into a fallback.
   Arbitrary external readers still do not acquire this lock; unrestricted
   reader/writer concurrency is not claimed.

These fixes are not a new multi-file transaction protocol. On a later save
failure, live payload/metadata can differ from the last committed history, and
an unreferenced completed snapshot can remain after a failed catalog write.
Power-loss durability, fsync, process-kill recovery at every publication step,
network filesystem semantics, and multi-file rollback remain unverified.

### P1: Hash and Restoration Boundaries Remain

5. **Original data.table key loss resolved for the approved native scope.**
   Sanitization still excludes key internals, preserving existing hashes. New
   native sidecar descriptors preserve only original keys independently of that
   hash. Key-only changes create metadata versions; unkeyed inputs remain
   unkeyed. Legacy snapshots without descriptors cannot reconstruct a lost key.
   Full arbitrary-class/index fidelity remains partial rather than certified.
6. **Hashing an environment can modify its attributes before failing.** General
   reference-object behavior is not safely defined. This is observed evidence,
   not a tested guarantee of support for all reference objects. It remains
   visible rather than being hidden by scalar/data.frame fixtures.
7. **Hash stability has narrower boundaries than the broad prose suggests.**
   Top-level attribute sorting depends on `LC_COLLATE`; nested attribute order
   is not normalized. For `structure(1L, Z = 1L, a = 2L)`, observed hashes were
   `011db2cdc5aea4d4` under `English_United States.utf8` and
   `25cc3ed61f7852f3` under `C`, on the same R version. Existing hash rules were
   preserved pending an explicit compatibility/versioning decision.

### P2: Loading, Metadata and Graph Defects Fixed

8. **Historical readers guessed a potentially wrong format.** Snapshot sidecar
   metadata now chooses the registered reader; extension/default fallback stays
   for legacy snapshots without metadata. Historical file/content verification
   follows the existing option-controlled warning policy. It does not apply
   the live loader's mutable PK/schema/domain annotation policy.
9. **A failed restore reported success.** `st_restore()` now checks the save
   result and fails if saving failed, and uses the snapshot's recorded writer
   instead of a changed default. The integer-offset conflict was resolved by the
   separately approved selector transition; append/no-op semantics remain open.
10. **Single-format metadata transitions could read stale JSON.** After a
    successful JSON-only or QS2-only update, the superseded representation is
    removed. Divergent or unreadable secondary QS2 metadata warns while retaining
    JSON priority. Invalid authoritative JSON and corrupt QS2-only metadata still
    fail. Interrupted dual writes are visible; atomic dual publication is not
    claimed. `st_load(verbose = FALSE)` suppresses these package warnings.
    New diagnostics initially leaked from quiet save decisions; that introduced
    regression was reproduced and corrected. `st_save(verbose = FALSE)` remains
    quiet, while default verbose saves still warn about divergent metadata.
11. **Missing QS2 file hashes produced false mismatch warnings.** Verification
    now checks that a recorded hash is scalar and nonmissing before comparison.
    An independent original-source probe warned for an unmodified RDS artifact
    with `store_file_hash = FALSE`; the fixed probe has no warning.
12. **Rebuild propagation truncated chains and convergence.** Planning and
    execution tests cover A-B-C, diamonds, unequal-depth DAGs, multiple roots,
    cycles, no-op/dry-run/failure, and exact rebuilt values. In-memory builder
    lookup must agree with normalized catalog paths without rewriting stored IDs.
13. **Relative lineage and Windows reverse-lineage lookups disagreed with
    persistence paths.** Query normalization and a snapshot fallback read
    existing graph identities without migrating them. An independent adversarial
    review also caught a newly introduced Boolean expansion guard that lost
    finite-depth descendants after longer-path-first convergence; the shorter
    path must be allowed to expand with its remaining depth.
    A normal CRAN-mode run additionally exposed mixed-case roots passed to
    `fs::path_rel()` against lowercased catalog paths. The scanner supplied long
    `../../...` paths, eventually hitting Windows PATH_MAX. Both operands now
    use the same query normalization; a regression captures the actual directory
    resolver inputs and requires exactly `a.rds` and `b.rds`. IDs are unchanged.
14. **Fractional UTC timestamps were not parsed for age retention.** `%S` rejected
    timestamps written by `.st_now_utc()`; `%OS` accepts whole/fractional seconds.
    Count and age conditions retain their documented union semantics.

### P2: Deferred Partition Defects Fixed or Withheld

15. **Projected reads used a logical folder instead of the payload file.** They
    now translate through the ordinary storage layout. Full/projected paths are
    compared against exact expected rows for Parquet and FST.
16. **Read errors silently removed partitions and warning tracking leaked into
    `.GlobalEnv`.** Failed reads now remain visible and tracking is local.
    Sparse fallback splitting omits unobserved factor combinations rather than
    manufacturing empty partitions.
17. **Directory keys can still overwrite payload values/types.** On Windows,
    normalized storage paths can turn `country=USA` into `country=usa`; parsing
    can change key case, and injection can replace typed payload columns.
    Misfiled payload authority, case preservation, NA keys and coercion require
    a contract decision. Lowercase unaffected fixtures do not establish these
    missing guarantees. The API remains deferred, not deleted or re-exported.
    Observational probes also found base-data-frame NA grouping losing one of
    two rows while data.table retains both, captured formula environments being
    discarded, unsafe key names introducing separators, and integer overflow at
    `2147483648`. These are recorded decision/validation gates, not verified
    supported behavior or silently selected new coercion rules.

### P2: Smaller Compatible Fixes and Test Integrity

18. `st_hash_obj(NULL)` now works; restoration no longer clears attributes on a
    caller-owned data.table by reference. Eighteen previously valid object
    fixtures and nine code fixtures retained identical hashes against baseline.
19. Missing PK/filter names are rejected. Option mirroring reads the actual
    option environment, and unloading restores an initially absent CLI theme.
20. Tests no longer rely on undeclared `%>%`, an attached development session,
    class-only restoration, a tautological children assertion, timestamp-named
    roots, or reinitializing another store as state restoration. Value tests
    explicitly silence expected missing-PK chatter; dedicated warning tests
    remain. Unnecessary supported-case skips were removed rather than renamed.
21. **NULL and omitted comparisons were conflated; resolved by approved
    follow-up.** The original probe saved 11L, requested NULL and observed a
    skipped replacement. The approved change now compares and stores explicit
    NULL as a real value, preserves omitted-argument behavior in all wrappers,
    and verifies exact native NULL payloads. The old failing observation remains
    historical evidence, not a description of the updated API.

## Explicit Decision Gates

| Contract | Evidence and Decision Needed |
| --- | --- |
| Restore numeric selectors | Resolved by approved option 3: `0` latest, `-n` n retained versions back. Positive `p` warns and keeps old selection, with migration to `1-p`. No silent positive reinterpretation. Idempotent restoration may still skip rather than create a new version; append policy is a separate gap. |
| NULL object versus omitted comparison | Resolved by NULL option 1 approved on 2026-10-16: explicit NULL is a value; omitted x skips content comparison. Migrate old sentinel calls by omitting x. Native RDS/QS2 persistence and restore are tested; table formats reject NULL, and other format-specific fidelity rules are unchanged. |
| Object/code hash equivalence | Original DT keys are preserved as metadata under the approved scope without changing content hashes. Locale, nested attributes, primitives, and closure environments still require explicit decisions before changing persisted hash rules. `sum` and `prod` hash equally because both primitive formals/bodies are NULL. |
| Alias boundary | Relative `../` paths and `auto_switch = FALSE` do not establish a sandbox. Do not turn path-routing docs into a new security policy. Absolute outside-root errors, Windows separators and overlapping roots are tested; UNC/junction/POSIX guarantees need their own evidence. |
| Store portability | IDs hash normalized absolute paths. Moving roots or changing platform normalization can change catalog/parent identity. No relocation or migration was attempted. |
| History guarantees | Snapshot format and integrity checks are improved; full equivalence with live PK/schema/domain restoration and historical release compatibility is not certified. Live `st_add_pk()` does not rewrite snapshots. |
| Failure behavior | `st_save()` retains its shipped warning/fallback policy. Stronger default errors, crash durability, and automatic repair are proposals, not inferred requirements. |
| Deferred partitions | Key authority, case/type/NA fidelity, misfiled payload policy and real-world validation remain unresolved. |

## Module Assessment

The CSV is authoritative for individual source sites. This table is a readable
guide, not a blanket claim that every branch in a module is adequate.

| Baseline Module | Top-Level Sites | Behavioral Evidence and Residual Limits |
| --- | ---: | --- |
| `aaa.R` | 10 | Null/default/state binding and alias config predicates; path case/tie/junction limits remain. |
| `format_registry.R` | 20 | Six built-ins, independent reader/writer fixtures, custom wrappers, transitions and failures; dual-file transactions not claimed. |
| `hashing.R` | 9 | Independent byte/serialization fixtures, all reason combinations, classes/attributes/immutability; unresolved equivalence and reference objects. |
| `IO_core.R` | 16 | Public save/load/info/decision/alias/restore behaviors plus writer/promotion/snapshot/catalog faults and child contention; no global transaction guarantee. |
| `options.R` | 4 | Reset/get/set/default preservation and rejected atomic updates; not all options have a declared validation policy. |
| `partitions.R` | 13 | Full/projected/filter/list/sparse/error/no-leak scenarios; key fidelity and real datasets remain deferred. |
| `rebuild.R` | 9 | All five exported APIs, graph plans/order/rebuilt outputs and failure paths; broader alias semantics remain partial. |
| `retention.R` | 6 | Count/age/union/ties/scoping/dry-run/deletion failures and post-save retention; remote deletion and crash windows unverified. |
| `schema_pk.R` | 8 | Named keys and invalid positional keys, uniqueness/missing/empty data, live annotations and strict filters; snapshots are immutable, not mutable annotation stores. |
| `utils.R` | 6 | Exact logical/storage/payload layouts, timestamps and path validation; security/UNC/symlink boundaries not invented. |
| `version_store.R` | 31 | Legacy catalog coercion, IDs/query consistency, immutable snapshots, selectors, historical reading and graph traversal; interactive/global cross-alias discovery incomplete. |
| `zzz.R` | 6 | Disposable real load/unload sessions, previous/absent theme, mirrors and extension maps; shared concurrent CLI ownership not certified. |
| `stamp-package.R` | 0 | Package documentation, no executable function site. |

Baseline-to-final nested counts are: formats 3 to 5, core I/O 7 to 9, rebuild
15 to 18, retention 1 to 2, and version store 11 to 14. The other nested counts
are unchanged, apart from the new reference_copy.R module with one top-level
and four nested sites. The three approved private key helpers increase hashing.R
from 9 to 12 top-level sites. The nine final parser discrepancy rows are explained:
the original 132/138 arithmetic conflict, those new helpers, the added module,
changed nested/named-local/anonymous counts and changed test file/case counts.
There is no namespace,
export, S3/hook, or wrapper-instance
reconciliation discrepancy. Source bodies/formals match the installed namespace.

### Callback Evidence and Limits

The nine initially missing assertion attributions were closed in
`test-audit-callbacks.R`. A separate normalization catch was also distinguished
from the identical-signature QS2 catch, rather than inheriting its evidence.
Recovery mocks assert invocation counts after resetting precondition checks:
returning the correct value without attempting the injected operation cannot
pass as proof that its error callback ran. The CSV has exact source/test spans.

| Site / Owner | Observed Assertion and Remaining Limit |
| --- | --- |
| `.st_make_abs()` error callback | Injected `fs::path_abs()` error returns the exact lexical input; one actual attempted call asserted. Real filesystem/platform error matrices remain partial. |
| `st_load()` metadata callback | Actual corrupt current JSON is established, then a counted read recovers exact 11L without warning. Native payload values and sanitizer markers are checked independently. |
| `st_load()` file-hash callback | Counted digest failure returns exact 11L without a false mismatch. This is current-loader evidence, not inherited historical-loader coverage. |
| `st_load()` object-hash callback | Separate counted object-digest failure returns exact 11L without warning. The full class/backend matrix is not certified. |
| `st_alias_list()` row callback | Exact typed rows for configured and NULL bindings, plus the exact empty table. |
| `.st_resolve_version_identifier()` | Explicit IDs and keywords retain their meaning. Dedicated follow-up regressions assert zero/negative offsets, warned legacy positives, malformed/unavailable values, unchanged defaults and read-only failure paths. |
| `st_should_save()` metadata callback | Actual corrupt JSON read is established; decision is exactly `list(save=TRUE, reason="missing_meta")`, and native payload value remains 11L. |
| `st_opts()` formatting callback | Exact quoted string/logical values appear in option messages and getters return the new values. Malformed option/control policy remains partial. |
| `st_lineage()` sidecar callback | Counted injected read failure yields the exact typed empty edge schema and unchanged latest ID. |
| `st_read_sidecar()` normalization callback | Supported absolute missing path is established, normalization failure is injected and counted, and missing metadata still returns NULL. No existing-outside-root lookup policy is selected. |
| `.st_prompt_select_version()` and menu-label callback | Both are blocked for actual interactive selection/labels/cancel in this noninteractive check. The noninteractive error is tested. |

Deferral is separate from these results: three pure partition format utilities
have bounded verified outcomes while retaining deferred lifecycle status. Their
results do not establish partition key/payload fidelity.

## Verification Ledger

Scratch evidence parent:
`C:/Users/wb384996/AppData/Local/Temp/2/kilo/`.

| Run | Configuration | Observed Result |
| --- | --- | --- |
| Direct baseline build | Workspace, `R CMD build` | Failed copying nested `.kilo/worktrees` overlong paths before exclusion. No test result. |
| `stamp-audit-baseline` | Isolated source mirror, no Pandoc configured | Build failed for unavailable Pandoc; no test result. |
| `stamp-audit-baseline-check` | Pandoc configured, normal `--as-cran` | Build 0; check 1: 2 ERRORs, 1 WARNING, 5 NOTEs. Tests: 0 FAIL, 6 WARN, 53 SKIP, 262 PASS. Vignette relative-lineage PATH_MAX errors; absent LaTeX; time/top-level/vignette-dependency notes separated from tests. |
| `stamp-be` | Immutable original sources, extended fast check | Build/check 0; tests 0 FAIL, 9 WARN, 7 SKIP, 402 PASS. The seven unconditional skips remain visible; no baseline coverage percentage is asserted. |
| `stamp-audit-io-red2` | New persistence assertions on original sources, fast focused check | 7 FAIL, 0 WARN, 0 SKIP, 72 PASS. Actual old-file loss, incomplete catalog publication, restart visibility and timeout entry reproduced. |
| `stamp-audit-io-green` | Same focused assertions, compatible fixes | 0 FAIL, 0 WARN, 0 SKIP, 79 PASS. Check 0, but omitted-vignette warnings prevent calling this a clean full check. |
| `stamp-f1` | First integrated fast check | 20 FAIL, 14 WARN, 0 SKIP, 1208 PASS. Retained as integration evidence, not a pass; uncovered fixture case errors, missing-sidecar test setup, graph lookup and fractional-age issues. |
| `stamp-fe` | First complete extended build/check | 1417 PASS, 0 FAIL/WARN/SKIP; vignettes rebuild. Manual generation fails: 1 ERROR, 1 WARNING, 1 NOTE. |
| `stamp-fs` | First shuffled cases/files | 8 FAIL from test-file-local helper definitions. Helpers moved to `helper-*.R`; production code was not weakened. |
| `stamp-fc` / `stamp-fc2` | CRAN-mode integration checks | Mixed-case snapshot-scan PATH_MAX errors; `fc2` also found one failed writer among six saves. Failure retained, then instrumented, not retried away. |
| `stamp-fe4` | Diagnostic extended check | 1 FAIL, 1400 PASS; diagnostics identified Windows `EPERM` replacing the same live payload. Decision-lock fix follows this evidence. |
| `stamp-fc5` | Pre-gap-hardening `R CMD build`, `R CMD check --as-cran --no-manual` | Build/check 0; 1427 PASS, 0 FAIL/WARN/SKIP. Check has 3 NOTEs: new submission, time verification unavailable, undeclared vignette dependencies. Examples including donttest and vignettes pass. |
| `stamp-fe5` | Fresh extended subprocess, identical `fc5` tarball, `--no-manual` | Check 0; 1427 PASS, 0 FAIL/WARN/SKIP; 1 NOTE for undeclared vignette dependencies. Full examples/vignettes pass. |
| `stamp-fs5` | Pre-gap-hardening source; seeded case and file shuffle `20261015`, `--no-manual` | Build/check 0; 1427 PASS, 0 FAIL/WARN/SKIP; 1 NOTE. |
| `stamp-fc5/coverage` | Pre-gap-hardening covr test-only subprocess | Exit 0; 92.39974% executable-line coverage. Not the final coverage measurement. |
| `stamp-callbacks` | Initial direct-callback fixtures, scoped fast check | 5 FAIL/21 PASS: raw scalar fixture incorrectly ignored sanitizer attributes, and corruption targeted the wrong sidecar filename. Fixture preconditions were corrected, not production behavior weakened. |
| `stamp-callbacks2` / `stamp-callbacks3` / `stamp-callbacks4` | Incremental scoped checks before final counted assertions | 36/42/45 PASS respectively, no FAIL/WARN/SKIP. Final checks below include invocation-count assertions too. |
| `stamp-fc9` | Initial-audit build and `R CMD check --as-cran --no-manual` | Build/check 0; **1478 PASS, 0 FAIL, 0 WARN, 0 SKIP**. Three NOTEs: new submission, inability to verify current time, undeclared vignette dependencies. All examples, donttest and vignettes pass. |
| `stamp-fe9` | Fresh extended subprocess, identical `fc9` tarball, `--no-manual` | Check 0; **1478 PASS, 0 FAIL/WARN/SKIP**; 1 NOTE for undeclared vignette dependencies. Full examples/vignettes pass. |
| `stamp-fs9` | Initial-audit source, seeded case and file shuffle `20261015`, `--no-manual` | Build/check 0; **1478 PASS, 0 FAIL/WARN/SKIP**; 1 NOTE. |
| `stamp-fc9/coverage` | Initial-audit fresh test-only covr run | Exit 0; **93.83672% executable-line coverage**. Superseded by the selector follow-up coverage. |
| `stamp-selector-red2` | New selector tests against the untouched pre-transition source | 9 FAIL/46 PASS, no test WARN/SKIP; zero/negative selection and missing legacy warnings reproduced. The first red/green attempts also exposed an expectation-fixture issue: `expect_warning()` returns a condition, not the expression value; assignments were moved inside the expectation. |
| `stamp-selector-green2` | Corrected focused selector tests on changed source | 135 PASS, no FAIL/WARN/SKIP; helper/public mapping, warned positives, malformed inputs, unchanged default/history and no-write failures asserted. |
| `stamp-selector-final` | Updated full build and `R CMD check --as-cran --no-manual` | Build/check 0; **1613 PASS, 0 FAIL/WARN/SKIP**. Existing check NOTEs remain; examples, donttest and vignettes pass. |
| `stamp-selector-extended` | Fresh extended check of the identical selector-update tarball | Check 0; **1613 PASS, 0 FAIL/WARN/SKIP**; existing undeclared-vignette-dependency NOTE only. |
| `stamp-selector-shuffle` | Frozen updated source, case/file shuffle seed `20261015`, `--no-manual` | Build/check 0; **1613 PASS, 0 FAIL/WARN/SKIP**; existing NOTE only. |
| `stamp-selector-final/coverage` | Updated fresh-process test-only coverage | Exit 0; **94.65551% executable-line coverage**. Inclusive per-site spans overlap nested sites and do not establish branch/assertion adequacy. |
| `stamp-null-red` | New NULL regressions against the pre-change source | 21 FAIL/47 PASS, no test WARN/SKIP. This is an assertion count, not 21 independent defects. |
| `stamp-null-green` | Scoped NULL regressions after implementation | 181 PASS, no FAIL/WARN/SKIP across native replacement/restore, omission forwarding and table-write rejection. |
| `stamp-null-final` | Updated full build and `R CMD check --as-cran --no-manual` | Build/check 0; **1794 PASS, 0 FAIL/WARN/SKIP**. Examples, donttest, vignettes and documentation checks pass; existing check NOTEs remain. |
| `stamp-null-extended` | Fresh extended check of the identical NULL-update tarball | Check 0; **1794 PASS, 0 FAIL/WARN/SKIP**; existing undeclared-vignette-dependency NOTE only. |
| `stamp-null-shuffle` | Updated source, shuffled files/cases with seed `20261016` | Build/check 0; **1794 PASS, 0 FAIL/WARN/SKIP**; existing NOTE only. |
| `stamp-null-final/coverage` | Updated fresh-process test-only coverage | Exit 0; **94.85199% executable-line coverage**; no adequacy promotion from coverage. |
| `stamp-key-red` | Initial key tests against pre-feature source | 67 FAIL/115 PASS/2 WARN. The warnings were fixture uses of empty key vectors; fixtures now use NULL when clearing a key. |
| `stamp-key-green` | First key implementation | 311 PASS/1 FAIL/6 WARN. A test incorrectly prohibited data.table's harmless NULL-clearing setter, and fixtures used empty vectors; both test issues were corrected. |
| `stamp-key-green2` | Corrected initial focused tests | 326 PASS, no FAIL/WARN/SKIP. |
| `stamp-key-review-red` | Scoped review regressions against intermediate implementation | 3 FAIL/329 PASS: stale sorted hints incorrectly accepted and `.xi` rejected. Both production validation defects fixed before final verification. |
| `stamp-key-green3` | Corrected focused original-key tests | 355 PASS, no FAIL/WARN/SKIP. |
| `stamp-key-final` | Updated full build and `R CMD check --as-cran --no-manual` | Build/check 0; **2149 PASS, 0 FAIL/WARN/SKIP**. Examples, donttest, vignettes and documentation checks pass; existing NOTEs remain. |
| `stamp-key-extended` | Fresh extended check of identical key-update tarball | Check 0; **2149 PASS, 0 FAIL/WARN/SKIP**; existing vignette-dependency NOTE only. |
| `stamp-key-shuffle` | Updated source, files/cases shuffled with seed `20261017` | Build/check 0; **2149 PASS, 0 FAIL/WARN/SKIP**; existing NOTE only. |
| `stamp-key-final/coverage` | Fresh test-only coverage | Exit 0; **94.87828% executable-line coverage**; no confidence promotion from coverage. |
| `stamp-contract-focused2` | Scoped approved artifact-contract examples | 76 PASS, no FAIL/WARN/SKIP. |
| `stamp-contract-final` / `stamp-contract-shuffle` | Full pre-pilot checks; shuffle seed 20261019 | Build/check 0; **2225 PASS, 0 FAIL/WARN/SKIP** each. Examples and vignettes pass. |
| `stamp-reference-pilot-review-red3` | Same-overlay marker regressions against pre-fix classifier | Build 0/check 1; 12 FAIL/270 PASS, no test WARN/SKIP. Counter and serialization failures are directly observed; protected stubs prevent system-root hashing or sanitization. |
| `stamp-reference-pilot-review-green3` | Corrected nonforcing identity classifier | Build/check 0; 305 PASS, no FAIL/WARN/SKIP. FAST omitted-vignette check warnings are not test warnings. |
| `stamp-reference-pilot-pk-red` | Same-overlay PK regressions against earlier source | Build 0/check 1; 6 FAIL/319 PASS. Five failures are PK-specific; one is the already-known missing-name guard error in that older stage. |
| `stamp-reference-pilot-pk-green` | Final focused pilot, 24 cases | Build/check 0; **342 PASS, 0 FAIL/WARN/SKIP**. Two intentional FAST omitted-vignette check warnings remain. |
| `stamp-reference-pilot-final3` | Final full `--as-cran --no-manual` check | Build/check 0; **2567 PASS, 0 FAIL/WARN/SKIP**. Examples/donttest and vignettes pass; 3 NOTEs for incoming/new submission, unavailable current-time verification and existing vignette dependencies. |
| `stamp-reference-pilot-extended3` | Fresh extended check of identical final3 tarball | Check 0; **2567 PASS, 0 FAIL/WARN/SKIP**; existing vignette-dependency NOTE only. |
| `stamp-reference-pilot-shuffle4` | Final source, seeded files/cases shuffle 20261019 | Build/check 0; **2567 PASS, 0 FAIL/WARN/SKIP**; existing NOTE only. |
| `pcov3/coverage` | Final fresh-process test-only coverage, no line/function exclusions | Exit 0; all **2567 assertions pass**, no FAIL/WARN/SKIP; **95.16376% executable-line coverage**. Inclusive per-site spans overlap nested sites; coverage does not establish branch/assertion adequacy. |

The current R sources, test/helper files, DESCRIPTION and NAMESPACE were checked
byte-for-byte against `stamp-reference-pilot-final3/stamp` before final CSV publication. Final
source MD5s, installed namespace comparison, all source sites, callers, test
coordinates, runtime wrapper instances and the nine explained discrepancies are
in `stamp-reference-pilot-inventory3/`. The curated evidence is validated through
`function-audit.R --evidence`; all four adequate rows pass its scenario gates.

The first full/shuffled pilot attempts were stopped after the classifier finding
and are not final evidence. A later shuffled staging attempt encountered a
Windows copy-permission error before build/tests; the fresh `shuffle4` retry
passed without a production code change.

Coverage initially failed because tracing replaced canonical function bindings
after `.onLoad` had registered the native writer. The test-only helper now
recreates that handler from the current canonical functions when `R_COVR=true`.
Production guards, custom-writer rejection assertions and normal test setup are
unchanged. Shorter scratch paths also avoid a Windows PATH_MAX failure. Public
covr exclusions were investigated but not retained: they filter reports after
tracing and cannot solve handler identity. No test or function was skipped to
obtain the final coverage result.

Additional red/green evidence is retained under the scratch parent:

| Module / Boundary | Evidence |
| --- | --- |
| Hashing | `audit-hashing-probe.R`: original 2 failed invariants/current 2 pass; `audit-hashing-compat.R`: 18 valid object and 9 code fixtures unchanged. Scoped final check `audit-hashing-green3`: 216 PASS, no FAIL/WARN/SKIP. |
| State/schema | `state-audit-probe.R`: original 4 false/current 4 true; `state-owned-check-4` and shuffled scoped check: 237 PASS each, no FAIL/WARN/SKIP. |
| Formats/partitions | `audit-formats-probes.R`: original 10 failed invariants/current 10 pass; `stamp-formats-check-5`: 293 PASS, no FAIL/WARN/SKIP. Observations in `audit-partition-decisions.R` are not passing-contract claims. |
| Versions | `audit-version-probe.R`, `audit-version-red.log`, `audit-version-green.log`: original 8 FAIL/2 PASS/current 10 PASS; `stamp-version-target-check-6`: 186 PASS. `audit-version-convergence-red.log` proves the intermediate Boolean-guard regression. |
| Retention/rebuild | `retention-rebuild-red-6`: 37 assertion failures/143 PASS/2 WARN; `green-6` and `integrated-6`: 220 PASS each, no FAIL/WARN/SKIP. Failure counts are not distinct bug counts. |
| Missing file hash | `audit-missing-filehash.R`: original false warning/exit 1; corrected no warning/exact 11L/exit 0. |
| Windows scan paths | `audit-case-fallback.R`: original repeated `../` resolver inputs/exit 1; corrected exact relative `a.rds`,`b.rds` and child ID/exit 0. |
| Decision locking | `audit-decision-lock.R`: original child can acquire the decision-time lock/exit 1; corrected child blocked/exit 0. Final unit tests also cover unchanged skips and preserved decision-error propagation. |
| Quiet-save regression | `audit-quiet-save.R`: intermediate new divergence diagnostics emitted two warnings with `verbose=FALSE`/exit 1; corrected zero warnings/exit 0. Final tests retain default verbose warnings and exact saved values. |
| Historical NULL policy observation | `audit-null-policy.R`: pre-fix existing 11L retained after skipped NULL replacement, one existing version; separate fresh NULL artifact worked. This failing observation was resolved by the subsequently approved NULL option 1 and is not current behavior. |

Some scoped harnesses deliberately omit vignettes/manuals and report missing
built-vignette warnings. Their assertion results do not replace the final full
checks. One background check launch (`stamp-fc3`) did not finish; incomplete
evidence was discarded and blocking subprocesses used for
the final checks. A direct second-check launch initially lacked an existing
output directory and did not run tests; it was corrected before `stamp-fe5`.

R was actually executed from `C:/Program Files/R/R-4.5.2/bin/R.exe` on
`x86_64-w64-mingw32`, Windows Server 2022. Default clean libraries were
`C:/Users/wb384996/AppData/Local/R/win-library/4.5` and
`C:/Program Files/R/R-4.5.2/library`. All declared Imports and Suggests were
available; `callr` was added only to Suggests for disposable child tests.
`qs2` is required for the catalog even when payloads use RDS; neither it nor
`nanoparquet` was treated as an optional dependency.

The build harness records exact commands, exit codes, dependency versions,
staged entries and tarball contents. Child-only startup/profile/environment
neutralization keeps explicit library paths and temporary roots; no personal
startup file or global library/configuration was edited. Early probes exposed
the personal `.Renviron` temporary-path override; final checks neutralize that
override as well. Tests use synthetic temporary fixtures and disposable evidence
directories; no real store was pruned.

## Efficiency Evidence

`dev/benchmark-audit.R` measured the immutable baseline with seed `20261015`,
three repetitions, R 4.5.2, one data.table thread and one default QS2 thread.
The final run completed 114 measurement rows under
`stamp-benchmark-6c4c61eb250e/`: `measurements.rds`, `measurements.txt`,
`metadata.txt` and `dependency-minimums.txt`.

| Scenario | Observation |
| --- | --- |
| Unchanged save, 1,000/10,000 rows | One content hash/serialization, no payload write or net file/byte growth. |
| Changed save | Two content hashes/serializations, one RDS write, one QS2 catalog write, two file-copy and three file-move function entries. |
| Changed save, 10,000 rows | 0.06/0.06/0.06 seconds, 916,792 allocated bytes each, net persisted bytes 78,106/78,079/78,076. |
| Catalogs: 10x2 / 10x20 / 100x2 / 100x20 | Persisted 854/1,496/2,008/6,409 bytes; warmed reads allocated 38,624/70,560/74,400/391,200 bytes. |
| 50-node chain children | 99 catalog reads and 10,335,440 allocated bytes; lineage used one catalog read and 3,453,752 allocated bytes. |
| Combine 100 partitions x 100 rows | `Reduce(rbind)` allocated 28,649,824 bytes versus 435,904 for output-identical `rbindlist`; 0.03/0.03/0.05 seconds versus below timer resolution. |
| 100 observed diagonal key pairs | Modeled grid/filter construction allocated 1,286,344 bytes versus 10,808 for sparse construction, with identical sorted output. Baseline uses `split()`, not `expand.grid()`. |
| 100-file listing | Repeated scans 0.06/0.05/0.06 seconds; one scan 0/0.02/0, with identical paths. |

Timing includes tracing, allocation profiling and correctness assertions.
Allocations exclude untracked native memory, bytes are net persisted bytes,
and file-operation counts are R function entries, not OS syscalls. Below timer
resolution is not instantaneous execution. No speed threshold was added to
routine tests. Network/PIP-scale, cold cache, peak RSS and general concurrency
performance are unverified. Performance-only source changes were not applied.

## Lifecycle Recommendations

| Candidate | Usage Evidence, Replacement, Impact and Sequence |
| --- | --- |
| `.st_versions_root()` | Already deprecated centralized layout; no baseline R/test caller. References remain in NEWS and stamp-directory vignette. Prefer distributed `.st_version_dir(rel_path, id, alias)`. Review documentation and external `:::` use, announce removal, then remove later. Never relocate stores as part of removal. |
| `.st_path_matches_alias()` | No baseline executable caller; new tests exercise it. Main routing uses longest-root detection/normalization with different NULL/auto-switch semantics. Investigate legacy status; do not blindly substitute. Review external internal-API use and document before later deletion. |
| `.st_extract_rel_path()` | No baseline executable caller; historical NEWS/logs describe prior prune use. Central normalizer returns `rel_path`, but special filename/stmeta/versions behavior differs. Sweep docs/callers and warn before future deletion. |
| `force_on_code_change` | Default/validator/docs exist; save decisions do not read it. Document no-op, consider explicit-setter deprecation, then remove later. Wiring it now changes version creation policy and requires approval. |
| `data_folder` | Default/stale path prose exist; storage uses alias root plus relative path. Deprecate no-op before removal. Making it effective relocates identity/history and needs a migration design. |
| `st_filter()` | Exported, documented in README/pkgdown and used in setup vignette with behavioral tests. Retain supported convenience with strict unknown-column diagnostics; size or lack of internal callers is not evidence for removal. |
| Overlapping selectors | Canonical `0`/negative offsets now agree. Restore-only positive positions remain temporarily compatible with warnings; migrate positive `p` to `1-p`, then remove support in a future release rather than silently reinterpret it. |
| Partitions and `st_path()` | Unfinished/deferred, not obsolete legacy. Keep internal; resolve fidelity/validation and real-world evidence before any export decision. |
| Repeated hash/catalog/scans/binds | Measured optimization candidates above. Prototype compatible output-identical alternatives separately, benchmark on representative target storage, then request approval; no audit-time performance refactor. |

## Reproduction and Remaining Work

Use the developer scripts with a verified existing scratch parent. They do not
write actual artifact stores or replace the user's working tree:

```powershell
$env:RSTUDIO_PANDOC = 'C:/Program Files/Positron/resources/app/quarto/bin/tools'
$env:STAMP_AUDIT_NO_MANUAL = 'true'
& 'C:/Program Files/R/R-4.5.2/bin/R.exe' --vanilla --slave `
  -f dev/audit-check.R --args . `
  'C:/Users/wb384996/AppData/Local/Temp/2/kilo' '<new-label>' cran
```

`STAMP_AUDIT_NO_MANUAL=true` omits only PDF manual generation, matching the
final local runs because `pdflatex` is unavailable (`stamp-fe/check.log:70-73`).
Leave it unset to attempt the full manual check on a host with LaTeX.
Use `extended` for child-only `NOT_CRAN=true`, or `shuffle:20261015` for
seeded case reordering in disposable source plus test-file shuffling. Optional
`STAMP_AUDIT_FAST=true` explicitly omits vignette/manual checks for diagnosis,
not CRAN verification. `STAMP_AUDIT_TEST_OVERLAY` runs the new IO regressions
against a supplied original source mirror; it never reverts source files.

Run `dev/function-audit.R` with `--root`, `--out`, explicit `--library`, and
optional `--coverage`/`--evidence`; its header documents schemas. It rejects
unknown source IDs, stale source hashes, or adequate labels without required
passing scenario evidence. `dev/curate-function-audit.R` integrates reviewed
contracts/assertions separately from AST call references. `dev/audit-coverage.R`
runs test-only covr on a staged package in a fresh process. Coverage is not a
branch/assertion oracle and cannot certify a skipped scenario.

The installed 65-package dependency closure has no explicit R requirement above
4.1; this is metadata evidence, not minimum-version compilation/runtime proof.
The added check workflow covers Windows/Linux release R, Linux 4.1 and Linux
devel, with CRAN-style/extended configurations and failure artifacts. Existing
coverage reporting is retained and includes `ready_cran`. No remote matrix job
was submitted or observed during this audit; those results remain pending.
Both workflow YAML files parsed successfully locally. The source tarball was
inspected: runtime code, documentation, tests and built vignettes are present;
development audit scripts/reports, `.kilo`, `.compound-gpid` and Git state are
not packaged. Read-only `git diff --check` passed; local LF/CRLF conversion
warnings were not treated as whitespace errors or corrected through git config.
