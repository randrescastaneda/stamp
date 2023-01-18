#' Get file names and paths
#'
#' @inheritParams st_write
#'
#' @return list of directories and files information
#' @keywords internal
path_info <-
  function(file,
           ext         = fs::path_ext(file),
           st_dir      = NULL,
           vintage     = getOption("stamp.vintage"),
           vintage_dir = NULL,
           recurse     = FALSE
  ) {

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Defensive setup   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## On Exit --------
    on.exit({

    })


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## Defenses --------
    stopifnot( exprs = {

    }
    )

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## Early Return --------
    if (FALSE) {
      return()
    }

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # initial parameters   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # Time parameters
    lt <- stamp_time()

    # stamp parameters
    dir_stamp <- getOption("stamp.dir_stamp")
    dir_vtg   <- getOption("stamp.dir_vintage")


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Main file   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ext <- tolower(ext) |>
      check_format(fs::path_ext(file))

    file_dir  <- ensure_file_path(file, recurse)
    file      <- fs::path_ext_remove(file)
    file_name <- fs::path_file(file)

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Stamp file and dir   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    st_name   <- paste0("_st_", file_name)

    # format directory to store stamps
    st_dir <-
      if (is.null(st_dir)) {
        file_dir |>
          fs::path(dir_stamp) |>
          fs::dir_create(recurse = TRUE)
      } else {
        if (fs::is_absolute_path(st_dir)) {
          fs::dir_create(st_dir, recurse = TRUE)
        } else {
          fs::path_wd(st_dir) |>
            fs::dir_create(recurse = TRUE)
        }
      }

    st_file <- fs::path(st_dir, st_name)
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Vintage file   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    st_time <- lt$st_time

    if (isTRUE(vintage)) {
      vintage_dir <-
        if (is.null(vintage_dir)) {
          file_dir |>
            fs::path(dir_vtg) |>
            fs::dir_create(recurse = TRUE)
        } else {
          if (fs::is_absolute_path(vintage_dir)) {
            fs::dir_create(vintage_dir, recurse = TRUE)
          } else {
            fs::path_wd(vintage_dir) |>
              fs::dir_create(recurse = TRUE)
          }
        }

      vintage_name <- paste0(file_name, "_", st_time )
      vintage_file <- fs::path(vintage_dir, vintage_name)

    } else {
      vintage_name <- NA_character_
      vintage_dir  <- NA_character_
      vintage_file <- NA_character_
    }



    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Return   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    l_path <- list(
      ext          = ext,
      file         = file,
      file_dir     = file_dir,
      file_name    = file_name,
      st_name      = st_name,
      st_dir       = st_dir,
      st_file      = st_file,
      st_time      = st_time,
      vintage_dir  = vintage_dir,
      vintage_name = vintage_name,
      vintage_file = vintage_file
    )
    return(l_path)

  }



#' Check whether the format is in Namespace
#'
#' @description Use valus in `ext` to check the corresponding package is
#'   available. It it is not, it defaults to `Rds`
#'
#' @inheritParams st_write
#' @param  file_ext character: File extension
#'
#' @return character with extension of desired format
#' @export
#'
#' @examples
#' fmt <- check_format(file_ext = "fst")
#' fmt
check_format <- function(ext = "Rds", file_ext) {
  # Computations ------------
  ext <- tolower(ext)

  if (ext != file_ext) {
    cli::cli_warn("Format provided, {.strong .{ext}}, is different from format in
                  file name, {.strong .{file_ext}}. The former will be used.",
                  wrap = TRUE)
  }

  # correctly write file name
  if (ext == "") {
    ext <- getOption("stamp.default.ext") |>
      tolower()
  }

  pkg_av <- pkg_available(ext)
  if (!pkg_av) {
    cli::cli_alert_warning("switching to {.strong .Rds} format")
    ext <- "Rds"
  }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(ext))

}




#' Check whether format is supported and package is available
#'
#' @param ext character: extension of file
#'
#' @return logical vector for availability of package
#' @examples
#' \dontrun{
#' pkg_available("fst")
#'}
pkg_available <- function(ext) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Computations   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  pkg_name <- c("base", "fst", "haven", "qs", "arrow", "arrow")
  formats  <- c("rds", "fst", "dta", "qs", "feather", "parquet")

  fmt <- which(ext %in% formats)
  if (length(fmt) == 0) {
    ofs <- cli::cli_vec(
      formats,
      style = list("vec-last" = " or ")
    )
    msg     <- c(
      "format {.strong .{ext}} is not supported by {.pkg stamp}",
      "i" = "Use any of the following formats: {ofs}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )
  }

  pkg <- pkg_name[fmt]

  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_alert_warning("Package {.pkg {pkg}} is not available in namespace")
    pkg_av <- FALSE
  } else {
    pkg_av <- TRUE
  }

  names(pkg_av) <- pkg


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(pkg_av))

}


#' Check that file format is supported and that package is available
#'
#' @param file character: file path to be read
#'
#' @return invisible TRUE
#' @keywords internal
check_file <- function(file) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Availability   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## File --------

  if (!fs::file_exists(file)) {

    msg     <- c(
      "File {.file {file}} is not available")
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )

  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Package --------

  ext    <- fs::path_ext(file)
  pkg_av <- pkg_available(ext)

  if (!pkg_av) {
    pkg <- names(pkg_av)

    msg     <- c(
      "Package {.pkg {pkg}} is not available to read {.strong {ext}} format",
      "i" = "you can install it by typing {.code install.package('{pkg}')}")
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(invisible(pkg_av))

}
