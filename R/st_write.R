#' Write R object with corresponding stamp (hash digest)
#'
#' @param x R object to write to disk as per limitations of `file` format.
#' @param file character: File or connection to write to
#' @param ext  character: format or extension of file. Default is
#'   `fs::path_ext(file)`
#' @param st_dir character: Directory to store stamp files. By default it is a
#'   subdirectory at the same level of `file`.
#' @param attr list of attributes to store
#' @param ... not is used right now
#' @param create_dir logical: is `TRUE` if directory in `file` does not it will
#'   be created. Default is FALSE
#' @param force logical: replace file in disk even if has hasn't changed
#' @param algo character: Algorithm to be used in [digest::digest()]. Default is
#'   "sha1"
#' @param vintage logical: Whether to save vintage versions `x`. Default `TRUE`
#' @param vintage_dir character: Directory to save vintages of `x`. By default
#'   it is a subdirectory at the same level of `file`
#'
#' @section Details: Object `x` is stored in `file` but its hash (i.e., stamp)
#'   is stored in subdirectory `st_file`.
#'
#' @return TRUE is object was saved successfully. FALSE otherwise.
#' @export
#'
#' @examples
#' \dontrun{
#'   tfile <- file_temp(ext = "qs")
#'   st_write(df, tfile)
#' }
st_write <- function(x,
                     file,
                     ext         = fs::path_ext(file),
                     st_dir      = NULL,
                     attr        = list(),
                     create_dir  = FALSE,
                     force       = FALSE,
                     algo        = "sha1",
                     vintage     = TRUE,
                     vintage_dir = NULL,
                     ...) {

#   ____________________________________________________
#   on.exit                                         ####
  on.exit({

  })

#   ____________________________________________________
#   Defenses and set up   ####
  stopifnot( exprs = {

    }
  )

#   ____________________________________________________
#   Early returns                                   ####
  if (FALSE) {
    return()
  }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# deal with file and path   ---------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  file      <- deal_with_file_path(file, ext, create_dir)
  file_dir  <- fs::path_dir(file)
  file_name <- fs::path_file(file) |>
    fs::path_ext_remove()
  st_name   <- paste0("_st_", file_name)

  # format directory to store stamps
  if (is.null(st_dir)) {
    st_dir <-
      file_dir |>
      fs::path("_st_dir") |>
      fs::dir_create(recurse = TRUE)
  } else {

    if (fs::is_absolute_path(st_dir)) {
      st_dir <- fs::dir_create(st_dir, recurse = TRUE)
    } else {
      st_dir <-
        fs::path_wd(st_dir) |>
        fs::dir_create(recurse = TRUE)
    }
  }

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# add hash   ---------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ## Check if there is a stamp already ----------
  st_file <- fs::path(st_dir, st_name)
  if (fs::file_exists(st_file)) {
    stamp <- qs::qread(st_file)
  } else {
    stamp <- digest::digest(0, algo = algo) # if not created before
  }

  ##  if Signature is different from the one in production ---------
  hash <- digest::digest(x, algo = algo)

  if (hash != stamp) {
    ms_status <- "changed"
  } else {
    ms_status <- "unchanged"
  }

  if (force == TRUE) {
    ms_status <- "forced"
  }

  ## if signature changes or force = TRUE ---------

  if (ms_status %in% c("forced", "changed")) {

    # re-write x in production if data signature is not found
    # Vintage
    time <- format(Sys.time(), "%Y%m%d%H%M%S") # find a way to account for time zones
    attr(x, "datetime") <- time



    if (verbose) {

      infmsg <-
        "Data signature {fillintext}
        {.file {measure}.{ext}} has been updated"

      cli::cli_alert_warning(infmsg)
    }

    return(invisible(TRUE))

  } else {
    if (verbose) {
      cli::cli_alert_info("Data signature is up to date.
                        {cli::col_blue('No update performed')}")
    }


  # Note: clean CPI data file and then create data signature
  # ds_dlw <- digest::digest(x, algo = "xxhash64") # Data signature of file
  #
  # if (ds_dlw != ds_production) {
  #   ms_status <- "changed"
  # } else {
  #   ms_status <- "unchanged"
  # }
  #
  # if (force == TRUE) {
  #   ms_status <- "forced"
  # }


#   ____________________________________________________
#   Return                                           ####
  return(invisible(file))

}
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
    file <-
      fs::path_ext_remove(file) |>
      fs::path(ext = ext)
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


#' Save objects in disk according to desired file
#' @inheritParams st_write
#'
#' @return logical value if it was waved correctly
#' @keywords internal
write <- function(x, file, ext = fs::path_ext(file)) {

  ext <- tolower(ext) |>
    check_format()

  file <- change_file_ext(file, ext)

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

  x_time              <- format(Sys.time(), "%Y%m%d%H%M%S")
  attr(x, "datetime") <- x_time
  # Sys.sleep(.5)

  complex_df <- check_complex_data(x)
  simple_fmts <- c("fst", "dta", "feather")

  if (ext %in% simple_fmts && complex_df) {
    cli::cli_alert_warning("format {.strong .{ext}} does not support complex data,
                           changing to {.strong .Rds} format")
    file <- change_file_ext(file, "rds")
  }



  l_fun <- list()
  save_fun <- get_save_fun(ext = ext)





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


  #   ____________________________________________________________________________
  #   Signatures                                                              ####


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
