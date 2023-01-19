#' Get stamp
#'
#' @description This is basically a wrapper around [digest::digest()], which
#'   calculates and displays the signature of the data in memory.
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
  return(list(stamps  = ls,
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
  lt   <- stamp_time()

  if (data.table::is.data.table(x)) {
    data.table::setattr(x, "stamp", hash)
    data.table::setattr(x, "stamp_time", lt$st_time)
  } else {
    attr(x, "stamp")      <- hash
    attr(x, "stamp_time") <- lt$st_time
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(x)
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
