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
    ext <- fs::path_ext(file) |>
      check_format(ext = tolower(ext))

    file_dir  <- ensure_file_path(file, recurse)
    file      <- fs::path_ext_remove(file)
    file_name <- fs::path_file(file)

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Stamp file and dir   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    st_name   <- paste0("st_", file_name)

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
#' @param  file_ext character: File extension
#' @inheritParams st_write
#'
#' @return character with extension of desired format
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' fmt <- check_format(file_ext = "fst")
#' fmt
#'}
check_format <- function(file_ext, ext = NULL) {
  # Computations ------------
  file_ext <- tolower(file_ext)
  if (!is.null(ext)) {
    ext      <- tolower(ext)

    if (ext != file_ext) {
      cli::cli_warn("Format provided, {.strong .{ext}}, is different from format in
                    file name, {.strong .{file_ext}}. The former will be used.",
                    wrap = TRUE)
    }
  } else {
    ext <- file_ext
  }

  # check that package is available for this extension
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
#' @keywords internal
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



#' Format Stamp directory
#'
#' @inheritParams stamp_save
#'
#' @return formatted directory
#' @keywords internal
format_st_dir <- function(st_dir = NULL) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # format dir   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # format directory to store stamps
  dir_stamp <- getOption("stamp.dir_stamp")
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## If it NULL --------

    if (is.null(st_dir)) {
      # create in current directory if NULL
      st_dir <-
        fs::path(dir_stamp) |> # curent directory
        fs::dir_create(recurse = TRUE)
    } else {

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ## check if it is a dir --------
      if (!fs::is_dir(st_dir)) {
        msg     <- c(
          "Path {.file {st_dir}} must be a directory")
        cli::cli_abort(msg,
                      class = "stamp_error",
                      wrap = TRUE
                      )
      }

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ## check last dir name --------

      last_dir <- fs::path_file(st_dir)
      if (last_dir != dir_stamp) {
        st_dir <- fs::path(st_dir, dir_stamp)
      }

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ## relative of absolute path --------

      st_dir <-
        if (fs::is_absolute_path(st_dir)) {
          fs::dir_create(st_dir, recurse = TRUE)
        } else {
          fs::path_wd(st_dir) |>
            fs::dir_create(recurse = TRUE)
        }
    }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(st_dir)
}


#' Format Stamp name
#'
#' @inheritParams stamp_save
#' @param st_nm_pr character: `st_name` prefix to save in file. default is value
#'   in option "stamp.stamp_prefix".
#'
#' @return formatted directory
#' @keywords internal
format_st_name <- function(st_name = NULL,
                           st_nm_pr = getOption("stamp.stamp_prefix")) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # format name   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  pattern    <- paste0("^", st_nm_pr)
  if (is.null(st_name)) {
    st_name <-  rand_name()
  }

  if (!grepl(pattern, st_name)) {
    st_name <- paste0(st_nm_pr, st_name)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(st_name)
}



#' Format stamp file
#'
#' @inheritParams stamp_save
#'
#' @return formatted directory
#' @keywords internal
format_st_file <- function(st_dir     = NULL,
                           st_name    = NULL,
                           st_ext     = getOption("stamp.default.ext")) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Defensive setup   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Defenses --------
  stopifnot( exprs = {
    !is.null(st_dir) || !is.null(st_name)
  }
  )


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Early return --------

  if (!is.null(st_dir) && is.null(st_name)) {
    isfile <- fs::is_file(st_dir)
    if (isfile) {
      return(st_dir)
    } else {
      msg     <- c(
        "file {.file {st_dir}} does not exist")
      cli::cli_abort(msg,
                    class = "stamp_error",
                    wrap = TRUE
                    )
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # get sf_file   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## dir and name --------

  st_dir  <- format_st_dir(st_dir)
  st_name <- format_st_name(st_name)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## fix extension --------

  st_name_ext <- fs::path_ext(st_name)
  if (st_name_ext != "") {
    st_ext <- st_name_ext
  }

  pkg_av <- pkg_available(st_ext)
  if (!pkg_av) {
    st_ext <- "rds"
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## create st_file --------

  st_file <- fs::path(st_dir,
                      st_name,
                      ext = st_ext)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(st_file)

}


#' General random name
#'
#' @param l numeric: length of name. Default 8
#'
#' @return random string name
#' @keywords internal
rand_name <- function(l = 8)
  {
  # punct <- c("!",  "#", "$", "%", "&", "(", ")", "*",  "+", "-", "/", ":",
  #            ";", "<", "=", ">", "?", "@", "[", "^", "_", "{", "|", "}", "~")
  nums <- c(0:9)
  # chars <- c(letters, LETTERS, punct, nums)
  chars <- c(letters, nums)
  # p <- c(rep(0.0105, 52), rep(0.0102, 25), rep(0.02, 10))
  pword <- paste0(sample(x = chars,
                         size = l,
                         replace = TRUE),
                  collapse = "")
  return(pword)
}
