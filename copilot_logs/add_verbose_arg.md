# Add Verbose Argument to st_load, st_save, and st_load_version

**Task:** `add_verbose_arg`  
**Date:** January 15, 2026  
**Branch:** `fix_verbose`  
**Repository:** stamp (local)

---

## 1. Task Overview

### What the Task Was About

The task added a `verbose` argument to the core save/load functions in the `stamp` package to give users control over informational messages during file operations.

- **Problem:** `st_save()`, `st_load()`, and `st_load_version()` always printed informational messages (via `cli::cli_inform()`), with no way to suppress them.
- **Goal:** Add `verbose = TRUE` parameter to all three functions and ensure the parameter is consistently forwarded to format handlers and respected by the format wrappers.
- **Scope:** Core I/O functions, format wrappers, and tests.

### Main Files and Functions Affected

- `R/IO_core.R` — `st_save()`, `st_load()`
- `R/version_store.R` — `st_load_version()`
- `R/format_registry.R` — `.st_wrap_reader()`, `.st_wrap_writer()`
- `tests/testthat/test-format-wrappers.R` — new tests

### Major Decisions and Trade-Offs

- Defaulted `verbose = TRUE` to preserve backward compatibility.
- Gate all user-facing messages with `if (isTRUE(verbose))` for safe boolean handling.
- Forward `verbose` to wrapped format readers/writers; wrappers suppress warnings when `verbose = FALSE`.
- Trade-off: when `verbose = FALSE` some format warnings are suppressed — documented for users.

---

## 2. Technical Explanation

### How the change works (step-by-step)

- st_save():
  - Signature now includes `verbose = TRUE`.
  - Informational messages (success) wrapped in `if (isTRUE(verbose))`.
  - Calls format writer as `h$write(x_final, sp$path, verbose = verbose, ...)`.

- st_load():
  - Signature now includes `verbose = TRUE`.
  - When delegating to `st_load_version()` forward `verbose`.
  - Calls format reader as `res <- h$read(sp$path, verbose = verbose, ...)`.
  - Informational and warning messages gated by `if (isTRUE(verbose))`.

- st_load_version():
  - Signature now includes `verbose = TRUE`.
  - Calls format reader as `res <- h$read(art, verbose = verbose, ...)`.
  - Informational messages gated by `if (isTRUE(verbose))`.

- Format wrappers:
  - `.st_wrap_reader()` and `.st_wrap_writer()` return functions that accept `verbose = TRUE` and suppress warnings via `suppressWarnings()` when `verbose = FALSE`.

### Key design choices

- Use `isTRUE(verbose)` to avoid surprises from `NULL`, `NA`, or non-logical inputs.
- Keep default behaviour unchanged (verbose = TRUE).
- Ensure wrappers handle `verbose` centrally so format functions never receive unexpected `verbose` args.

---

## 3. Plain-language overview

- Purpose: let users silence the package’s save/load messages during batch processing or scripting.
- Usage:
  - Default (messages shown): `st_save(obj, "a.rds")`
  - Quiet: `st_save(obj, "a.rds", verbose = FALSE)`
- Both `st_load()` and `st_load_version()` behave identically with respect to `verbose`.

---

## 4. Documentation and comments

- Added `@param verbose` roxygen entries for `st_save()`, `st_load()`, and `st_load_version()`.
- Maintainers should wrap any new `cli::cli_*()` calls in `if (isTRUE(verbose))`.
- Note: format wrappers are internal but document the behavior inline.

---

## 5. Validation bundle

### Checklist

- [x] `st_save()` includes `verbose = TRUE` and gates messages.
- [x] `st_load()` includes `verbose = TRUE`, gates messages, forwards `verbose` to `st_load_version()`.
- [x] `st_load_version()` includes `verbose = TRUE` and gates messages.
- [x] Format wrappers accept `verbose` and suppress warnings when `FALSE`.
- [x] Backward compatibility preserved.

### Tests added

- `tests/testthat/test-format-wrappers.R`
  - Verifies wrappers expose `verbose` in their formals
  - Checks that warnings appear with `verbose = TRUE` and are suppressed with `verbose = FALSE`
  - Tests registered and custom formats
  - End-to-end quiet save/load integration test

### Error handling

- `isTRUE(verbose)` treats non-TRUE inputs as `FALSE` (quiet).
- Wrappers intercept `verbose` so underlying format functions never receive unexpected args.

---

## 6. Dependencies and risk analysis

- No new external dependencies introduced.
- Risk: suppressing warnings with `verbose = FALSE` can hide legitimate issues — documented and reversible by setting `verbose = TRUE`.
- Recommended: audit other user-facing functions for consistent `verbose` gating if needed.

---

## 7. Actions taken / Files changed

- `R/IO_core.R` — added `verbose` to `st_save()`/`st_load()`, gated messages, forwarded to format handlers.
- `R/version_store.R` — added `verbose` to `st_load_version()`, gated messages.
- `R/format_registry.R` — verified wrappers already support `verbose`.
- `tests/testthat/test-format-wrappers.R` — added comprehensive tests.

---

## 8. Follow-ups

- Add short examples in function docs demonstrating `verbose = FALSE`.
- Optionally audit CLI calls across the package to consistently respect `verbose`.

---

## 9. Conclusion

The `verbose` argument provides a simple, consistent mechanism to silence informational messages and format warnings for scripted or batch use. Changes are backward compatible and covered by tests.
