# R/partitions.R
# ---- Partitioned artifacts (Hive-style dirs) ---------------------------------
# Layout: <base>/<k1>=<v1>/<k2>=<v2>/part.<ext> (+ sidecars)
# Ext defaults to stamp's default format (e.g., qs2).

# ---- Small helpers -----------------------------------------------------------

.st_is_named_scalar_list <- function(x) {
  is.list(x) &&
    !is.null(names(x)) &&
    all(nzchar(names(x))) &&
    all(vapply(
      x,
      function(z) length(z) == 1L && (is.atomic(z) || is.factor(z)),
      logical(1)
    ))
}

.st_key_normalize <- function(key) {
  stopifnot(.st_is_named_scalar_list(key))
  # stringify + basic sanitation (no "/" or "=" in values)
  v <- vapply(
    key,
    function(z) {
      s <- as.character(z)
      if (length(s) != 1L) {
        stop("Partition values must be length-1.")
      }
      if (grepl("/", s, fixed = TRUE) || grepl("=", s, fixed = TRUE)) {
        cli::cli_abort("Partition values cannot contain '/' or '=': {s}")
      }
      s
    },
    character(1)
  )
  # stable ordering by name for determinism
  v[order(names(v))]
}

.st_key_segments <- function(key) {
  kn <- .st_key_normalize(key)
  paste0(names(kn), "=", unname(kn))
}

.st_known_exts <- function() {
  # Real file extensions we know how to read (ext -> format map),
  # plus any formats that happen to equal an extension name (rds, csv, json, fst, qs2)
  c(
    names(as.list(.st_extmap_env)),
    names(as.list(.st_formats_env))
  )
}


.st_guess_or_default_format <- function(path = NULL, format = NULL) {
  fmt <- format %||%
    (if (!is.null(path)) .st_guess_format(path) else NULL) %||%
    st_opts("default_format", .get = TRUE)
  if (is.null(fmt) || !nzchar(fmt)) {
    cli::cli_abort("No format available; set st_opts(default_format=...).")
  }
  fmt
}

.st_file_basename_default <- function(fmt) sprintf("part.%s", fmt)

.st_parse_key_from_rel <- function(rel) {
  # rel is a relative path like "k1=v1/k2=v2/part.qs2"
  segs <- fs::path_split(fs::path_dir(rel))[[1]]
  kv <- segs[nzchar(segs)]
  out <- list()
  if (!length(kv)) {
    return(out)
  }
  for (s in kv) {
    m <- regmatches(s, regexec("^([^=]+)=(.*)$", s))[[1]]
    if (length(m) == 3L) out[[m[2]]] <- m[3]
  }
  out
}

.st_match_filter <- function(key_list, filter) {
  # filter: named list of exact matches; return TRUE if all present & equal
  if (is.null(filter) || !length(filter)) {
    return(TRUE)
  }
  stopifnot(.st_is_named_scalar_list(filter))
  for (nm in names(filter)) {
    want <- as.character(filter[[nm]])
    have <- key_list[[nm]]
    if (is.null(have) || !identical(as.character(have), want)) return(FALSE)
  }
  TRUE
}

# ---- Public API --------------------------------------------------------------

#' Build a concrete partition path under a base directory
#'
#' @param base Character base directory (e.g., "data/users")
#' @param key  Named list of scalar values, e.g. list(country="US", year=2025)
#' @param file Optional filename (default "part.<ext>")
#' @param format Optional format (qs2|rds|csv|fst|json); default = stamp option
#' @return Character file path to the partition artifact
#' @export
st_part_path <- function(base, key, file = NULL, format = NULL) {
  stopifnot(is.character(base), length(base) == 1L)
  segs <- .st_key_segments(key)
  fmt <- .st_guess_or_default_format(format = format)
  fname <- file %||% .st_file_basename_default(fmt)
  fs::path(base, fs::path_join(segs), fname)
}

#' Save a single partition (uses st_save under the hood)
#'
#' @param x Object to save
#' @param base Base dir for partitions
#' @param key  Named list of scalar values (e.g., list(country="US", year=2025))
#' @param code,parents,code_label,format,... Passed to st_save()
#' @return invisibly, list(path=..., version_id=...)
#' @export
st_save_part <- function(
  x,
  base,
  key,
  code = NULL,
  parents = NULL,
  code_label = NULL,
  format = NULL,
  ...
) {
  path <- st_part_path(base, key, format = format)
  out <- st_save(
    x,
    path,
    format = format,
    code = code,
    parents = parents,
    code_label = code_label,
    ...
  )
  invisible(list(path = path, version_id = out$version_id))
}

#' List available partitions under a base directory
#'
#' @param base Base dir
#' @param filter Named list to restrict partitions (exact match on key fields)
#' @param recursive Logical; search subdirs (default TRUE)
#' @return A data.frame with columns: path, <key columns...>
#' @export
st_list_parts <- function(base, filter = NULL, recursive = TRUE) {
  stopifnot(is.character(base), length(base) == 1L)
  if (!fs::dir_exists(base)) {
    return(data.frame(path = character(), stringsAsFactors = FALSE))
  }

  exts <- unique(.st_known_exts())
  globs <- paste0("*.", exts)

  files <- unlist(
    lapply(globs, function(g) {
      fs::dir_ls(
        base,
        recurse = recursive,
        glob = g,
        type = "file",
        fail = FALSE
      )
    }),
    use.names = FALSE
  )
  files <- unique(files)

  sep <- .Platform$file.sep
  inside_stmeta <- grepl(paste0(sep, "stmeta", sep), files, fixed = TRUE)
  is_sidecar <- grepl("\\.stmeta\\.(json|qs2)$", files)
  files <- files[!(inside_stmeta | is_sidecar)]

  if (!length(files)) {
    return(data.frame(path = character(), stringsAsFactors = FALSE))
  }

  rows <- lapply(files, function(p) {
    rel <- fs::path_rel(p, start = base)
    key <- .st_parse_key_from_rel(rel)
    if (!.st_match_filter(key, filter)) {
      return(NULL)
    }
    c(list(path = as.character(p)), key)
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(data.frame(path = character(), stringsAsFactors = FALSE))
  }

  all_keys <- unique(unlist(lapply(rows, names)))
  all_keys <- setdiff(all_keys, "path")
  df <- data.frame(
    path = vapply(rows, function(r) r[["path"]], character(1)),
    stringsAsFactors = FALSE
  )
  for (k in all_keys) {
    df[[k]] <- vapply(
      rows,
      function(r) as.character(r[[k]] %||% NA_character_),
      character(1)
    )
  }
  df[order(df$path), , drop = FALSE]
}


#' Load and row-bind partitioned data
#'
#' @param base Base dir
#' @param filter Named list to restrict partitions (exact match)
#' @param as Data frame binding mode: "rbind" (base) or "dt" (data.table if available)
#' @return Data frame with unioned columns and extra columns for the key fields
#' @export
st_load_parts <- function(base, filter = NULL, as = c("rbind", "dt")) {
  mode <- match.arg(as)
  listing <- st_list_parts(base, filter = filter, recursive = TRUE)
  if (!nrow(listing)) {
    return(
      if (mode == "dt" && requireNamespace("data.table", quietly = TRUE)) {
        data.table::data.table()
      } else {
        data.frame()
      }
    )
  }

  objs <- vector("list", nrow(listing))
  key_cols <- setdiff(names(listing), "path")

  for (i in seq_len(nrow(listing))) {
    p <- listing$path[[i]]
    obj <- tryCatch(st_load(p), error = function(e) NULL)
    if (is.null(obj)) {
      next
    }

    if (inherits(obj, "data.frame")) {
      # table case: just tack on key columns
      for (k in key_cols) {
        obj[[k]] <- listing[[k]][[i]]
      }
    } else {
      tmp <- data.frame(.object = I(list(obj)), stringsAsFactors = FALSE)
      for (k in key_cols) {
        tmp[[k]] <- listing[[k]][[i]]
      }
      obj <- tmp
    }
    objs[[i]] <- obj
  }

  objs <- Filter(Negate(is.null), objs)
  if (!length(objs)) {
    return(
      if (mode == "dt" && requireNamespace("data.table", quietly = TRUE)) {
        data.table::data.table()
      } else {
        data.frame()
      }
    )
  }

  if (mode == "dt" && requireNamespace("data.table", quietly = TRUE)) {
    return(data.table::rbindlist(objs, use.names = TRUE, fill = TRUE))
  }

  Reduce(
    function(a, b) {
      cols <- union(names(a), names(b))
      a[setdiff(cols, names(a))] <- NA
      b[setdiff(cols, names(b))] <- NA
      a <- a[, cols, drop = FALSE]
      b <- b[, cols, drop = FALSE]
      rbind(a, b)
    },
    objs
  )
}
