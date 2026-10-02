---
date: 2026-10-02
title: "options()/on.exit() does not restore st_opts() state — it's a no-op"
category: "bugs"
language: "R"
tags: [testthat, st_opts, test-isolation, state-leakage, withr]
root-cause: "st_opts() stores state in a package-level environment (.stamp_opts via rlang::env_bind), which is entirely separate from base R's options(); snapshotting/restoring base options() never touches it"
severity: "P2"
---

# options()/on.exit() does not restore st_opts() state — it's a no-op

## Problem

Ten `test_that()` blocks in `tests/testthat/test-write-parts.R` (and one in
`test-hash-sanitize.R`) opened with:

```r
old_opts <- options()
on.exit(options(old_opts), add = TRUE)
```

intending to snapshot and restore the package's option state so that changes
made inside one test (e.g. `st_opts(default_format = "rds")`) wouldn't leak
into other tests. Separately, `test-partitions.R` called
`st_opts(warn_missing_pk_on_load = FALSE)` at **file top level**, outside any
`test_that()` block, with no cleanup at all.

## Root Cause

`stamp::st_opts()` does not read or write base R's `options()`. It binds into
a package-private environment:

```r
# R/options.R
st_opts <- function(..., .get = FALSE) {
  ...
  rlang::env_bind(.stamp_opts, !!!args)   # NOT options()
  ...
}
```

So `old_opts <- options(); on.exit(options(old_opts))` snapshots and restores
*base R options* — completely unrelated state. Every `st_opts()` call inside
those ten tests was a permanent, unscoped mutation of package state for the
rest of the test run. The top-level `st_opts(warn_missing_pk_on_load = FALSE)`
in `test-partitions.R` was the worst case: it silently suppressed a
missing-primary-key warning for every test file that ran afterward in the
same session.

This bug was invisible because it degrades gracefully — tests still passed,
they just asserted against a weaker signal (a missing warning that should
have fired, didn't).

## Solution

Added a real snapshot/restore helper that round-trips through `st_opts()`'s
actual getter/setter contract:

```r
# tests/testthat/helper-opts.R
local_st_opts <- function(..., .local_envir = parent.frame()) {
  old <- st_opts(.get = TRUE)
  withr::defer(suppressMessages(do.call(st_opts, old)), envir = .local_envir)
  if (...length()) {
    suppressMessages(st_opts(...))
  }
  invisible(old)
}
```

Replaced all eleven leaking sites with `local_st_opts(...)`, including
scoping the previously-unscoped top-level call in `test-partitions.R`.

**Verification signal that the fix mattered**: after scoping the leak,
`R CMD check --as-cran`'s WARN count rose from 7 to 9 — the two new warnings
are the missing-PK warning that had been silently suppressed across test
files, now firing where it always should have.

## Prevention

- Before writing a "snapshot and restore" test helper for *any* package
  option system, check whether the package's option accessor actually reads
  from/writes to base `options()`. Many packages (this one included) use a
  private environment instead — `options()`/`on.exit(options(old))` only ever
  restores base R options, nothing else.
- The correct idiom already existed once in the codebase
  (`test-pruning.R`, using `st_opts(..., .get = TRUE)` + `withr::defer`) —
  check for an existing working pattern in the same test suite before writing
  a new one from scratch.
- Never set package options at file top level in a test file. Scope every
  mutation to the `test_that()` block that needs it.

## Related

- `.cg-docs/reviews/2026-09-30-cran-release-without-partitions-review.md` —
  finding P2.14 (assertion quality and state leakage in `tests/testthat/`).
