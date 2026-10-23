## Submission

This is the first CRAN submission of stamp 0.0.11.

## Test Environment

* macOS Tahoe 26.7.1, aarch64, R 4.6.1.

## Local R CMD Check Results

`R CMD check --as-cran --no-manual stamp_0.0.11.tar.gz`:

0 errors | 0 warnings | 1 NOTE

The NOTE is the expected incoming-feasibility message: "New submission".

* All 4,171 test assertions passed, with no failures, test warnings, or skips.
* Examples, including `--run-donttest`, and vignette rebuilds passed.
* All 13 URLs checked by `urlchecker::url_check()` passed.
* The local ClickUp binding is excluded from the source package.

## Validation Still Required Before Upload

The current working-tree changes have not yet been checked on Windows or
Linux. PDF-manual generation was not checked because LaTeX is unavailable in
the local environment. Runnable examples still need review: 27 of the 39
exported functions have no example section. These checks and documentation
updates must be completed before submission.
