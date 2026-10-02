# Test helpers ----------------------------------------------------------------

# Snapshot the stamp option store and restore it when the calling frame exits.
#
# `st_opts()` binds into the package's `.stamp_opts` environment, not into base
# `options()`. The `old_opts <- options(); on.exit(options(old_opts))` idiom
# therefore restores nothing, and option changes leak into later tests. This
# helper captures the real store and restores it on exit.
#
# Optional `...` are set after the snapshot is taken, so
# `local_st_opts(default_format = "rds")` both sets and cleans up.
local_st_opts <- function(..., .local_envir = parent.frame()) {
  old <- st_opts(.get = TRUE)
  withr::defer(suppressMessages(do.call(st_opts, old)), envir = .local_envir)
  if (...length()) {
    suppressMessages(st_opts(...))
  }
  invisible(old)
}
