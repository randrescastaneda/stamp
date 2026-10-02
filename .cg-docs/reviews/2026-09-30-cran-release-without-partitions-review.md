---
date: 2026-09-30
depth: standard
type: standard
plan: .cg-docs/plans/2026-09-30-cran-release-without-partitions.md
findings:
  P1.1: fixed
  P1.2: fixed
  P1.3: fixed
  P1.4: fixed
  P1.5: deferred
  P1.6: deferred
  P2.1: fixed
  P2.2: fixed
  P2.3: fixed
  P2.4: deferred
  P2.5: deferred
  P2.6: deferred
  P2.7: deferred
  P2.8: deferred
  P2.9: deferred
  P2.10: deferred
  P2.11: fixed
  P2.12: fixed
  P2.13: skipped
  P2.14: fixed
  P3.1: fixed
  P3.2: fixed
  P3.3: deferred
  P3.4: deferred
  P3.5: fixed
  P3.6: fixed
  P3.7: fixed
---

## Review Report

**Review mode**: standard (8 agents)
**Scope**: `324ece4..HEAD` — commits `8dc5c67`, `3bed3e0`, `e26edfc`; 42 files, +199 / -906
**Findings**: 27 (P0: 0, P1: 6, P2: 14, P3: 7)

### Reading note

The partition-unexport work itself is **clean**. Four agents independently verified: no
missed `stamp:::` call site, no mutated test description, no dangling `\link{}`, no broken
pkgdown reference, correct vignette renumbering, unidirectional `partitions.R -> core`
dependency, and dependency metadata still justified. The `partition_key` removal is safe —
no consumer exists anywhere.

Most findings below are **pre-existing defects that the review surfaced**, not regressions
introduced by this plan. They split into two groups:

- **Ships to CRAN** (P1.1–P1.4, P2.1–P2.3, P2.11–P2.13): affects the tarball, the public
  API, or published documentation.
- **Parked code** (P1.5, P1.6, P2.4–P2.10): inside `R/partitions.R`, now internal. These
  are direct input to the deferred `post-cran-partitions` milestone and are, in effect,
  the real-data validation evidence the milestone was created to gather.

---

### P1 — CRITICAL (must fix before merge)

- **[P1.1]** [cg-version-control, cg-code-quality] [.Rbuildignore](.Rbuildignore) — build artifacts are gitignored but **not** Rbuildignored `[safe_auto]`
  **Why**: `stamp.Rcheck/` and `stamp_0.0.11.tar.gz` both exist in the package root right now (verified by directory listing). `8dc5c67` added them to `.gitignore` but added no `.Rbuildignore` rule, and R's default exclusion list covers neither. The next `R CMD build .` will sweep an entire check directory — which contains an installed copy of the package — plus a nested tarball into the submission. The current clean `1 NOTE` status only holds because the tarball was built *before* the check directory existed; it will not survive a build-after-check cycle.
  **Fix**: append `^.*\.Rcheck$` and `^.*\.tar\.gz$`.

- **[P1.2]** [cg-documentation] [README.Rmd](README.Rmd#L73) — the `.qs` / `{qs}` format is documented but does not exist `[safe_auto]`
  **Why**: Verified against the installed package — registered formats are exactly `csv, fst, json, parquet, qs2, rds`. There is no `qs` reader, writer, or extension mapping, and `qs` is not in `Suggests`. Three separate claims are wrong: the table row advertising `.qs`; "There is no automatic fallback between them" (unrecognized extensions **do** fall back to `default_format`, silently writing qs2 content to a `.qs` path); and "Existing `.qs` files can still be loaded if `{qs}` is installed" (`{qs}` is never consulted). This is the fourth instance of the README-documents-nonexistent-API defect, after `st_auto_partition`, `st_hash_code`, and `st_hash_file` — and the first that a function-name sweep could not catch.
  **Fix**: drop the `.qs` row and rewrite the two paragraphs below it to describe the real fallback behaviour.

- **[P1.3]** [cg-data-quality] [R/schema_pk.R](R/schema_pk.R#L199) — `st_filter()` silently returns unfiltered data `[manual]`
  **Why**: **Empirically verified against the installed package**, on a 2-row frame:
  | call | result |
  |---|---|
  | `st_filter(d, list("PER"))` — unnamed, `strict = TRUE` | **2 of 2 rows** (no error) |
  | `st_filter(d, list(cuntry = "PER"), strict = FALSE)` — typo | **2 of 2 rows** (no warning) |
  | `st_filter(d, list(country = "PER"), strict = "yes")` | accepted silently |
  An unnamed `filters` gives `names(filters) == NULL`, so `setdiff(NULL, names(df))` is empty (the strict check passes) and the `for` loop never iterates — the full frame is returned **under `strict = TRUE`**. This is an **exported** function shipping to CRAN, and a filter that silently does not filter is the worst possible failure mode. Direct violation of the charter's fail-loudly rule.
  **Fix**: validate `strict` as `logical(1)` non-NA; abort when `filters` is non-empty but not fully named; warn rather than `next` on unknown names under `strict = FALSE`.

- **[P1.4]** [cg-architecture, cg-data-quality, cg-testing] [R/IO_core.R](R/IO_core.R#L126) — `st_path()` is an orphaned export `[manual]`
  **Why**: Verified — there is **no** `inherits(file, "st_path")` branch anywhere in `R/IO_core.R`. `st_save()` and `st_load()` both document `file` as accepting an `st_path`, but every path flows through `.st_normalize_user_path()`, which hard-aborts on non-character input. So `st_save(x, st_path("a.qs2"))` fails today with a misleading message. Removing `partition_key` reduced the object to `list(path, format)`, and `format` is never read either — `st_save()` re-derives it from the character path. The constructor is exported, has an S3 `print` method, is taught in a vignette (where it is only ever printed), and is in the pkgdown index. It has zero effect on package behaviour. Note this is **pre-existing**, not caused by the diff — but the diff removed the last field that gave the object any content.
  **Fix**: either honour the contract (~6 lines: unwrap `st_path` at the top of `st_save()`/`st_load()`, which also makes `format` meaningful for the first time), or withdraw it the same way partitions were withdrawn. Do not ship the status quo.

- **[P1.5]** [cg-performance, cg-data-quality] [R/partitions.R](R/partitions.R#L659) — `warned_formats <<-` writes into the user's global environment `[manual]`
  **Why**: The `<<-` sits inside a `tryCatch` expression evaluated in the `st_load_parts()` frame, so its search starts at `parent.env()` — the package namespace — skips the local binding at line 618, finds nothing on the search path, and **creates the variable in `.GlobalEnv`**. Two consequences: it clobbers any user object of that name (a CRAN-policy concern — packages must not modify the global environment), and the warn-once guard never works, so the "column selection not supported" warning fires **once per partition file**. At PIP scale that is tens of thousands of `cli_warn()` calls, each building a condition object and walking the handler stack.
  **Fix**: hoist the accumulator into `new.env(parent = emptyenv())` and mutate `state$formats`. Environment mutation is unaffected by which frame the promise evaluates in.

- **[P1.6]** [cg-testing, cg-data-quality] [R/aaa.R](R/aaa.R#L157), [tests/testthat/test-write-parts.R](tests/testthat/test-write-parts.R#L107) — partition key **values** are case-folded on Windows, and the tests are built so they cannot detect it `[manual]`
  **Why**: `.st_normalize_path()` applies `tolower()` to the *entire* path on Windows, which lands inside the Hive key segment. `st_save_part(key = list(country = "COL"))` physically writes `country=col/`; `st_load_parts()` reads back `"col"` and **assigns it over the column already present in the file**. Reproduced directly by an agent:
  ```
  manifest$path[1]  -> .../country=USA/year=2020/part.parquet
  on disk           -> .../country=usa/year=2020/part.parquet
  st_list_parts(filter = list(country = "USA")) -> 0 rows
  st_list_parts(filter = list(country = "usa")) -> 3 rows
  ```
  Partition segments are *data*, not just paths — so this is a value-mangling channel between save and load that silently returns zero rows instead of erroring, and behaves differently on Windows vs Linux for identical input. The four `skip()` calls in `test-write-parts.R` are labelled "Partition filtering not fully functional", which is **not** what is happening: the filtering logic is largely fine, the path-normalization layer is not. Because the skips are unconditional rather than `skip_on_os("windows")`, they also delete ~30 working assertions on Linux and macOS. Compounding it, [test-vignette-issues.R](tests/testthat/test-vignette-issues.R#L58) applies `tolower()` to **both sides** of the one assertion that touches key case, making it structurally incapable of failing.
  **Fix**: case-fold for *comparison only*, never for the stored or returned value. Then convert the four skips to `skip_on_os("windows")` with an accurate message, and assert exact case.

---

### P2 — IMPORTANT (should fix)

**Ships to CRAN**

- **[P2.1]** [cg-code-quality, cg-documentation, cg-reproducibility] [vignettes/stamp.Rmd](vignettes/stamp.Rmd#L472) — orphaned partition vocabulary `[safe_auto]`
  **Why**: Flagged independently by three agents. The comment still reads "identify welfare partitions vs macros" and the builder still returns `code_label = "aggregate_welfare_partitioned"`, but the section that defined "partition" was deleted. `code_label` is written into real sidecar metadata, so the vignette now teaches users to stamp provenance with a concept the package no longer exposes.
  **Fix**: reword the comment to "welfare inputs vs macro inputs"; change the label to `aggregate_welfare`. Human-facing strings only — no hash changes.

- **[P2.2]** [cg-version-control] [.gitignore](.gitignore#L5) — `*.tar.gz` and `docs` are unanchored `[safe_auto]`
  **Why**: Both match at any depth. A future `tests/testthat/fixtures/*.tar.gz` would vanish from commits with no error — the silent-failure mode the charter forbids.
  **Fix**: `/*.tar.gz` and `/docs/`.

- **[P2.3]** [5 agents] [dev/partitions.Rmd](dev/partitions.Rmd#L20) — the parked document is no longer runnable `[safe_auto]`
  **Why**: The most-agreed finding in the review. All ~34 chunks call `st_write_parts()` etc. unqualified; those names left NAMESPACE in this diff. The setup chunk's `library(stamp)` fallback now dies with "could not find function", and it only works at all via `load_all()`'s `export_all = TRUE`. It also retains live `%\VignetteIndexEntry{}` metadata and a dangling `?st_write_parts` reference. A parked artifact that cannot be re-executed is a dead reproducibility record — exactly what "park, don't delete" was meant to avoid.
  **Fix**: extend the banner to state that chunks require `pkgload::load_all()` or `stamp:::` prefixes, and point the `?st_write_parts` reference at the source file.

- **[P2.11]** [cg-documentation] [README.Rmd](README.Rmd#L111) — nine exported functions have no README entry `[manual]`
  **Why**: The README→NAMESPACE direction is now clean (all 29 named functions exist). The reverse is not: `st_path`, `st_opts_get`, `st_formats`, `st_register_format`, `st_restore`, `st_switch`, `st_pk`, `st_with_pk`, `st_builders` are exported and in the pkgdown index but absent from the README. `st_restore()` is the headline feature of 0.0.10.
  **Fix**: add entries to the existing sections. (Note `st_path` here interacts with P1.4 — resolve that first.)

- **[P2.12]** [cg-documentation] [_pkgdown.yml](_pkgdown.yml#L83) — no redirect for the removed `articles/partitions.html` `[advisory]`
  **Why**: That URL is currently live and was linked from the README, so it is likely indexed. The next deploy 404s it. `check_pkgdown()` does not detect dangling *inbound* links.
  **Fix**: add a `redirects:` entry mapping it to `index.html`.

- **[P2.13]** [cg-documentation] [man/stamp-package.Rd](man/stamp-package.Rd#L21) — maintainer listed twice `[advisory]`
  **Why**: The `aut`+`cre` person now renders under `\strong{Maintainer}` *and* as the first `Authors:` item. Side effect of the roxygen2 7.3.2 -> 8.0.0 upgrade, not of `Authors@R`. Visible on `?stamp` and the pkgdown reference page for a first CRAN submission.
  **Fix**: confirm against the roxygen2 8.0.0 changelog. Do not hand-edit generated Rd.

- **[P2.14]** [cg-testing] `tests/testthat/` — assertion quality and state leakage `[manual]`
  **Why**: Four sub-issues. (a) `expect_true(nrow(x) >= 2)` against known-exact counts is a smoke check, and passes even if `st_load_parts()` silently drops a partition — the exact failure mode of P1.6. (b) Four `expect_error()` calls have no message pattern, so they pass on any error including an unrelated `stopifnot`. (c) `test_that("multiplication works", ...)` is leftover `usethis` scaffolding, so `test-partitions.R` has 8 real assertions, not 9. (d) `st_opts()` is set at file top-level with no restore, and the `old_opts <- options()` cleanup repeated in ten blocks of `test-write-parts.R` is a **no-op** — `st_opts()` writes to a package environment, not `options()`. The suite currently depends on file ordering; `shuffle = TRUE` would expose it.
  **Fix**: exact assertions, message patterns on `expect_error`, delete the scaffolding test, and factor a `local_st_opts()` helper (the correct idiom already exists at `test-pruning.R:34`).

**Parked code — input to `post-cran-partitions`**

- **[P2.4]** [cg-performance, cg-data-quality] [R/partitions.R](R/partitions.R#L311) — `interaction()` and `split()` default to `drop = FALSE` `[manual]`
  **Why**: For a sparse cross-product — the normal case for country x year x reporting_level — unobserved combinations become zero-row groups. The key is then extracted via `part_data[1L, ...]` on a zero-row frame, yielding an all-`NA` key, so every absent combination tries to write to the same `country=NA/year=NA/` path, each overwriting the last and each minting a spurious catalog version. At 170 x 35 x 3 that is ~15,000 wasted iterations. Existing tests use a fully-populated 2x2x3 grid and cannot catch it.
  **Fix**: `drop = TRUE` on both, plus `stopifnot(nrow(part_data) > 0L)`; add a sparse-grid test.

- **[P2.5]** [cg-data-quality] [R/partitions.R](R/partitions.R#L191) — folder key is never validated against contents, and load trusts the folder over the file `[manual]`
  **Why**: `st_save_part(df_of_CAN, key = list(country = "USA"))` succeeds silently. On read, `obj[[k]] <- listing[[k]][[i]]` **overwrites** the real column with the folder-derived value — so a mis-filed partition is not merely mis-filed, loading rewrites its data to match the lie. The removed vignette's "folder keys should agree with PK columns" described an invariant enforced nowhere. Also, `unique = TRUE` validates PK uniqueness only *within* each partition, never across the rbound result.
  **Fix**: assert key/column agreement at save; change the load overwrite to check-then-fill.

- **[P2.6]** [cg-data-quality] [R/partitions.R](R/partitions.R#L682) — `st_load_parts()` silently discards unreadable partitions `[manual]`
  **Why**: `error = function(e) NULL` then `next` — no warning, no counter. A corrupt file or missing `nanoparquet` drops that partition's rows and the caller gets a plausible, quietly incomplete frame. Poverty aggregates on a silently truncated panel are wrong in a way nobody can see.
  **Fix**: collect failures and abort at the end; make tolerance an explicit opt-in defaulting to abort.

- **[P2.7]** [cg-data-quality] [R/partitions.R](R/partitions.R#L370) — `st_write_parts()` downgrades save failures to warnings `[manual]`
  **Why**: A PK-uniqueness violation — the one guarantee `unique = TRUE` documents — becomes a warning, and the run "succeeds" with partitions missing from disk *and* from the manifest. When every partition fails (e.g. `nanoparquet` absent, since `format` defaults to `"parquet"` unconditionally) it returns an empty frame **invisibly**, indistinguishable from success at the console.
  **Fix**: let errors propagate, or abort at the end listing every failure; validate format availability once before the loop.

- **[P2.8]** [cg-data-quality] [R/partitions.R](R/partitions.R#L128) — expression filters leak into the caller's environment and swallow errors `[manual]`
  **Why**: `enclos = parent.frame(n = 3)` means an unmatched name falls through to whatever is bound in the calling frame — a user's local `year` would be silently used for every partition. The hard-coded depth is itself an implementation detail, not a contract. Paired with `error = function(e) FALSE` and the comment "Silently fail for invalid expressions", a misspelled key yields an empty result rather than an error.
  **Fix**: evaluate with `enclos = baseenv()`; pre-validate `all.vars(filter_expr)` against the key names once, before the loop.

- **[P2.9]** [cg-performance] [R/partitions.R](R/partitions.R#L721) — `Reduce(rbind)` is quadratic `[advisory]`
  **Why**: Pairwise accumulation copies the accumulator on every step, and the two `a[...] <- NA` / `a[, cols]` lines each force an *additional* full copy — so roughly `3 * O(n^2)`. The `"dt"` branch two lines above already uses `rbindlist(fill = TRUE)` correctly; the `"rbind"` branch hand-reimplements it slowly.
  **Fix**: route through `rbindlist()` then `setDF()` (converts by reference, preserving the documented return type).

- **[P2.10]** [cg-performance] [R/partitions.R](R/partitions.R#L486) — six full recursive tree walks per listing `[advisory]`
  **Why**: `lapply(globs, fs::dir_ls(recurse = TRUE, glob = g))` issues one complete recursive walk **per known extension** (~6), then discards most results with five `grepl()` filters. On a network filesystem — where PIP data lives — this dominates `st_list_parts()` and therefore `st_load_parts()`.
  **Fix**: walk once, filter with a single alternation regexp.

---

### P3 — MINOR

- **[P3.1]** [cg-code-quality] [R/partitions.R](R/partitions.R#L165) — `# ---- Public API ----` banner now states the opposite of the truth `[safe_auto]`
- **[P3.2]** [cg-code-quality, cg-documentation] [R/version_store.R](R/version_store.R#L747) — three coexisting internal-doc conventions (`@keywords internal`, both tags, `@noRd` alone). Pick one per file. `[advisory]`
- **[P3.3]** [cg-data-quality] [R/partitions.R](R/partitions.R#L29) — value sanitation is incomplete: `\` is unchecked (path-traversal write primitive on Windows), plus `:`, `*`, `?`, reserved device names, trailing dots, empty string, and `NA` (which becomes the literal directory `country=NA` — and `"NA"` is Namibia's ISO code). `[manual]`
- **[P3.4]** [cg-data-quality] [R/partitions.R](R/partitions.R#L556) — key types are carefully inferred from the path, then flattened to `character` and written over typed columns, so `year` returns as `"2020"` and `dt[year == 2020L]` silently returns zero rows. `[manual]`
- **[P3.5]** [cg-data-quality] [R/partitions.R](R/partitions.R#L37) — `order(names(v))` is locale-dependent, so the same logical key can produce different physical paths under different `LC_COLLATE`. Use `method = "radix"`. `[safe_auto]`
- **[P3.6]** [cg-documentation] [NEWS.md](NEWS.md#L1) — 0.0.11 does not mention that the Partitions vignette was withdrawn; a reader following a bookmark has no explanation. `[safe_auto]`
- **[P3.7]** [cg-reproducibility] vignette loading strategy is split 4/3 — four vignettes call `pkgload::load_all()` unguarded, so rendered output reflects the source tree on a dev machine and the installed tarball on a CRAN builder. Pre-existing, but it is the largest remaining determinism gap. `[manual]`

---

### Passed / verified clean

- **Secrets**: none. Full scan for `ghp_`/`github_pat`/AWS keys/PEM blocks/bearer tokens across all added lines. The out-of-repo `~/.Renviron` PAT exposure has **not** leaked in.
- **Partition scrub completeness**: no dangling `\link{}`, `@seealso`, vignette link, or pkgdown entry targets removed content.
- **Vignette object graphs**: no surviving chunk depends on an object created by a deleted chunk; `set.seed(123)` still precedes every consumer; the deleted RNG consumer sat *after* the last surviving one, so no rendered output shifts.
- **Dependencies**: nothing orphaned — `nanoparquet` and `fst` keep consumers; DESCRIPTION needs no edit.
- **`stamp:::` rewrite**: all 42 call sites converted, zero missed, no `test_that()` description mutated, baseline counts reproduced exactly.
- **`.Rbuildignore` regexes** (existing entries): all correct and properly anchored, including `^compound-gpid.*\.md$` and `^dev$`.
- **`dev/` convention**: sound — tracked in git, excluded from the tarball, matches the existing `^copilot_logs$` precedent.
- **`@noRd` over `@keywords internal`**: the right call. It preserves the full roxygen block in source, so re-export is a five-token change; `@keywords internal` would have shipped help pages for functions CRAN users cannot call.
- **Branch state**: fast-forward mergeable, 5 ahead / 0 behind, clean tree.
- **DESCRIPTION / NEWS / charter**: consistent; Title and Description conform to CRAN policy.


---

## Disposition of the four P1 decisions (2026-10-02)

| Finding | Decision | Where it lives now |
| --- | --- | --- |
| P1.3 `st_filter()` silent pass-through | **Fixed pre-CRAN** — all three holes (unnamed filters, silent skip under `strict = FALSE`, uncoerced `strict`) | `R/schema_pk.R`; new `tests/testthat/test-filter.R` (13 assertions — the function previously had **zero** coverage) |
| P1.4 `st_path()` orphaned export | **Fixed pre-CRAN via Option B — unexported.** Chosen over wiring it in, because removing an export after CRAN acceptance costs a deprecation cycle while adding one later is free | `R/IO_core.R` (`@keywords internal`, `S3method(print, st_path)` retained); docs, `vignettes/setup-and-basics.Rmd` and `_pkgdown.yml` corrected |
| P1.5 `warned_formats` globalenv leak | **Deferred.** Approach decided: function-local environment, not removal of the warn-once logic | roadmap `post-cran-partitions` / `fix-warned-formats-globalenv-leak` |
| P1.6 Windows case-folding + mislabelled skips | **Deferred** in full, bug and tests together | roadmap `post-cran-partitions` / `fix-windows-case-folding-of-partition-keys` |

Re-exporting `st_path` once it works uniformly is tracked as
`post-cran-api-polish` / `wire-st-path-through-path-taking-functions`.

`roadmap.json` stores only `id`, `title`, `status` and `plan` per feature, so the
technical detail behind those three ids is the P1.4/P1.5/P1.6 sections of this
document. Read them before starting any of that work.

**Post-fix gate**: `R CMD check --as-cran` -> `Status: 1 NOTE` (New submission only);
tests `[ FAIL 0 | WARN 7 | SKIP 7 | PASS 407 ]`, up from 394.
