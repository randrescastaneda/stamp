#' Get stamp
#'
#' @description calculates and displays the hash of the data in memory for all
#' the elements of the first level of `x`. This function is basically a wrapper
#' around [digest::digest()]. It also stores the time of the estimation of the
#' stamp.
#'
#' @inheritParams digest::digest
#'
#' @param x 	An arbitrary R object which will then be passed to the
#'   base::serialize function
#' @param algo character: default is value in option "stamp.digest.algo". This
#'   argument is the algorithms to be used; currently available choices are md5,
#'   which is also the default, sha1, crc32, sha256, sha512, xxhash32, xxhash64,
#'   murmur32, spookyhash and blake3
#'
#' @inherit digest::digest return details
#' @export
#' @family stamp functions
#' @examples
#' stamp_get("abc")
stamp_get <- function(x,
                      algo            = c(
                        getOption("stamp.digest.algo"),
                        "md5",
                        "sha1",
                        "crc32",
                        "sha256",
                        "sha512",
                        "xxhash32",
                        "xxhash64",
                        "murmur32",
                        "spookyhash",
                        "blake3"
                      ),
                      serialize       = TRUE,
                      file            = FALSE,
                      length          = Inf,
                      skip            = "auto",
                      ascii           = FALSE,
                      raw             = FALSE,
                      seed            = 0,
                      errormode       = c("stop", "warn", "silent")) {
  algo <- match.arg(algo)


  ls <- lapply(x, \(.) {
    digest::digest(., algo = algo)
  })
  lt   <- stamp_time()
  return(list(stamps  = ls,
              time    = lt,
              algo    = algo))
}


#' Set an attribute *stamp* to R object
#'
#' @description This functions does the same as stamp_get() but stores the
#' stamps as an attribute in the object. If the object is not saved afterward
#' the stamps won't be permanent. Yet, it is useful for quick verification.
#'
#'
#' @inheritDotParams stamp_get
#' @inheritParams  stamp_get
#'
#' @return R object in `x` with attribute *stamp*
#' @export
#' @family stamp functions
#'
#' @examples
#' x <- data.frame(a = 1:10, b = letters[1:10])
#' stamp_set(x) |> attr(which = "stamp")
stamp_set <- function(x, ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  hash <- stamp_get(x, ...)

  if (data.table::is.data.table(x)) {
    data.table::setattr(x, "stamp", hash)
  } else {
    attr(x, "stamp")      <- hash
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(x)
}

#' Save Stamp in disk
#'
#' @description f
#'
#' @param x R object to stamp
#' @param st_name character: name of stamp in file. All stamp files are prefixed
#'   with value in option "stamp.stamp_prefix", which by default is "_st_".
#' @param st_dir character: parent directory to store stamp file (see details).
#' @param stamp list of stamp from stamp_get() in case it was calculated before
#'   hand. Developers option. It should be used interactively.
#' @param x_attr logical: whether or not to save the attributes of `x` along
#'   with the stamp. Useful for quick comparisons
#' @param ... other arguments passed to stamp_get()
#'
#' @return
#' @export
#' @family stamp functions
#'
#' @details `st_dir` is parent directory. It is inside `st_dir` that {stamp}
#'   creates another subdirectory with name in option "stamp.dir_stamp" and it
#'   is in there where the stamps are saved. The idea objective is to have a
#'   directory for stamps only. By default, `st_dir` is the current directory.
#'   If last directory name of `st_dir` is equal to option "stamp.dir_stamp",
#'   then `st_dir` becomes the stamps directory.
#'
#'   `st_name` must prefixed to avoid overwriting actual data. This is just a
#'   precaution that should not present bumps in any workflow.  If the beginning
#'   of `st_name` is identical to the value in "stamp.stamp_prefix", then it is
#'   adopted as is. Otherwise, the prefix in "stamp.stamp_prefix" will be added
#'   to `st_name`. Be default, `st_name` is random name of 8 characters.
#'
#' @examples
stamp_save <- function(x,
                       st_name,
                       st_dir     = NULL,
                       stamp      = NULL,
                       x_attr     = FALSE,
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
  # Get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (is.null(stamp)) {
    stamp <- stamp_get(x, ...)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Directory and stamp name   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  st_dir <- format_st_dir(st_dir)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(TRUE)

}

#' Get time parameters
#'
#' It uses the values stored in "stamp.timezone", "stamp.timeformat" and
#' "stamp.usetz" options
#'
#' @return list of time parameters as objects
#' @export
#' @family stamp functions
#'
#' @examples
#' stamp_time()
stamp_time <- function() {
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Time parameters   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


  # tz <- "America/Los_Angeles"
  # tformat <- "%Y%m%d%H%M%S"
  l <- list()
  l$tz        <- getOption("stamp.timezone")
  l$tformat   <- getOption("stamp.timeformat")
  l$usetz     <- getOption("stamp.usetz")

  l$st_time <-
    Sys.time() |>
    format(format = l$tformat,
           tz     = l$tz,
           usetz  = l$usetz) |>
    {\(.) gsub('\\s+', '_', .)}()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(l)
}

#' Confirm stamp has not changed
#'
#' @description verifies that, were the stamp recalculated, it would match the
#'   one previously set with stamp_set().
#'
#' @inheritParams stamp_set
#' @inheritParams st_write
#'
#' @return Logical value. `FALSE` if the objects do not match and  `TRUE` if
#'   they do.
#' @export
#' @family stamp functions
#'
#' @examples
stamp_confirm <- function(x,
                          verbose = getOption("stamp.verbose"),
                          using   = c("self", "stamp"),
                          st_dir  = NULL,
                          st_name = NULL,
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
  # Computations   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~






  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(TRUE)

}






#' Add attributes and characteristics of x to stamp file
#'
#' @inheritParams st_write
#' @param hash character: stamp previously calculated. otherwise it will be
#'   added
#'
#' @return list of attributes
#' @export
#' @family stamp functions
#' @examples
#' x <- data.frame(a = 1:10, b = letters[1:10])
#' stamp_attr(x)
stamp_attr <- function(x,
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
