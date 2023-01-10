
#' Save objects in disk according to desired file
#' @inheritParams st_write
#' @param lp list of paths returned by `path_info()`
#'
#' @return logical value if it was waved correctly
#' @keywords internal
write <- function(x, lp, ext = fs::path_ext(file)) {

  #   ____________________________________________________
  #   on.exit                                         ####
  on.exit({

  })

  #   ____________________________________________________
  #   Defenses                                        ####
  stopifnot( exprs = {

  }
  )

  #   ____________________________________________________
  #   Early returns                                   ####
  if (FALSE) {
    return()
  }

  #   ____________________________________________________
  #   Computations                                     ####

  ##  Save main file ----------

  ### data.frames only formats  ---------
  complex_df <- check_complex_data(x)
  simple_fmts <- c("fst", "dta", "feather")

  if ((ext %in% simple_fmts) && isTRUE(complex_df)) {
    cli::cli_alert_warning("format {.strong .{ext}} does not support complex data,
                           changing to {.strong .Rds} format")
    file <- change_file_ext(file, "rds")
  }



  l_fun <- list()
  save_file <- get_saving_fun(ext = ext)





  if (ext %in% c("fst", "dta")) {

    var_class <- purrr::map(x, class) # variables class
    if (is.data.frame(x) && !("list"  %in% unique(var_class))) {
      # is_dt <- data.table::is.data.table(x)

      x <- data.frame(a = 1)
      file <-  fs::file_temp(ext = "fst")



      if (ext == "fst")
        fst::write_fst(x = x,
                       path = fs::path(file)
        )

      if (ext == "dta")
        haven::write_dta(data =  x,
                         path = fs::path(file)
        )
    } else {

    }


  } else {



    readr::write_rds(x = x,
                     file = fs::path(msrdir, measure, ext = "rds"))
    ext <- "rds"
  }

  qs::qsave(
    x = x,
    file = fs::path(msrdir, measure, ext = "qs")
  )

  ##  ............................................................................
  ##  Save vintages                                                           ####

  if (is.data.frame(x) && !("list"  %in% unique(var_class))) {
    fst::write_fst(
      x = x,
      path = fs::path(msrdir, "_vintage/",
                      paste0(measure, "_", time),  ext = "fst")
    )

    if (save_dta) {
      haven::write_dta(
        data = x,
        path = fs::path(msrdir, "_vintage/",
                        paste0(measure, "_", time),  ext = "dta"))
    }

  } else {

    readr::write_rds(x = x,
                     file = fs::path(msrdir, "_vintage/",
                                     paste0(measure, "_", time),
                                     ext = "rds"))

  }

  qs::qsave(
    x = x,
    file = fs::path(msrdir, "_vintage/", paste0(measure, "_", time),  ext = "qs")
  )


  #   _______________________________________________________________
  #   Signatures                                                  ####


  ds_text <- c(ds_dlw, time, Sys.info()[8])

  readr::write_lines(
    x = ds_dlw,
    file = ds_production_path
  )


  fillintext <- fcase(ms_status == "new", "was not found",
                      ms_status == "forced", "has been changed forcefully",
                      ms_status == "changed", "has changed",
                      default = "")



  #   ____________________________________________________
  #   Return                                           ####
  return(TRUE)

}




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
           create_dir  = FALSE
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
    # Main file   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ext <- tolower(ext) |>
      check_format()

    file <-
      change_file_ext(file, ext) |>
      deal_with_file_path(ext, create_dir)

    file_dir  <- fs::path_dir(file)
    file_name <- fs::path_file(file) |>
      fs::path_ext_remove()

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Stamp file and dir   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    st_name   <- paste0("_st_", file_name)

    # format directory to store stamps
    st_dir <-
      if (is.null(st_dir)) {
        file_dir |>
          fs::path("_st_dir") |>
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

    # tz <- "America/Los_Angeles"
    # tformat <- "%Y%m%d%H%M%S"
    tz      <- getOption("stamp.timezone")
    tformat <- getOption("stamp.timeformat")
    usetz   <- getOption("stamp.usetz")
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
            fs::path("_st_vintage") |>
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
#   ____________________________________________________
#   Return                                           ####
  return(invisible(sv))

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
deal_with_file_path <- function(file, ext, create_dir) {

  # correctly write file name
  if (ext == "") {
    ext <- getOption("stamp.default.ext")
  } else {
    # check that file ext and ext provided by the user are not different
    o_ext <- fs::path_ext(file)

    if (ext != o_ext) {
      cli::cli_warn("Original extension {.field {o_ext}} is different
                    from the one provided in {.field ext}: {ext}.
                    The ext {ext} provided will be used.")
    }
    file <- change_file_ext(file, ext)
  }

  # Check that dir exists
  file_dir <- fs::path_dir(file)
  if (!fs::dir_exists(file_dir) && create_dir == FALSE) {
    msg     <- c(
      "directory {.file {file_dir}} does not exist",
      "i" = "You could use option {.arg create_dir = TRUE}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error"
    )
  }
  fs::dir_create(file_dir, recurse = TRUE)


  #   ____________________________________________________
  #   Return                                           ####
  return(file)

}

