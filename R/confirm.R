#' confirm names of objects match
#'
#' @param ss stamps from stamp
#' @param sh stamps from hash
#' @param verbose logical: whether to display additional information
#'
#' @return invisible TRUE if confirm passes or FALSE otherwise.
#' @keywords internal
confirm_names <- function(ss,
                          sh,
                          verbose = getOption("stamp.verbose")) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # check names   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  pass <- TRUE
  wn <- waldo::compare(names(ss), names(sh))
  if (length(wn)) {
    if (verbose) {
      cli::cli_alert_danger("Names in {.code x} differ from the ones in stamp",
                            wrap = TRUE)
      print(wn)
    }

    pass <- FALSE
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(invisible(pass))

}


#' Confirms if data has changed
#'
#' @inheritParams confirm_names
#'
#' @return invisible TRUE if confirm passes or FALSE otherwise.
#' @keywords internal
confirm_data <- function(ss,
                         sh,
                         verbose = getOption("stamp.verbose")) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Comparing by name  ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  pass <- TRUE
  ns <- names(ss)
  nh <- names(sh)

  if (!is.null(ns) && !is.null(nh)) {

    int <- intersect(ns, nh)
    uni <- union(ns, nh)
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## No intersection --------

    if (length(int) == 0) {
      if (verbose) {
        cli::cli_alert_danger("All names in `x` have changed:
                              Names in x: {.field {nh}}
                              Names in stamps: {.blue {ns}}")
      }
      return(invisible(FALSE))
    }

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## intersection --------
    iss <- ss[int]
    ish <- sh[int]

    wn <- waldo::compare(iss, ish)
    if (length(wn) > 0) {
      if (verbose) {
        cli::cli_alert_danger("Elements in `x` with the same name in stamp are different",
                              wrap = TRUE)
        print(wn)
      }
      pass <- FALSE
    } else {
      if (setequal(int, uni)) {
        pass <- TRUE
      } else {
        if (verbose) {
          cli::cli_alert("Different number of elements, but equal common elements")
        }
        pass <- FALSE
      }
    }

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## differences --------
    if (verbose) {
      dsh <- setdiff(ns, nh)
      dhs <- setdiff(nh, ns)
      if (length(dsh) > 0) {
        cli::cli_alert_warning("In stamp not in `x`: {.field {dsh}}")
      }
      if (length(dhs) > 0) {
        cli::cli_alert_warning("In `x` not in stamp: {.field {dhs}}")
      }
    }

  } else {
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # Comparing by positioin   ---------
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(pass))

}

