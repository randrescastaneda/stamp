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
    # initialk parameters   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # tz <- "America/Los_Angeles"
    # tformat <- "%Y%m%d%H%M%S"
    tz        <- getOption("stamp.timezone")
    tformat   <- getOption("stamp.timeformat")
    usetz     <- getOption("stamp.usetz")
    dir_stamp <- getOption("stamp.dir_stamp")
    dir_vtg   <- getOption("stamp.dir_vintage")


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Main file   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ext <- tolower(ext) |>
      check_format()

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

    st_time <-
      Sys.time() |>
      format(format = tformat,
             tz     = tz,
             usetz  = usetz) |>
      {\(.) gsub('\\s+', '_', .)}()


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



#' Saving function depending on format selected
#'
#' @inheritParams st_write
#'
#' @return saving function according to `ext`
#' @export
#'
#' @examples
#' # Rds default
#' save_fun <- get_save_fun()
#' save_fun
#'
#' # fst format
#' save_fun <- get_save_fun(ext="fst")
#' save_fun
get_saving_fun <- function(ext = "Rds") {

  # Select function -------------
  ext <- tolower(ext)

  sv <-
    if (ext == "fst") {
      \(x, path, ...) fst::write_fst(x = x, path = path, ...)
    } else if (ext == "dta") {
      \(x, path, ...) haven::write_dta(data = x, path =  path, ...)
    } else if (ext == "qs") {
      \(x, path, ...) qs::qsave(x = x, file = path, ...)
    } else if (ext == "feather") {
      \(x, path, ...) arrow::write_feather(x = x, sink = path, ...)
    } else if (ext == "rds") {
      \(x, path, ...) saveRDS(object = x, file = path, ...)
    } else {
      cli::cli_abort("format {.strong .{ext}} is not available")
    }

  # make sure that data saved properly

  sv2 <- \(x, path, ...) {
    t1 <- Sys.time()
    Sys.sleep(.2)
    sv(x, path, ...)
    saved <- t1 <= file.mtime(path)
    names(saved) <- path
    return(saved)
  }

#   ____________________________________________________
#   Return                                           ####
  return(invisible(sv2))

}



#' Check whether the format is in Namespace
#'
#' @description Use valus in `ext` to check the corresponding package is
#'   available. It it is not, it defaults to `Rds`
#'
#' @inheritParams st_write
#'
#' @return character with extension of desired format
#' @export
#'
#' @examples
#' fmt <- check_format()
#' fmt
check_format <- function(ext = "Rds") {
  # Computations ------------
  ext <- tolower(ext)
  # correctly write file name
  if (ext == "") {
    ext <- getOption("stamp.default.ext")
  }

  pkg_name <- c("base", "fst", "haven", "qs", "arrow", "arrow")
  formats  <- c("rds", "fst", "dta", "qs", "feather", "parquet")

  fmt <- which(ext %in% formats)
  if (length(fmt) == 0) {
    cli::cli_abort("format {.strong .{ext}} is not available")
  }

  pkg <- pkg_name[fmt]

  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_alert_warning("Package {.pkg {pkg}} is not available in namespace,
                           switching to {.strong .Rds} format")
    ext <- "Rds"
  }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(ext))

}


#' Check whther object can be saved in tabular formats like fst
#'
#' @inheritParams st_write
#'
#' @return logical for complex data
#' @export
#'
#' @examples
#' False
#' check_complex_data(data.frame())
#'
#' # TRUE
#' check_complex_data(list())
check_complex_data <- function(x) {


#   ____________________________________________________
#   Computations                                     ####
  if (is.data.frame(x)) {

    complex_df <-
      lapply(x, class) |>  # variables class
      unique() |>
      {\(.) "list" %in% .}()

  } else {
    complex_df <- TRUE
  }

#   ____________________________________________________
#   Return                                           ####
  return(complex_df)

}



#' change file extension to new ext
#'
#' @param file character: current file path with old ext
#' @param ext character: new ext
#'
#' @return character file path
#' @keywords internal
change_file_ext <- function(file, ext) {
  ext  <- tolower(ext)
  oext <- fs::path_ext(file) |>
    tolower()

  if (ext != oext) {
    file <-  file |>
      fs::path_ext_remove() |>
      fs::path(ext = ext)
  }

#   ____________________________________________________
#   Return                                           ####
  return(file)

}



#' Make sure file names and directory paths are working fine
#'
#' @inheritParams st_write
#'
#' @return character vector with file path
#' @keywords internal
ensure_file_path <- function(file, recurse) {

  # Check that dir exists
  file_dir <- fs::path_dir(file)
  if (!fs::dir_exists(file_dir) && recurse == FALSE) {
    msg     <- c(
      "directory {.file {file_dir}} does not exist",
      "i" = "You could use option {.arg recurse = TRUE}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error"
    )
  }
  fs::dir_create(file_dir, recurse = TRUE)


  #   ____________________________________________________
  #   Return                                           ####
  return(file_dir)

}



#' Add attributes and characteristics of x to stamp file
#'
#' @inheritParams st_write
#' @param hash character: stamp previously calculated. otherwise it will be
#'   added
#'
#' @return list of attributes
#' @keywords internal
#'
#' @examples
#' x <- data.frame(a = 1:10, b = letters[1:10])
#' st_attr(x)
st_attr <- function(x,
                    hash = NULL,
                    complete_stamp = getOption("stamp.completestamp"),
                    algo           = getOption("stamp.digest.algo")
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
  # Get basic info from X  ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (is.null(hash)) {
    hash <- digest::digest(x, algo = algo)
  }
  st_x      <- attributes(x)

  if (is.data.frame(x)) {
    if (requireNamespace("skimr", quietly = TRUE) && complete_stamp == TRUE) {
      st_x$skim <- skimr::skim(x)
    } else {
      st_x$dim <- dim(x)
    }
  } else {
    st_x$length <- length(x)
  }

  st_x$stamp <- hash
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(st_x)

}
