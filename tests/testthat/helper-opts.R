# Test helpers ----------------------------------------------------------------

# covr traces namespace functions after .onLoad captures the native writer.
# Rebuild only this test-process handler from the current canonical functions.
if (identical(Sys.getenv("R_COVR"), "true")) local({
  handler <- get("rds", envir = stamp:::.st_formats_env, inherits = FALSE)
  handler$write <- stamp:::.st_wrap_writer(stamp:::.st_rds_write)
  assign("rds", handler, envir = stamp:::.st_formats_env)
})

# Restore bindings, including removed and newly introduced names, on errors too.
local_stamp_state <- function(.local_envir = parent.frame()) {
  ns <- asNamespace("stamp")
  stores <- lapply(c(
    ".stamp_aliases", ".stamp_state", ".stamp_opts", ".st_builders_env",
    ".st_formats_env", ".st_extmap_env"
  ), get, envir = ns, inherits = FALSE)
  snapshots <- lapply(stores, as.list, all.names = TRUE)
  old_options <- options()
  old_wd <- getwd()
  withr::defer({
    for (i in seq_along(stores)) {
      rm(list = ls(stores[[i]], all.names = TRUE), envir = stores[[i]])
      list2env(snapshots[[i]], envir = stores[[i]])
    }
  }, envir = .local_envir)
  withr::defer({
    added <- setdiff(names(options()), names(old_options))
    if (length(added)) options(setNames(rep(list(NULL), length(added)), added))
    options(old_options)
  }, envir = .local_envir)
  withr::defer(setwd(old_wd), envir = .local_envir)
  invisible(NULL)
}

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

local_alias <- function(name, env = parent.frame()) {
  local_stamp_state(.local_envir = env)
  root <- withr::local_tempdir(.local_envir = env)
  st_init(root, alias = name, verbose = FALSE)
  root
}
