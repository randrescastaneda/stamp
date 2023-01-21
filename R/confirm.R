#' confirm names of objects match
#'
#' @param ss stamps from stamp
#' @param sh stamps from hash
#'
#' @return invisible TRUE if confirm passes or FALSE otherwise.
#' @keywords internal
confirm_names <- function(ss, sh) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # check names   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  wn <- waldo::compare(names(ss), names(sh))
  # wn <- waldo::compare(names(ss), c(names(sh), "H"))
  pass <- TRUE
  if (length(wn)) {
    cli::cli_alert_danger("Names in {.code x} differ from the ones in stamp",
                          wrap = TRUE)
    print(wn)
    pass <- FALSE
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(pass))

}

