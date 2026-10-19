# Fresh-process, test-only covr run on a staged package, never on the workspace.
# R --vanilla --slave -f dev/audit-coverage.R --args <stage> <existing-parent>
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L, dir.exists(args[1L]), dir.exists(args[2L]))
root <- normalizePath(args[1L], winslash = "/", mustWork = TRUE)
out <- file.path(normalizePath(args[2L], winslash = "/", mustWork = TRUE),
                 "coverage")
if (dir.exists(out)) stop("Coverage output already exists; use a new parent.")
dir.create(out)
Sys.setenv(R_PROFILE_USER = "NUL", R_PROFILE = "NUL",
           R_ENVIRON_USER = "NUL", R_ENVIRON = "NUL", NOT_CRAN = "true",
           R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
           TMPDIR = dirname(out), TMP = dirname(out), TEMP = dirname(out))
capture.output(sessionInfo(), file = file.path(out, "environment.txt"))
coverage <- covr::package_coverage(path = root, type = "tests", quiet = FALSE,
  clean = FALSE, install_path = file.path(out, "library"))
saveRDS(coverage, file.path(out, "coverage.rds"))
data <- as.data.frame(coverage)
utils::write.csv(data, file.path(out, "expressions.csv"), row.names = FALSE)
files <- gsub("\\\\", "/", data$filename)
files <- sub("^.*?/R/", "R/", files)
lines <- aggregate(data$value, list(file = files, line = data$first_line), sum)
names(lines)[3L] <- "hits"
utils::write.csv(lines, file.path(out, "lines.csv"), row.names = FALSE)
capture.output(print(covr::percent_coverage(coverage)),
               file = file.path(out, "percent.txt"))
cat("Test-only executable-line coverage:", covr::percent_coverage(coverage),
    "\nEvidence:", out, "\n")
