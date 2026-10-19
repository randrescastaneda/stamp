# Namespace fault injection compatible with the declared testthat 3.1.5 floor.
local_audit_binding <- function(name, value, env = asNamespace("stamp"),
                                .local_envir = parent.frame()) {
  old <- get(name, envir = env, inherits = FALSE)
  locked <- bindingIsLocked(name, env)
  if (locked) unlockBinding(name, env)
  assign(name, value, envir = env)
  if (locked) lockBinding(name, env)
  withr::defer({
    if (bindingIsLocked(name, env)) unlockBinding(name, env)
    assign(name, old, envir = env)
    if (locked) lockBinding(name, env)
  }, envir = .local_envir)
  invisible(old)
}

audit_local_bindings <- function(..., .local_envir = parent.frame()) {
  replacements <- list(...)
  for (name in names(replacements)) {
    local_audit_binding(name, replacements[[name]],
                        .local_envir = .local_envir)
  }
  invisible(NULL)
}
