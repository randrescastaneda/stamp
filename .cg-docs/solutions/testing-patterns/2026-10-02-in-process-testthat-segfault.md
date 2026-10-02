---
date: 2026-10-02
title: "In-process testthat::test_local() segfaults silently — verify via R CMD check instead"
category: "testing-patterns"
language: "R"
tags: [testthat, segfault, r-cmd-check, windows, subprocess, verification]
root-cause: "In-process test harness artifact on this R 4.5.1/Windows setup; the package's tests are fine, confirmed by R CMD check running the same suite in a clean subprocess"
severity: "P2"
---

# In-process testthat::test_local() segfaults silently — verify via R CMD check instead

## Problem

Three separate attempts to run `testthat::test_local()` / `testthat::test_file()`
directly in the development terminal (to verify a fix before doing a full
`R CMD check`) crashed the R process with exit code `0xC0000005`
(ACCESS_VIOLATION) and printed **zero output** — not even a partial test
summary. This looked like either a broken test harness or a serious
regression in the package.

## Root Cause

The crash is an artifact of running testthat in-process in this terminal
environment, not a defect in the package: the identical test suite passes
cleanly, every time, inside `R CMD check`'s own subprocess harness (consistent
~21-22s runtime, `FAIL 0`). The in-process harness differs from `R CMD check`
in process isolation and likely interacts badly with native code in one of
the package's dependencies under this R 4.5.1/Windows setup.

The **zero output** is itself a trap: R block-buffers stdout when it is
piped or redirected (as it is when driven from an automated terminal). A hard
crash (segfault) discards whatever was in that buffer before it could be
flushed — so an empty terminal result does not mean nothing executed, it
means the crash happened before the buffer was flushed. Don't read "no
output" as "nothing ran" or "nothing to report."

## Solution

Stopped using in-process `testthat::test_local()`/`test_file()` for
verification entirely in this environment. Switched the verification
protocol to:

```powershell
& "C:\Program Files\R\R-4.5.1\bin\R.exe" CMD build . > "$env:TEMP\build.txt" 2>&1
& "C:\Program Files\R\R-4.5.1\bin\R.exe" CMD check --as-cran stamp_x.y.z.tar.gz > "$env:TEMP\check.txt" 2>&1
Get-Content 'stamp.Rcheck\00check.log' | Select-String -Pattern 'NOTE|WARNING|ERROR|Status|checking tests' -Context 0,2
Get-ChildItem 'stamp.Rcheck\tests' -Filter *.Rout* | ForEach-Object { Get-Content $_.FullName -Tail 12 }
```

This runs the real test suite inside a clean subprocess (the same one CRAN
uses) and reliably returns `[ FAIL n | WARN n | SKIP n | PASS n ]` plus the
check status, with no crashes across the whole session.

## Prevention

- In this R/Windows setup, never use in-process `testthat::test_local()` or
  `test_file()` as the source of truth for "did my fix work" — use it only
  for fast, disposable iteration, and always confirm with `R CMD check`
  before concluding anything.
- If a terminal command touching R returns **zero output** where you expected
  a summary, check the process exit code before assuming nothing ran — a
  silent crash looks identical to "command not executed yet."
- `devtools`/`rcmdcheck` were not installed in this environment; `R CMD
  build`/`check --as-cran` driven directly are the approved substitutes (see
  session notes for full invocation templates, including the
  `--no-init-file` / `R_PROFILE_USER` workarounds needed because of the
  user's `.Rprofile`).

## Related

- `.cg-docs/reviews/2026-09-30-cran-release-without-partitions-review.md` —
  verification protocol used throughout the fix-triage pass on this package.
