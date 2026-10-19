# Reproducible, disposable build/check harness. No user profile or library edits.
# R --vanilla --slave -f dev/audit-check.R --args <source> <existing-parent> <label>
# Optional fourth argument: cran (default), extended, stage, or shuffle:<seed>.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 3L, dir.exists(args[1L]), dir.exists(args[2L]))
root <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
parent <- normalizePath(args[2L], winslash = "/", mustWork = TRUE)
out <- file.path(parent, args[3L])
if (dir.exists(out)) stop("Use a new label; audit evidence is never overwritten.")
dir.create(out)
mode <- if (length(args) >= 4L) args[4L] else "cran"
stage <- file.path(out, "stamp")
dir.create(stage)
patterns <- readLines(file.path(root, ".Rbuildignore"), warn = FALSE)
entries <- list.files(root, all.files = TRUE, no.. = TRUE)
ignored <- entries %in% c(".git", ".compound-gpid", ".gitignore")
for (pattern in patterns[nzchar(patterns)]) {
  ignored <- ignored | grepl(pattern, entries, ignore.case = TRUE)
}
entries <- entries[!ignored]
stopifnot(all(file.copy(file.path(root, entries), stage, recursive = TRUE,
                       copy.date = TRUE)))
writeLines(entries, file.path(out, "staged-entries.txt"))
# Optional regression overlay: run new assertions against an untouched source.
overlay <- Sys.getenv("STAMP_AUDIT_TEST_OVERLAY")
if (nzchar(overlay)) {
  tests <- file.path(stage, "tests", "testthat")
  unlink(list.files(tests, "^test-.*[.]R$", full.names = TRUE))
  pattern <- Sys.getenv("STAMP_AUDIT_TEST_PATTERN", "^test-audit-io[.]R$")
  fixtures <- c("helper-opts.R", "helper-faults.R", list.files(
    file.path(overlay, "tests", "testthat"), pattern = pattern))
  stopifnot(all(file.copy(file.path(overlay, "tests", "testthat", fixtures),
                         tests, overwrite = TRUE)))
  writeLines(fixtures, file.path(out, "regression-overlay.txt"))
}
capture.output({
  print(sessionInfo())
  print(.libPaths())
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  deps <- paste(description[1L, c("Imports", "Suggests")], collapse = ",")
  deps <- trimws(strsplit(gsub("\\([^)]*\\)", "", deps), ",")[[1L]])
  print(data.frame(package = deps, version = vapply(deps, function(pkg) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      as.character(packageVersion(pkg))
    } else NA_character_
  }, character(1))))
  print(Sys.getenv(c("R_LIBS_USER", "R_LIBS_SITE", "R_PROFILE_USER", "TZ")))
}, file = file.path(out, "environment.txt"))
# R CMD's child sessions must not source the personal startup profile.
Sys.setenv(R_PROFILE_USER = "NUL", R_PROFILE = "NUL",
           R_ENVIRON_USER = "NUL", R_ENVIRON = "NUL",
           R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
           TMPDIR = parent, TMP = parent, TEMP = parent)
if (nzchar(Sys.getenv("RSTUDIO_PANDOC"))) {
  Sys.setenv(PATH = paste(Sys.getenv("RSTUDIO_PANDOC"), Sys.getenv("PATH"),
                         sep = .Platform$path.sep))
}
if (mode == "extended" || startsWith(mode, "shuffle:")) {
  Sys.setenv(NOT_CRAN = "true")
} else {
  Sys.unsetenv("NOT_CRAN")
}
if (startsWith(mode, "shuffle:")) {
  seed <- as.integer(sub("shuffle:", "", mode, fixed = TRUE))
  stopifnot(!is.na(seed))
  set.seed(seed)
  for (file in list.files(file.path(stage, "tests", "testthat"),
                           "^test-.*[.]R$", full.names = TRUE)) {
    expressions <- parse(file)
    cases <- which(vapply(expressions, function(x) {
      is.call(x) && identical(x[[1L]], as.name("test_that"))
    }, logical(1)))
    if (length(cases) > 1L) expressions[cases] <- expressions[sample(cases)]
    writeLines(unlist(lapply(expressions, deparse, width.cutoff = 500L),
                       use.names = FALSE), file)
  }
  test_entry <- file.path(stage, "tests", "testthat.R")
  writeLines(c("library(testthat)", "library(stamp)",
               sprintf("set.seed(%d)", seed),
               "test_check('stamp', shuffle = TRUE)"), test_entry)
  writeLines(as.character(seed), file.path(out, "shuffle-seed.txt"))
}
if (mode == "stage") {
  cat("Staged source:", stage, "\n")
  quit(status = 0L)
}
r <- file.path(R.home("bin"), "R.exe")
if (.Platform$OS.type != "windows") r <- file.path(R.home("bin"), "R")
setwd(out)
run <- function(arguments, name) {
  log <- file.path(out, paste0(name, ".log"))
  writeLines(paste(c(shQuote(r), arguments), collapse = " "),
             file.path(out, paste0(name, "-command.txt")))
  status <- system2(r, arguments, stdout = log, stderr = log)
  writeLines(as.character(status), file.path(out, paste0(name, "-exit.txt")))
  cat(name, "exit:", status, "log:", log, "\n")
  flush.console()
  status
}
fast <- identical(Sys.getenv("STAMP_AUDIT_FAST"), "true")
build_flags <- if (fast) "--no-build-vignettes" else character()
status <- run(c("CMD", "build", build_flags, shQuote(stage)), "build")
if (status != 0L) quit(status = status)
tarball <- list.files(out, "^stamp_.*[.]tar[.]gz$", full.names = TRUE)
stopifnot(length(tarball) == 1L)
writeLines(utils::untar(tarball, list = TRUE), file.path(out, "tarball-contents.txt"))
flags <- if (mode == "cran") "--as-cran" else character()
if (identical(Sys.getenv("STAMP_AUDIT_NO_MANUAL"), "true")) {
  flags <- c(flags, "--no-manual")
}
if (fast) flags <- c(flags, "--no-vignettes", "--no-manual")
status <- run(c("CMD", "check", flags, shQuote(tarball)), "check")
quit(status = status)
