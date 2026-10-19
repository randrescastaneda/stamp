# Limited save-only pilot. This is not a generic reference-object copier.
.st_reference_copy_for_save <- function(x, fmt, handler) {
  decline <- function(reason) {
    cli::cli_abort(
      "reference_copy_on_save does not support this input: {reason}.",
      class = "stamp_reference_copy_unsupported"
    )
  }

  # Do not silently opt a registered replacement writer into the native pilot.
  native_writer <- .st_wrap_writer(.st_rds_write)
  if (!identical(fmt, "rds") ||
      !is.function(handler$write) ||
      !identical(body(handler$write), body(native_writer)) ||
      !identical(formals(handler$write), formals(native_writer)) ||
      !identical(get0("write_fn", envir = environment(handler$write),
                      inherits = FALSE), .st_rds_write)) {
    decline("only the native RDS writer is supported")
  }

  # Classify only identities obtained from R's registries, never input bindings.
  attached <- search()
  special_envs <- c(
    list(globalenv(), baseenv(), emptyenv()),
    lapply(loadedNamespaces(), getNamespace),
    lapply(attached[startsWith(attached, "package:")], as.environment)
  )
  special <- function(env) {
    any(vapply(special_envs, identical, logical(1), y = env))
  }
  seen <- list()
  nodes <- 0L
  visit <- function(value, depth = 0L, parent_boundary = FALSE) {
    if (is.environment(value) && special(value)) {
      # R serialization preserves these parent identities; never inspect them.
      if (parent_boundary) return(invisible(NULL))
      decline("special environments as roots or binding values")
    }
    if (is.environment(value)) {
      # Serialization may resolve counterfeit namespace/package names to real
      # system environments. Existence checks do not read active/lazy markers.
      if (exists(".__NAMESPACE__.", envir = value, inherits = FALSE)) {
        decline("namespace markers on unrecognized environments")
      }
      name <- attr(value, "name", exact = TRUE)
      if (is.character(name) && any(startsWith(name, "package:"), na.rm = TRUE)) {
        decline("package names on unrecognized environments")
      }
    }
    nodes <<- nodes + 1L
    if (nodes > 10000L || depth > 64L) {
      decline("graph exceeds the 10000-node or 64-level limit")
    }
    if (is.environment(value) &&
        any(vapply(seen, identical, logical(1), y = value))) {
      return(invisible(NULL))
    }
    if (isS4(value) || inherits(value, "connection")) {
      decline("S4 objects or connections")
    }
    attrs <- attributes(value)
    if (is.environment(value)) {
      if (!is.null(attr(value, "class", exact = TRUE))) {
        decline("classed environments (including R6)")
      }
      seen[[length(seen) + 1L]] <<- value
      bindings <- ls(value, all.names = TRUE)
      if (length(bindings) > 10000L - nodes) {
        decline("graph exceeds the 10000-node or 64-level limit")
      }
      # Check the entire frame before retrieving any binding value.
      if (any(vapply(bindings, bindingIsActive, logical(1), env = value))) {
        decline("active bindings")
      }
      if (any(rlang::env_binding_are_lazy(value, bindings))) {
        decline("promise bindings")
      }
      for (name in bindings) {
        visit(get(name, envir = value, inherits = FALSE), depth + 1L)
      }
      visit(parent.env(value), depth + 1L, parent_boundary = TRUE)
    } else if (!typeof(value) %in%
               c("NULL", "logical", "integer", "double", "complex",
                 "character", "raw")) {
      decline("non-atomic binding values")
    }
    # Attributes may contain only simple atomic values, not reference graphs.
    for (attribute in attrs) {
      if (is.environment(attribute)) decline("environment attributes")
      visit(attribute, depth + 1L)
    }
    invisible(NULL)
  }
  visit(x)
  owned <- tryCatch(
    unserialize(serialize(x, connection = NULL, version = 3)),
    error = function(e) decline(paste("serialization failed:",
                                      conditionMessage(e)))
  )
  if (!is.environment(owned) || identical(owned, x) || special(owned)) {
    decline("serialization did not detach the root environment")
  }
  return(owned)
}
