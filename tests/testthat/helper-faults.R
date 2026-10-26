# Namespace fault injection compatible with the declared testthat 3.1.5 floor.
local_audit_binding <- function(name, value, .local_envir = parent.frame()) {
  env <- asNamespace("stamp")
  old <- get(name, envir = env, inherits = FALSE)
  locked <- bindingIsLocked(name, env)
  if (locked) {
    unlockBinding(name, env)
  }
  assign(name, value, envir = env)
  if (locked) {
    lockBinding(name, env)
  }
  withr::defer(
    {
      if (bindingIsLocked(name, env)) {
        unlockBinding(name, env)
      }
      assign(name, old, envir = env)
      if (locked) lockBinding(name, env)
    },
    envir = .local_envir
  )
  invisible(old)
}

audit_local_bindings <- function(..., .local_envir = parent.frame()) {
  replacements <- list(...)
  for (name in names(replacements)) {
    local_audit_binding(name, replacements[[name]], .local_envir = .local_envir)
  }
  invisible(NULL)
}

# Qualified calls need body substitution; a child environment alone cannot mask ::.
audit_local_function <- function(fn, replacements = list(), bindings = list()) {
  replace <- function(expr) {
    if (missing(expr)) {
      return(quote(expr = ))
    }
    for (replacement in replacements) {
      if (identical(expr, replacement[[1L]])) return(replacement[[2L]])
    }
    if (is.call(expr)) {
      return(as.call(lapply(expr, replace)))
    }
    if (is.pairlist(expr)) {
      return(as.pairlist(lapply(expr, replace)))
    }
    expr
  }
  body(fn) <- replace(body(fn))
  environment(fn) <- list2env(bindings, parent = environment(fn))
  fn
}

audit_key_loaders <- function() {
  ns <- asNamespace("stamp")
  loaders <- list2env(
    list(
      setkey = function(...) stop("unexpected key creation"),
      setkeyv = function(x, cols, ...) {
        if (length(cols)) {
          stop("unexpected key sorting")
        }
        data.table::setkeyv(x, cols, ...)
      }
    ),
    parent = ns
  )
  replacements <- list(
    list(quote(data.table::setkey), quote(setkey)),
    list(quote(data.table::setkeyv), quote(setkeyv))
  )
  # Copy the full stamp call graph so catalog reads have the same guards as loads.
  for (name in ls(ns, all.names = TRUE)) {
    fn <- get(name, envir = ns, inherits = FALSE)
    if (!is.function(fn) || !identical(environment(fn), ns)) {
      next
    }
    fn <- audit_local_function(fn, replacements)
    environment(fn) <- loaders
    assign(name, fn, envir = loaders)
  }
  loaders
}
