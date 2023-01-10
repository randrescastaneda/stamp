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
#' @param verbose logical: whether to display additional information. This could
#'   be changed in option `"stamp.verbose"`. Default is `TRUE`
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
                     ext         = fs::path_ext(file),
                     st_dir      = NULL,
                     attr        = list(),
                     create_dir  = FALSE,
                     force       = FALSE,
                     algo        = getOption("stamp.digest.algo"),
                     vintage     = getOption("stamp.vintage"),
                     vintage_dir = NULL,
                     verbose     = getOption("stamp.verbose"),
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

  # List of paths (lp)
  lp <- path_info(
    file        = file,
    ext         = ext,
    st_dir      = st_dir,
    vintage     = vintage,
    vintage_dir = vintage_dir,
    create_dir  = create_dir
  )

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# add hash   ---------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ## Check if there is a stamp already ----------
  if (fs::file_exists(lp$st_file)) {
    stamp <- qs::qread(lp$st_file)
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

    if (data.table::is.data.table(x)) {
      data.table::setattr(x, "stamp_time", lp$st_time)
    } else {
      attr(x, "stamp_time") <- time
    }

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

