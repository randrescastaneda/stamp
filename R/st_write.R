#' Write R object with corresponding stamp (hash digest)
#'
#' @description The `st_write` function is intended to be a wrapper of several
#'   other functions in different packages that save data disk. Yet, it goes
#'   several steps beyond that. First it creates the stamps (e.g., hashes) as
#'   part of the attributes of the object and saves it in a different file for
#'   easy access. Also, it may create vintage files of the object to keep track
#'   of changes. The philosophy of this package is increase speed in processes
#'   that work with many files, avoiding the need to load files to check whether
#'   the data has changed or not. Since disk space is cheap and time is not,
#'   `stamp` may be redundant in the files it saves.
#'
#' @param x R object to write to disk as per limitations of `file` format.
#' @param file character: File or connection to write to
#' @param ext  character: format or extension of file. Default is
#'   `fs::path_ext(file)`
#' @param st_dir character: Directory to store stamp files. By default it is a
#'   subdirectory at the same level of `file`.
#' @param ... not is used right now
#' @param save_stamp logical: Whether to save a stamp in a separate file.
#'   Default is TRUE. It doesn't make a lot of sense to use [st_write()] when
#'   `save_stamp = FALSE`, as saving data along with the stamp is the main
#'   functionality of [st_write()].
#' @param recurse logical: is `TRUE` if directory in `file` does not it will be
#'   created. Default is FALSE
#' @param force logical: replace file in disk even if has hasn't changed
#' @param algo character: Algorithm to be used in [digest::digest()]. Default is
#'   "sha1"
#' @param vintage logical: Whether to save vintage versions `x`. Default `TRUE`
#' @param vintage_dir character: Directory to save vintages of `x`. By default
#'   it is a subdirectory at the same level of `file`
#' @param verbose logical: whether to display additional information. This could
#'   be changed in option `"stamp.verbose"`. Default is `TRUE`
#' @param complete_stamp logical: Whether to add a complete report of data.frame
#'   to stamp file. You need the `skimr` package. If `skimr` is not in
#'   namespace, limited but lighter report will be added.
#' @inheritParams stamp_save
#' @inheritDotParams stamp_get
#'
#'
#' @details Object `x` is stored in `file` but its hash (i.e., stamp) is stored
#'   in subdirectory `st_file`.
#'
#'   ## Vintage files Vintage files are optional but play an important role for
#'   replicability purposes. We highly recommend you turn this option off if you
#'   don't have enough space in your disk.
#'
#' @return TRUE is object was saved successfully. FALSE otherwise.
#' @export
#'
#' @examples
#' \dontrun{
#'   tfile <- fs::file_temp(ext = "qs")
#'   st_write(df, tfile)
#' }
st_write <- function(x,
                     file,
                     ext            = fs::path_ext(file),
                     st_dir         = NULL,
                     st_name        = NULL,
                     save_stamp     = TRUE,
                     complete_stamp = getOption("stamp.completestamp"),
                     recurse        = FALSE,
                     force          = FALSE,
                     algo           = getOption("stamp.digest.algo"),
                     vintage        = getOption("stamp.vintage"),
                     vintage_dir    = NULL,
                     verbose        = getOption("stamp.verbose"),
                     ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Defenses   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # deal with file and path   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # List of paths (lp)
  lp <- path_info(
    file        = file,
    ext         = ext,
    st_dir      = st_dir,
    st_name     = st_name,
    vintage     = vintage,
    vintage_dir = vintage_dir,
    recurse     = recurse
  )
  saved <- FALSE



  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # add hash   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


  ## Check if there is a stamp already ----------
  ms_status <- ""
  if (fs::file_exists(lp$st_file)) {

    stamp <- stamp_read(lp$st_file)

  } else {
    # if not created before
    stamp <- stamp_get(0, algo = algo,...)
    ms_status <- "new"
  }

  ##  Find proper status  ---------
  # hash <- stamp_get(x, algo = algo,...)

  if (ms_status != "new") {
    sc <- stamp_confirm(x,stamp = stamp,verbose = verbose, ...)
    if (sc) {
      ms_status <- "unchanged"
    } else {
      ms_status <- "changed"
    }
    if (force == TRUE) {
      ms_status <- "forced"
    }
  }

  # if signature changes or force = TRUE ---------

  if (ms_status != "unchanged") {

    ## data.frames only formats  ---------
    complex_df <- check_complex_data(x)
    simple_fmts <- c("fst", "dta", "feather")

    if ((lp$ext %in% simple_fmts) && isTRUE(complex_df)) {
      msg     <- c(
        "Chosen format is not compatipable with object structure",
        "*" = "format {.strong .{lp$ext}} does not support complex data",
        "i" = "Use either {.strong qs} or {.strong rds} format."
        )
      cli::cli_abort(msg,
                    class = "stamp_error",
                    wrap = TRUE
                    )
    }

    ## Get saving function ------------
    save_file <- get_saving_fun(ext = lp$ext)

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Save files   ---------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ## Save main file -----
    saved <-
      save_file(x   = x,
                path = fs::path(lp$file,
                                ext = lp$ext))

    ## save stamp -------
    # stamp_save(x = x)

    ## save vintage --------
    save_file(x    = x,
              path = fs::path(lp$vintage_file,
                              ext = lp$ext))


    # if (verbose) {
    #
    #   infmsg <-
    #     "Data signature {fillintext}
    #     {.file {measure}.{ext}} has been updated"
    #
    #   cli::cli_alert_warning(infmsg)
    # }

    return(invisible(saved))

  } else {
    # if (verbose) {
    #   cli::cli_alert_info("Data signature is up to date.
    #                     {cli::col_blue('No update performed')}")
    # }
    return(invisible(saved))
  }

}

