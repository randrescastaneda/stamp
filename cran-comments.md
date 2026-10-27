## Submission

This is the first CRAN submission of stamp 0.0.11.

## Local Test Environment

* macOS Tahoe 26.7.1, aarch64, R 4.6.1, checked on 2026-10-26.

## Local R CMD Check Results

`R CMD check --as-cran --run-donttest stamp_0.0.11.tar.gz`:

0 errors | 0 warnings | 1 NOTE

The NOTE is the expected incoming-feasibility message: "New submission".

* All 4,171 test assertions passed, with no failures, test warnings, or skips.
* Checked with current CRAN dependencies in an isolated library, including
  data.table 1.18.6.1, qs2 0.3.1, and rlang 1.3.0.
* Examples, vignette rebuilds, and the PDF and HTML manuals passed.
* All 39 exported functions have documented return values and runnable examples.
* All 13 URLs checked by `urlchecker::url_check()` passed.
* Tests inject dependency failures into local function copies without changing
  base R or dependency namespaces.
* Local project bindings, development files, and manual test scripts are
  excluded from the source package.

## Reverse Dependencies

There are currently no CRAN reverse dependencies. This is the first CRAN
submission.

## Continuous Integration

All eight package-check jobs passed on 2026-10-27 for commit `df2084e`.
Warnings are treated as failures in every job.

| Platform | R | Check mode | Result |
| --- | --- | --- | --- |
| Ubuntu 24.04, x86_64 | 4.6.1 | CRAN, with manuals | Passed |
| Ubuntu 24.04, x86_64 | 4.6.1 | Extended | Passed |
| Ubuntu 24.04, x86_64 | 4.1.3 | Extended | Passed |
| Ubuntu 24.04, x86_64 | R-devel | Extended | Passed |
| Windows, x86_64 | 4.6.1 | CRAN | Passed |
| Windows, x86_64 | 4.6.1 | Extended | Passed |
| Windows, x86_64 | R-devel | CRAN | Passed |
| macOS, aarch64 | 4.6.1 | CRAN | Passed |

All jobs run `--run-donttest`. CRAN-mode jobs also run `--as-cran`.
The Linux manual job reports `Status: OK`, including PDF generation and
HTML validation with HTML Tidy. The local check above also includes the
incoming-feasibility check and its expected "New submission" NOTE.

* [Package-check results](https://github.com/randrescastaneda/stamp/actions/runs/40505291743)
* [Coverage check: passed](https://github.com/randrescastaneda/stamp/actions/runs/40505291738)

The package files in the source archive match the checked package source.
Submission notes and CI configuration are excluded from the source package.

## Win-Builder

The locally checked source archive was uploaded once for an R-devel check on
2026-10-26. Win-builder accepted the upload with HTTP status 200. It sends
the report link to the maintainer email address. That report is not available
in this session, so no win-builder pass is claimed. The separate GitHub
Windows R-devel check above passed.

No CRAN submission has been made.
