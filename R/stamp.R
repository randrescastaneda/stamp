#' Get stamp
#'
#' @description This is basically a wrapper around [digest::digest()]
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
#'
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
  digest::digest(x, algo = algo)
}


#' Set an attribute *stamp* to R object
#'
#'
#' @inheritDotParams stamp_get
#'
#' @return R object in `x` with attribute *stamp*
#' @export
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


