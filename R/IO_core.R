#' stamp: Milestone 1 — I/O core (qs2-first), cli+fs only
#' Depends: cli, fs, jsonlite (and optionally qs2, qs, fst, data.table)
#' Exports: st_init, st_path, st_register_format, st_formats, st_save, st_load

# ---- st_init -----------------------------------------------------------------

#' Initialize stamp project structure
#' @param root project root (default ".")
#' @param state_dir directory name for internal state (default ".stamp")
#' @return (invisibly) the absolute state dir
st_init <- function(root = ".", state_dir = ".stamp") {
  root <- fs::path_abs(root)
  st_state_set(state_dir = state_dir)

  sd <- fs::path(root, state_dir)
  .st_dir_create(sd)
  .st_dir_create(fs::path(sd, "temp"))
  .st_dir_create(fs::path(sd, "logs"))

  cli::cli_inform(c(
    "v" = "stamp initialized",
    " " = paste0("root: ", root),
    " " = paste0("state: ", fs::path_abs(sd))
  ))
  invisible(fs::path_abs(sd))
}

# ---- st_path (S3-ish lightweight) -------------------------------------------

#' Declare a path (with optional format & partition hint)
#' @param path file or directory path
#' @param format optional explicit format ("qs2","rds","csv","fst","json")
#' @param partition_key optional partition key (not used in M1)
#' @return list with class 'st_path'
st_path <- function(path, format = NULL, partition_key = NULL) {
  stopifnot(is.character(path), length(path) == 1L)
  structure(
    list(
      path = path,
      format = format %||% .st_guess_format(path),
      partition_key = partition_key
    ),
    class = "st_path"
  )
}

#' @export
print.st_path <- function(x, ...) {
  cli::cli_inform(paste0("<st_path> ", x$path, " [format=", x$format, "]"))
  invisible(x)
}

.st_guess_format <- function(path) {
  ext <- fs::path_ext(path) |> 
    tolower()
  switch(ext,
    "qs2" = "qs2",
    "qs"  = "qs2",   # treat .qs as qs2 default handler; adapter picks best available
    "rds" = "rds",
    "csv" = "csv",
    "fst" = "fst",
    "json"= "json",
    NULL
  )
}



# ---- st_save (atomic) --------------------------------------------------------

#' Save an R object to disk with sidecar metadata (atomic move)
#' @param x object to save
#' @param file destination path (character or st_path)
#' @param format optional format override ("qs2" | "rds" | "csv" | "fst" | "json")
#' @param metadata named list of extra metadata (stored in sidecar)
#' @param ... forwarded to format writer
#' @return invisibly, a list with path and metadata
st_save <- function(x, file, format = NULL, metadata = list(), ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)
  fmt <- format %||% sp$format %||% "qs2"
  h <- .st_formats_env[[fmt]]
  if (is.null(h)) stop("Unknown format '", fmt, "'. See st_formats() or st_register_format().")

  # ensure parent dir exists
  .st_dir_create(fs::path_dir(sp$path))

  # write to temp in same dir, then move atomically
  tmp <- fs::file_temp(tmp_dir = fs::path_dir(sp$path), pattern = fs::path_file(sp$path))
  h$write(x, tmp, ...)

  # move into place
  if (fs::file_exists(sp$path)) fs::file_delete(sp$path)
  fs::file_move(tmp, sp$path)

  # sidecar metadata (no hashes yet — Milestone 2)
  meta <- c(
    list(
      path        = as.character(sp$path),
      format      = fmt,
      created_at  = .st_now_utc(),
      size_bytes  = unname(fs::file_info(sp$path)$size),
      attrs       = list()  # reserved for stamp internals
    ),
    metadata
  )
  .st_write_sidecar(sp$path, meta)

  cli::cli_inform(c("v" = paste0("Saved [", fmt, "] → ", sp$path)))
  invisible(list(path = sp$path, metadata = meta))
}

# ---- st_load -----------------------------------------------------------------

#' Load an object from disk (format auto-detected by extension or explicit format)
#' @param file path or st_path
#' @param format optional format override
#' @param ... forwarded to format reader
#' @return the loaded object
st_load <- function(file, format = NULL, ...) {
  sp <- if (inherits(file, "st_path")) file else st_path(file, format = format)
  if (!fs::file_exists(sp$path)) stop("File does not exist: ", sp$path)

  fmt <- format %||% sp$format %||% .st_guess_format(sp$path) %||% "qs2"
  h <- .st_formats_env[[fmt]]
  if (is.null(h)) stop("Unknown format '", fmt, "'. See st_formats().")

  res <- h$read(sp$path, ...)
  cli::cli_inform(c("v" = paste0("Loaded [", fmt, "] ← ", sp$path)))
  res
}



# ---- options (rlang) ---------------------------------------------------------

.stamp_opts <- rlang::env(
  meta_format = "json"  # "json" | "qs2" | "both"
)

st_opts <- function(..., .get = FALSE) {
  # setter: st_opts(meta_format = "both")
  # getter: st_opts(.get = TRUE) or st_opts(".single_key", .get=TRUE)
  if (.get) {
    args <- list(...)
    if (length(args) == 0L) {
      return(as.list(.stamp_opts))
    } else if (length(args) == 1L && is.character(args[[1]]) && length(args[[1]]) == 1L) {
      key <- args[[1]]
      return(rlang::env_get(.stamp_opts, key, default = NULL))
    } else {
      stop("For getting, use st_opts(.get = TRUE) or st_opts('key', .get = TRUE).")
    }
  } else {
    dots <- rlang::list2(...)
    if (length(dots) == 0L) return(invisible(NULL))
    # validate meta_format if present
    if ("meta_format" %in% names(dots)) {
      mf <- dots$meta_format
      if (!is.character(mf) || length(mf) != 1L || !mf %in% c("json","qs2","both")) {
        stop("meta_format must be one of 'json', 'qs2', or 'both'.")
      }
    }
    rlang::env_bind(.stamp_opts, !!!dots)
    cli::cli_inform(c("v" = "stamp options updated", " " = paste(names(dots), dots, sep=" = ", collapse=", ")))
    invisible(NULL)
  }
}

