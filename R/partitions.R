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
    if (length(m) == 3L) {
      key_name <- m[2]
      key_val <- m[3]

      # Improved type conversion:
      # 1. Check for boolean first (cheap and unambiguous)
      if (key_val %in% c("TRUE", "FALSE")) {
        converted_val <- as.logical(key_val)
      } else {
        # 2. Try numeric conversion
        num_val <- suppressWarnings(as.numeric(key_val))
        if (!is.na(num_val)) {
          # 3. Verify round-trip to avoid "02020" → 2020 issues
          # Use formatC for consistent representation
          roundtrip <- format(num_val, scientific = FALSE, trim = TRUE)
          if (roundtrip == key_val) {
            # 4. Use integer if appropriate (no decimal part)
            if (num_val == as.integer(num_val)) {
              converted_val <- as.integer(num_val)
            } else {
              converted_val <- num_val
            }
          } else {
            # Not a clean numeric round-trip, keep as string
            converted_val <- key_val
          }
        } else {
          # Not numeric at all, keep as string
          converted_val <- key_val
        }
      }

      out[[key_name]] <- converted_val
    }
  }
  out
}

.st_match_filter <- function(key_list, filter_expr = NULL, filter_list = NULL) {
  # Support two filter modes:
  # 1. filter_expr: NSE expression (e.g., quote(year > 2010 & country == "COL"))
  # 2. filter_list: named list for exact matching (backward compat)

  if (is.null(filter_expr) && is.null(filter_list)) {
    return(TRUE)
  }

  # Handle expression-based filtering
  if (!is.null(filter_expr)) {
    # Convert key_list to single-row data.frame for expression evaluation
    # Ensure proper type conversion already happened in .st_parse_key_from_rel
    key_df <- as.data.frame(key_list, stringsAsFactors = FALSE)

    # Evaluate filter expression in context of key_df
    result <- tryCatch(
      {
        eval(filter_expr, envir = key_df, enclos = parent.frame(n = 3))
      },
      error = function(e) {
        # Silently fail for invalid expressions (e.g., missing columns)
        # This allows graceful handling when partition keys don't match filter variables
        FALSE
      }
    )

    # Ensure result is logical and length 1
    if (!is.logical(result) || length(result) != 1L) {
      return(FALSE)
    }

    return(isTRUE(result))
  }

  # Handle named list filtering (exact match, backward compatible)
  if (!is.null(filter_list)) {
    stopifnot(.st_is_named_scalar_list(filter_list))
    for (nm in names(filter_list)) {
      want <- as.character(filter_list[[nm]])
      have <- key_list[[nm]]
      if (is.null(have) || !identical(as.character(have), want)) return(FALSE)
    }
    return(TRUE)
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

#' Auto-partition and save a dataset (Hive-style)
#'
#' Splits a data.frame/data.table by partition columns and saves each partition
#' to a separate file using Hive-style directory structure. Eliminates manual
#' looping and splitting logic.
#'
#' @param x Data.frame or data.table to partition and save
#' @param base Base directory for partitions (e.g., "data/welfare_parts")
#' @param partitioning Character vector of column names to partition by
#'   (e.g., c("country", "year", "reporting_level"))
#' @param code,parents,code_label,format,... Passed to st_save() for each partition
#' @param pk Optional primary key columns (passed to st_save())
#' @param domain Optional domain label(s) (passed to st_save())
#' @param unique Logical; enforce PK uniqueness at save time (default TRUE)
#' @param .progress Logical; show progress bar for partitions (default TRUE for >10 parts)
#'
#' @return Invisibly, a data.frame with columns:
#'   - partition_key: list-column of key values
#'   - path: file path
#'   - version_id: version identifier
#'   - n_rows: number of rows in partition
#'
#' @section Performance:
#' For large datasets with many partitions, this function uses data.table's
#' split for efficiency when available. Progress reporting can be disabled
#' with `.progress = FALSE`.
#'
#' @examples
#' \dontrun{
#' # Create sample data
#' welfare <- data.frame(
#'   country = rep(c("USA", "CAN"), each = 100),
#'   year = rep(2020:2021, each = 50),
#'   reporting_level = sample(c("national", "urban"), 200, replace = TRUE),
#'   value = rnorm(200)
#' )
#'
#' # Auto-partition and save
#' st_write_parts(
#'   welfare,
#'   base = "data/welfare_parts",
#'   partitioning = c("country", "year", "reporting_level"),
#'   code_label = "welfare_partition"
#' )
#'
#' # Result: files saved to:
#' #   data/welfare_parts/country=USA/year=2020/reporting_level=national/part.qs2
#' #   data/welfare_parts/country=USA/year=2020/reporting_level=urban/part.qs2
#' #   ... etc
#' }
#'
#' @export
st_write_parts <- function(
  x,
  base,
  partitioning,
  code = NULL,
  parents = NULL,
  code_label = NULL,
  format = NULL,
  pk = NULL,
  domain = NULL,
  unique = TRUE,
  .progress = NULL,
  ...
) {
  # Validate inputs
  stopifnot(
    is.data.frame(x),
    is.character(base),
    length(base) == 1L,
    is.character(partitioning),
    length(partitioning) >= 1L
  )

  # Check partition columns exist
  missing_cols <- setdiff(partitioning, names(x))
  if (length(missing_cols)) {
    cli::cli_abort(
      "Partitioning columns not found in data: {.field {missing_cols}}"
    )
  }

  # Ensure base directory exists
  fs::dir_create(base)

  # Default to parquet for partitions (optimal for column subsetting)
  format <- format %||% "parquet"

  # Split data by partition columns
  # Use data.table split for efficiency if available
  if (inherits(x, "data.table")) {
    # data.table fast split
    split_list <- split(x, by = partitioning, keep.by = TRUE)
  } else {
    # Base R split (works for data.frame)
    # Create interaction factor for all partition columns
    part_factor <- interaction(
      x[, partitioning, drop = FALSE],
      sep = "|",
      lex.order = TRUE
    )
    split_list <- split(x, part_factor)
  }

  n_parts <- length(split_list)
  if (n_parts == 0L) {
    cli::cli_warn("No partitions created (empty dataset?)")
    return(invisible(data.frame(
      partition_key = list(),
      path = character(),
      version_id = character(),
      n_rows = integer()
    )))
  }

  # Determine if we should show progress
  show_progress <- .progress %||% (n_parts > 10L)

  # Setup progress bar if needed
  if (show_progress) {
    cli::cli_progress_bar(
      "Saving partitions",
      total = n_parts,
      format = "{cli::pb_spin} Saving {cli::pb_current}/{cli::pb_total} partitions [{cli::pb_elapsed}]"
    )
  }

  # Save each partition
  results <- vector("list", n_parts)
  part_names <- names(split_list)

  for (i in seq_len(n_parts)) {
    part_data <- split_list[[i]]
    part_name <- part_names[[i]]

    # Extract partition key values from first row
    # Use ..cols syntax for data.table, otherwise standard subsetting
    if (inherits(part_data, "data.table")) {
      key <- as.list(part_data[1L, ..partitioning])
    } else {
      key <- as.list(part_data[1L, partitioning, drop = FALSE])
    }
    names(key) <- partitioning

    # Save partition
    res <- tryCatch(
      {
        st_save_part(
          x = part_data,
          base = base,
          key = key,
          code = code,
          parents = parents,
          code_label = code_label,
          format = format,
          pk = pk,
          domain = domain,
          unique = unique,
          ...
        )
      },
      error = function(e) {
        cli::cli_warn(
          "Failed to save partition {part_name}: {conditionMessage(e)}"
        )
        NULL
      }
    )

    if (!is.null(res)) {
      results[[i]] <- list(
        partition_key = list(key),
        path = res$path,
        version_id = res$version_id %||% NA_character_,
        n_rows = nrow(part_data)
      )
    }

    if (show_progress) {
      cli::cli_progress_update()
    }
  }

  if (show_progress) {
    cli::cli_progress_done()
  }

  # Filter out failed partitions
  results <- Filter(Negate(is.null), results)

  if (!length(results)) {
    cli::cli_warn("No partitions saved successfully")
    return(invisible(data.frame(
      partition_key = list(),
      path = character(),
      version_id = character(),
      n_rows = integer()
    )))
  }

  # Build manifest data.frame
  manifest <- data.frame(
    partition_key = I(lapply(results, function(r) r$partition_key[[1]])),
    path = vapply(results, function(r) r$path, character(1)),
    version_id = vapply(results, function(r) r$version_id, character(1)),
    n_rows = vapply(results, function(r) r$n_rows, integer(1)),
    stringsAsFactors = FALSE
  )

  cli::cli_inform(c(
    "v" = "Saved {nrow(manifest)} partition{?s} to {.path {base}}"
  ))

  invisible(manifest)
}

#' List available partitions under a base directory
#'
#' @param base Base dir
#' @param filter Partition filter. Supports three formats:
#'   - Named list for exact matching: `list(country = "USA", year = 2020)`
#'   - Formula with expression: `~ year > 2010` or `~ country == "COL" & year >= 2012`
#'   - NULL for no filtering (default)
#' @param recursive Logical; search subdirs (default TRUE)
#' @return A data.frame with columns: path plus one column per partition key
#' @examples
#' \dontrun{
#' # List all partitions
#' st_list_parts("data/parts")
#'
#' # Exact match (backward compatible)
#' st_list_parts("data/parts", filter = list(country = "USA"))
#'
#' # Expression-based (flexible)
#' st_list_parts("data/parts", filter = ~ year > 2010)
#' st_list_parts("data/parts", filter = ~ country == "COL" & year >= 2012)
#' }
#' @export
st_list_parts <- function(base, filter = NULL, recursive = TRUE) {
  stopifnot(is.character(base), length(base) == 1L)

  # Determine filter mode
  filter_expr <- NULL
  filter_list <- NULL

  if (!is.null(filter)) {
    if (inherits(filter, "formula")) {
      # Formula: extract RHS as expression
      filter_expr <- if (length(filter) == 2L) filter[[2L]] else filter[[3L]]
    } else if (is.list(filter) && !is.null(names(filter))) {
      # Named list: exact matching
      filter_list <- filter
    } else {
      cli::cli_abort(c(
        "!" = "Invalid filter argument",
        "i" = "Use named list (e.g., {.code list(year = 2020)}) or formula (e.g., {.code ~ year > 2010})"
      ))
    }
  }

  # Partitions are stored under the root directory (not in .st_data anymore)
  # The directory structure is: root/<base_rel_path>/<partition_path>/<filename>
  # First, find the root directory from current working directory or alias
  # For now, assume base is relative to current directory
  base_abs <- fs::path_abs(base)

  if (!fs::dir_exists(base_abs)) {
    return(data.frame(path = character(), stringsAsFactors = FALSE))
  }

  search_dir <- base_abs

  exts <- unique(.st_known_exts())
  globs <- paste0("*.", exts)

  files <- unlist(
    lapply(globs, function(g) {
      fs::dir_ls(
        search_dir,
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
  inside_versions <- grepl(paste0(sep, "versions", sep), files, fixed = TRUE)
  is_stmeta_file <- grepl("\\.stmeta\\.(json|qs2)$", files)
  is_sidecar <- grepl("sidecar\\.(json|qs2)$", files)
  files <- files[
    !(inside_stmeta | inside_versions | is_stmeta_file | is_sidecar)
  ]

  if (!length(files)) {
    return(data.frame(path = character(), stringsAsFactors = FALSE))
  }

  rows <- lapply(files, function(p) {
    # Files are stored at: root/.st_data/base_rel/partition_path/filename
    # Calculate path relative to search_dir to extract the partition path
    rel <- fs::path_rel(p, start = search_dir)

    key <- .st_parse_key_from_rel(rel)

    # Apply filter
    if (
      !.st_match_filter(
        key,
        filter_expr = filter_expr,
        filter_list = filter_list
      )
    ) {
      return(NULL)
    }

    # Construct the logical path for loading
    # The partition path is now relative to the base directory
    # e.g., if rel = "country=can/year=2021/part.parquet/part.parquet"
    # we want logical path = base + dirname(rel) which gives us the storage dir
    # Actually, for st_load we need just base + the partition hierarchy
    # The rel includes the duplicate filename at the end, so path_dir gives us what we need
    logical_path <- fs::path(base, fs::path_dir(rel))

    c(list(path = as.character(logical_path)), key)
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
#' @param filter Partition filter. Supports three formats:
#'   - Named list for exact matching: `list(country = "USA", year = 2020)`
#'   - Formula with expression: `~ year > 2010` or `~ country == "COL" & year >= 2012`
#'   - NULL for no filtering (default)
#' @param columns Character vector of column names to load (optional).
#'   For parquet/fst formats, uses native column selection (fast, low memory).
#'   For other formats (qs/rds/csv), loads full object then subsets (with warning).
#' @param as Data frame binding mode: "rbind" (base) or "dt" (data.table)
#' @return Data frame with unioned columns and extra columns for the key fields
#' @examples
#' \dontrun{
#' # Load all partitions
#' st_load_parts("data/parts")
#'
#' # Filter with exact match
#' st_load_parts("data/parts", filter = list(country = "USA"))
#'
#' # Filter with expression
#' st_load_parts("data/parts", filter = ~ year > 2010)
#'
#' # Combine filter + column selection
#' st_load_parts("data/parts", filter = ~ year > 2010, columns = c("value", "metric"))
#' }
#' @export
st_load_parts <- function(
  base,
  filter = NULL,
  columns = NULL,
  as = c("rbind", "dt")
) {
  mode <- match.arg(as)

  # Pass filter through to st_list_parts (handles formula/list/NULL)
  listing <- st_list_parts(base, filter = filter, recursive = TRUE)
  if (!nrow(listing)) {
    return(
      if (mode == "dt") {
        data.table::data.table()
      } else {
        data.frame()
      }
    )
  }

  objs <- vector("list", nrow(listing))
  key_cols <- setdiff(names(listing), "path")

  # Track if we've warned about column selection for non-columnar formats
  warned_formats <- character()

  for (i in seq_len(nrow(listing))) {
    p <- listing$path[[i]]

    # Determine format from file extension
    fmt <- tolower(fs::path_ext(p))

    # Load with column selection if supported
    obj <- tryCatch(
      {
        if (!is.null(columns) && length(columns) > 0L) {
          if (fmt == "parquet") {
            # Native column selection for parquet
            if (requireNamespace("nanoparquet", quietly = TRUE)) {
              # nanoparquet uses col_select argument directly
              nanoparquet::read_parquet(p, col_select = columns)
            } else {
              cli::cli_warn(
                "nanoparquet not available; loading all columns from {.file {basename(p)}}"
              )
              st_load(p)
            }
          } else if (fmt == "fst") {
            # Native column selection for fst
            if (requireNamespace("fst", quietly = TRUE)) {
              fst::read_fst(p, columns = columns)
            } else {
              cli::cli_warn(
                "fst not available; loading all columns from {.file {basename(p)}}"
              )
              st_load(p)
            }
          } else {
            # Warn once per format type
            if (!fmt %in% warned_formats) {
              cli::cli_warn(c(
                "!" = "Column selection not supported for {.field {fmt}} format",
                "i" = "Loading full object then subsetting (less efficient)",
                "i" = "Consider using parquet or fst format for columnar loading"
              ))
              warned_formats <<- c(warned_formats, fmt)
            }
            # Load full object then subset
            full_obj <- st_load(p)
            if (inherits(full_obj, "data.frame")) {
              # Keep requested columns that exist
              available_cols <- intersect(columns, names(full_obj))
              if (length(available_cols) > 0L) {
                if (inherits(full_obj, "data.table")) {
                  full_obj[, ..available_cols]
                } else {
                  full_obj[, available_cols, drop = FALSE]
                }
              } else {
                full_obj
              }
            } else {
              full_obj
            }
          }
        } else {
          # No column selection requested
          st_load(p)
        }
      },
      error = function(e) NULL
    )

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
      if (mode == "dt") {
        data.table::data.table()
      } else {
        data.frame()
      }
    )
  }

  if (mode == "dt") {
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
