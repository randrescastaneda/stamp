#' Read files with Stamp
#'
#' @param file character: file path to be read.
#' @param  vintage An integer or a quoted directive. "available": displays list
#'   of available versions for `measure`. "select"|"pick"|"choose": allows user
#'   to select the vintage of `measure`. if the integer is a zero or a negative
#'   number (e.g., `-1`), `pip_load_aux` will load that number of versions
#'   before the most recent version available. So, if `0`, it loads the current
#'   version. If `-1`, it will load the version before the current, `-2` loads
#'   two versions before the current one, and so on. If it is a positive number,
#'   it must be quoted (as character) and in the form "%Y%m%d%H%M%S". If "00",
#'   it load the most recent version of the data (similar to `version = 0` or
#'   `version = NULL` or `version = "0"`). The difference is that `"00"` load
#'   the most recent version of the vintage folder, rather than the current
#'   version in the dynamic folder. Thus, attribute "version" in `attr(dd,
#'   "version")` is the actual version of the most recent vintage of the file
#'   rather that `attr(dd, "version")` equal to "current", which is the default.
#'   Option "00" is useful for vintage control
#' @inheritParams st_write
#'
#' @return
#' @export
#'
#' @examples
st_read <- function(file,
                    st_dir         = NULL,
                    vintage        = NULL,
                    vintage_dir    = NULL,
                    verbose        = getOption("stamp.verbose"),
                    ...) {

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
  # Check directories and files---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Main file  --------

  check_file(file = file)

  ext <- file |>
    fs::path_ext() |>
    tolower()


  # List of paths (lp)
  lp <- path_info(
    file        = file,
    ext         = ext,
    st_dir      = st_dir,
    vintage     = vintage,
    vintage_dir = vintage_dir,
    recurse     = FALSE
  )


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # getting reading function   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  lp$st_ext <- getOption("stamp.default.ext")

  read_file  <- get_reading_fun(ext)
  read_stamp <- get_reading_fun(lp$st_ext)





  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(TRUE)

}
