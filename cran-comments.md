## Submission

This is the first CRAN submission of stamp 0.0.11.

## Test Environment

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

## Validation Still Required Before Upload

The current source archive has not yet been checked on Windows, Linux, or
R-devel. The latest earlier CI run passed on Linux but failed on Windows
because two graph-test fixtures did not use the planner's canonical paths.
Those fixtures have been corrected, but a fresh Windows run is still required.

Run the updated R-CMD-check workflow for this candidate before upload. It
includes macOS, Linux, Windows, R-devel, and R 4.1, with PDF-manual generation
on Linux and warnings treated as failures. Alternatively, check the source
archive with win-builder using `devtools::check_win_devel()` and obtain fresh
Linux results. Record the results here before submitting.

No CRAN submission or remote-builder upload has been made for this candidate.
