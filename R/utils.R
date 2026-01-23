# utils.R — small internal helpers (no global state defined here)

#' Current time as UTC ISO-8601 (Z) string with microsecond precision
#'
#' @return Character scalar like "2025-10-30T15:42:07.123456Z"
#' @keywords internal
.st_now_utc <- function() {
  # ISO 8601 with microsecond precision and trailing 'Z' for UTC
  # %OS6 gives fractional seconds with 6 digits (microseconds)
  # This ensures proper ordering even for versions saved in rapid succession
  format(Sys.time(), "%Y-%m-%dT%H:%M:%OS6Z", tz = "UTC")
}

#' Ensure directory exists (idempotent)
#'
#' Create `path` if it does not already exist. Intermediate directories
#' are created as needed.
#'
#' @param path Character scalar path to a directory.
#' @return Invisibly returns `NULL`.
#' @keywords internal
.st_dir_create <- function(path) {
  if (!fs::dir_exists(path)) {
    fs::dir_create(path, recurse = TRUE)
  }
  invisible(NULL)
}

#' Get the absolute path to the data folder (internal)
#'
#' Returns the absolute path to the data folder for the given alias.
#' The data folder name is configurable via st_opts(data_folder = "...").
#'
#' @param alias Optional alias; if NULL, uses "default"
#' @return Character scalar absolute path to the data folder.
#' @keywords internal
.st_data_folder <- function(alias = NULL) {
  # Get alias configuration
  cfg <- .st_alias_get(alias)
  if (is.null(cfg)) {
    if (is.null(alias) || identical(alias, "default")) {
      cli::cli_abort(c(
        "x" = "No stamp folder initialized.",
        "i" = "Initialize it with {.fn st_init}."
      ))
    } else {
      cli::cli_abort(c(
        "x" = "Alias {.val {alias}} not found.",
        "i" = "Initialize it with {.fn st_init} or use a registered alias."
      ))
    }
  }

  # Get data folder name from options
  data_folder_name <- st_opts("data_folder", .get = TRUE) %||% ".st_data"

  # Return absolute path: <root>/<data_folder_name>
  fs::path(cfg$root, data_folder_name)
}

#' Compute file storage directory in .st_data structure (internal)
#'
#' Given a relative path from alias root, compute the storage directory
#' where the file, versions, and metadata will be stored.
#'
#' Structure: <data_folder>/<rel_path>/
#'
#' Examples:
#'   - rel_path: "data.qs2" → storage: <data_folder>/data.qs2/
#'   - rel_path: "dirA/file.qs" → storage: <data_folder>/dirA/file.qs/
#'
#' @param rel_path Character relative path from alias root (includes filename)
#' @param alias Optional alias
#' @return Character scalar absolute path to the file storage directory
#' @keywords internal
.st_file_storage_dir <- function(rel_path, alias = NULL) {
  data_folder <- .st_data_folder(alias)
  # Storage directory: <data_folder>/<rel_path>/
  fs::path(data_folder, rel_path)
}

#' Compute the actual artifact path in .st_data structure (internal)
#'
#' Returns the path where the actual user file will be stored.
#'
#' Structure: <file_storage_dir>/<filename>
#'
#' @param rel_path Character relative path from alias root
#' @param alias Optional alias
#' @return Character scalar absolute path to the artifact file
#' @keywords internal
.st_artifact_path <- function(rel_path, alias = NULL) {
  storage_dir <- .st_file_storage_dir(rel_path, alias = alias)
  filename <- fs::path_file(rel_path)
  fs::path(storage_dir, filename)
}

#' Extract relative path from an absolute path (internal)
#'
#' Given an absolute path (possibly in .st_data or possibly user's original path),
#' extract the relative path component from alias root.
#'
#' This handles both cases:
#' - Path is in .st_data: extract rel_path from .st_data structure
#' - Path is under root directly: extract rel_path from root
#'
#' @param abs_path Character absolute path
#' @param alias Optional alias
#' @return Character relative path from root, or NULL if path not under root/data_folder
#' @keywords internal
.st_extract_rel_path <- function(abs_path, alias = NULL) {
  cfg <- .st_alias_get(alias)
  if (is.null(cfg)) {
    return(NULL)
  }

  root_abs <- .st_normalize_path(cfg$root)
  path_norm <- .st_normalize_path(abs_path)
  data_folder <- .st_data_folder(alias)
  data_folder_norm <- .st_normalize_path(data_folder)

  # Case 1: Path is in .st_data structure
  data_folder_slash <- if (endsWith(data_folder_norm, "/")) {
    data_folder_norm
  } else {
    paste0(data_folder_norm, "/")
  }

  if (startsWith(path_norm, data_folder_slash)) {
    # Extract relative path from data folder
    # Format: <data_folder>/<rel_path>/<filename>/<filename>
    # or: <data_folder>/<rel_path>/stmeta/...
    # or: <data_folder>/<rel_path>/versions/...

    remainder <- sub(
      paste0(
        "^",
        gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", data_folder_slash)
      ),
      "",
      path_norm
    )

    # Extract the rel_path part (before /stmeta, /versions, or the final duplicate filename)
    # This is tricky - we need to find where the "storage directory" ends

    # Simple heuristic: split by "/" and reconstruct until we hit a special dir or duplicate filename
    parts <- strsplit(remainder, "/")[[1]]
    if (!length(parts)) {
      return(NULL)
    }

    # Find the storage dir path (everything before /stmeta, /versions, or duplicate filename)
    filename <- parts[length(parts)]

    # Check if the path contains our special subdirs or duplicate filename
    special_dirs <- c("stmeta", "versions")

    # Find first occurrence of special dir or where filename repeats
    storage_path_parts <- character()
    for (i in seq_along(parts)) {
      if (parts[i] %in% special_dirs) {
        break
      }
      if (i > 1 && parts[i] == parts[length(parts)] && i == length(parts) - 1) {
        # Duplicate filename at second-to-last position (artifact path case)
        storage_path_parts <- c(storage_path_parts, parts[i])
        break
      }
      storage_path_parts <- c(storage_path_parts, parts[i])
    }

    if (length(storage_path_parts)) {
      return(paste(storage_path_parts, collapse = "/"))
    }
  }

  # Case 2: Path is directly under root (old behavior, for compatibility)
  root_abs_slash <- if (endsWith(root_abs, "/")) {
    root_abs
  } else {
    paste0(root_abs, "/")
  }

  if (identical(path_norm, root_abs)) {
    return(fs::path_file(abs_path))
  }

  if (startsWith(path_norm, root_abs_slash)) {
    return(sub(
      paste0("^", gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root_abs_slash)),
      "",
      path_norm
    ))
  }

  NULL
}

#' Universal path normalization and validation helper (internal)
#'
#' This is the central helper that validates and normalizes any user-provided path.
#' It handles both relative and absolute paths, validates absolute paths are under
#' the alias root, and returns a standardized structure that all other functions can use.
#'
#' **Validation Rules:**
#' - Absolute paths MUST be under the alias root (or raise error)
#' - Absolute paths MUST exist (or raise error)
#' - Relative paths are resolved against alias root
#' - All paths are normalized to absolute form
#'
#' **Return Structure:**
#' - `logical_path`: The user's path relative to root (for catalog, API)
#' - `storage_path`: Physical location in .st_data where file lives
#' - `rel_path`: Relative path from root (same as logical but may differ in format)
#' - `alias`: The alias used
#' - `is_absolute`: Whether user provided absolute path
#'
#' @param user_path Character path provided by user (relative or absolute)
#' @param alias Optional alias; if NULL, uses "default"
#' @param must_exist Logical; if TRUE and user provided absolute path, verify it exists
#' @return List with components: logical_path, storage_path, rel_path, alias, is_absolute
#' @keywords internal
#' @examples
#' \dontrun{
#' # Relative path
#' result <- .st_normalize_user_path("dirA/file.qs")
#' # result$logical_path = "dirA/file.qs"
#' # result$storage_path = "<root>/.st_data/dirA/file.qs/file.qs"
#' # result$rel_path = "dirA/file.qs"
#'
#' # Absolute path
#' result <- .st_normalize_user_path("/full/path/to/root/dirA/file.qs")
#' # Validates it's under root, extracts rel_path = "dirA/file.qs"
#' }
.st_normalize_user_path <- function(
  user_path,
  alias = NULL,
  must_exist = FALSE,
  verbose = TRUE,
  auto_switch = TRUE
) {
  # Input validation
  if (
    !is.character(user_path) ||
      length(user_path) != 1L ||
      is.na(user_path) ||
      !nzchar(user_path)
  ) {
    cli::cli_abort(c(
      "x" = "`user_path` must be a non-missing, non-empty character scalar.",
      "i" = "Provide a single filename or path."
    ))
  }

  # Get alias configuration
  alias_to_use <- alias %||% "default"
  cfg <- .st_alias_get(alias_to_use)

  # If alias is NULL (user didn't specify) and "default" doesn't exist,
  # try to auto-detect from the path
  if (is.null(cfg) && is.null(alias)) {
    # For absolute paths, try detection
    if (fs::is_absolute_path(user_path)) {
      detected_alias <- .st_detect_alias_from_path(.st_normalize_path(
        user_path
      ))
      if (!is.null(detected_alias)) {
        alias_to_use <- detected_alias
        cfg <- .st_alias_get(alias_to_use)
      }
    }
  }

  if (is.null(cfg)) {
    if (is.null(alias) || identical(alias, "default")) {
      cli::cli_abort(c(
        "x" = "No stamp folder initialized.",
        "i" = "Initialize it with {.fn st_init}."
      ))
    } else {
      cli::cli_abort(c(
        "x" = "Alias {.val {alias_to_use}} not found.",
        "i" = "Initialize it with {.fn st_init} or use a registered alias."
      ))
    }
  }

  root_abs <- .st_normalize_path(cfg$root)
  root_abs_slash <- if (endsWith(root_abs, "/")) {
    root_abs
  } else {
    paste0(root_abs, "/")
  }

  # Determine if path is absolute or relative
  is_absolute <- fs::is_absolute_path(user_path)

  if (is_absolute) {
    # **ABSOLUTE PATH HANDLING**

    # Normalize the path
    user_path_norm <- .st_normalize_path(user_path)

    # Check if path is under the specified alias root
    is_under_root <- identical(user_path_norm, root_abs) ||
      startsWith(user_path_norm, root_abs_slash)

    if (!is_under_root) {
      # Path is NOT under the specified alias root
      # Try to find which alias actually owns this path
      actual_alias <- .st_detect_alias_from_path(user_path_norm)

      if (!is.null(actual_alias) && isTRUE(auto_switch)) {
        # We found the owning alias AND auto_switch is enabled
        # Only warn if user explicitly specified a mismatched alias
        # If alias=NULL, silently switch to the detected alias
        actual_cfg <- .st_alias_get(actual_alias)
        if (isTRUE(verbose) && !is.null(alias)) {
          cli::cli_warn(c(
            "!" = "Path {.file {user_path}} is outside the root of alias {.val {alias_to_use}}.",
            "i" = "Alias {.val {alias_to_use}} root: {.file {cfg$root}}",
            "i" = "Path actually located in alias {.val {actual_alias}}.",
            "i" = "Versions will be stored under alias {.val {actual_alias}}."
          ))
        }
        # Use the actual alias configuration instead
        alias_to_use <- actual_alias
        cfg <- actual_cfg
        root_abs <- .st_normalize_path(cfg$root)
        root_abs_slash <- if (endsWith(root_abs, "/")) {
          root_abs
        } else {
          paste0(root_abs, "/")
        }
      } else if (!is.null(actual_alias) && !isTRUE(auto_switch)) {
        # Auto-switch disabled: just continue with mismatched alias
        # This allows querying versions from any alias's catalog
      } else {
        # Path is not under any registered alias - abort
        cli::cli_abort(c(
          "x" = "Absolute path {.file {user_path}} is not under alias root.",
          "i" = "Alias {.val {alias_to_use}} root: {.file {cfg$root}}",
          "i" = "Provide a relative path or an absolute path under the alias root."
        ))
      }
    }

    # Validation 2: Must exist (if required)
    if (isTRUE(must_exist) && !fs::file_exists(user_path)) {
      cli::cli_abort(c(
        "x" = "Absolute path {.file {user_path}} does not exist.",
        "i" = "Provide an existing file path or use a relative path."
      ))
    }

    # Extract relative path from root
    rel_path <- if (identical(user_path_norm, root_abs)) {
      fs::path_file(user_path)
    } else {
      sub(
        paste0(
          "^",
          gsub("([.|()\\^{}+$*?]|\\[|\\])", "\\\\\\1", root_abs_slash)
        ),
        "",
        user_path_norm
      )
    }
  } else {
    # **RELATIVE PATH HANDLING**

    # Relative paths are resolved against alias root
    rel_path <- user_path
  }

  # Compute storage paths in .st_data structure
  storage_dir <- .st_file_storage_dir(rel_path, alias = alias_to_use)
  filename <- fs::path_file(rel_path)
  storage_path <- fs::path(storage_dir, filename)

  # Return standardized structure
  list(
    logical_path = rel_path, # User's path (relative to root) - for catalog
    storage_path = storage_path, # Physical path in .st_data - for file I/O
    rel_path = rel_path, # Relative path from root
    alias = alias_to_use, # Alias used
    is_absolute = is_absolute, # Whether user provided absolute path
    storage_dir = storage_dir # Storage directory (for versions, stmeta)
  )
}
