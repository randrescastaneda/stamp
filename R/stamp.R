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

  if (is.list(x)) {
    ls <- lapply(x, \(.) {
      digest::digest(., algo = algo)
    })
  } else  {
    ls <- list()
    ls[[1]] <- digest::digest(x, algo = algo)
  }

  lt   <- stamp_time()

  return(list(stamps  = ls,
              time    = lt,
              algo    = algo))
}


#' Set and call stamps from `.stamp` environment
#'
#' @description `stamp_set()` makes use of `stamp_get()` and stores the stamp
#'   into the `.stamp` environment, which can be accesses via `stamp_call()` or
#'   `stamp_env()`. `stamp_call()`  retrieves one single stamp. `stamp_env()`
#'   display all the stamps available in the `.stamp` env.
#'
#' @rdname set-call
#' @order 1
#'
#' @inheritParams  stamp_get
#' @inheritParams  st_write
#' @param st_name character: Name of stamp to be set or called in .stamp env.
#' @param replace Logical: if TRUE and `st_name` already exists in `.stamp`
#'   environment, it will be replaced with new stamp. If `FALSE` it gives an
#'   error. Default is `FALSE`
#' @param ... arguments passed on to [stamp_get()]
#'
#' @return invisible stamp from stamp_get() but it can now be called with
#'   stamp_call()
#' @export
#' @family stamp functions
#'
#' @examples
#' stamp_env()
#' x <- data.frame(a = 1:10, b = letters[1:10])
#' stamp_set(x, st_name = "xts")
#' stamp_call("xts")
#'
#' y <- data.frame(a = 5:10, b = letters[5:10])
#' stamp_set(y, st_name = "yts")
#' stamp_env()
stamp_set <- function(x,
                      st_name = NULL,
                      verbose = getOption("stamp.verbose"),
                      replace = FALSE,
                      ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  hash <- stamp_get(x, ...)

  st_name <- format_st_name(st_name,
                            st_nm_pr = "") |>
    make.names(unique = TRUE)

  if (!env_has(.stamp, st_name) || isTRUE(replace)) {
    env_poke(.stamp, st_name, hash)
  } else {
    msg     <- c(
      "*" = "stamp {.field {st_name}} already exists in environment
      {.env .stamp}",
      "i" = "change name of stamp in {.field st_name} or use option
      {.code replace = TRUE}"
      )
    cli::cli_abort(msg,
                  class = "stamp_error",
                  wrap = TRUE
                  )
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(hash))
}



#' Call stamps in memory
#'
#' @rdname set-call
#' @order 2
#'
#' @return list with stamp values
#' @export
stamp_call <- function(st_name) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Call stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (env_has(.stamp, st_name)) {

    return(env_get(.stamp, st_name))

  } else {
    msg     <- c(
      "*" = "stamp {.field {st_name}} does not exist",
      "i" = "make sure it was created with {.code stamp::stamp_set()}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE)
  }

}


#' Display stamps available
#'
#' @rdname set-call
#' @order 3
#'
#' @return names of stamps available in .stamp env. If no stamp is available, it
#'   returns an invisible character vector of length 0.
#' @export
stamp_env <- function(verbose = getOption("stamp.verbose")) {
  st_name <- env_names(.stamp)

  if (verbose) {
    if (length(st_name) == 0) {
      cli::cli_alert_info("no stamps in {.env .stamp} environment")
      return(invisible(st_name))
    }
  }
  return(st_name)
}

#' Save Stamp in disk
#'
#' @description
#' Create and save in file stamp for future use
#'
#' @param x R object to stamp
#' @param st_dir character: parent directory to store stamp file (see details).
#' @param st_name character: name of stamp in file. All stamp files are prefixed
#'   with value in option "stamp.stamp_prefix", which by default is "_st_".
#'   You don't need to add the prefix.
#' @param stamp list of stamp from stamp_get() in case it was calculated before
#'   hand. Developers option. It should be used interactively.
#' @param x_attr logical: whether or not to save the attributes of `x` along
#'   with the stamp. Useful for quick comparisons
#' @param st_ext character: format of stamp file to save. Default is value in
#'   option "stamp.default.ext"
#' @param ... other arguments passed to stamp_get()
#' @param verbose logical: Fi TRUE displays information about stamping process.
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
#'   to `st_name`. If NULL, `st_name` would be a random name of 8 characters.
#'
#' @examples
stamp_save <- function(x,
                       st_dir     = NULL,
                       st_name    = NULL,
                       st_ext     = getOption("stamp.default.ext"),
                       stamp      = NULL,
                       x_attr     = TRUE,
                       verbose    = getOption("stamp.verbose"),
                       ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (is.null(stamp)) {
    stamp <- stamp_get(x, ...)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Directory and stamp name   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  st_file <- format_st_file(st_dir = st_dir,
                            st_name = st_name,
                            st_ext = st_ext)
  st_ext <- fs::path_ext(st_file)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # X attributes   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (x_attr) {
    st_xattr <- stamp_x_attr(x)
  } else {
    st_xattr <- NULL
  }

  stamp_attr <- append(stamp, list(x_attr = st_xattr))


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Save   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  save_stamp <- get_saving_fun(ext = st_ext)

  saved <- save_stamp(x = stamp_attr, path = st_file)

  if (verbose) {
    if (saved) {
      cli::cli_alert_success("stamp file {.file {st_file}} has been saved
                             successfully",
                             wrap =  TRUE)
    } else {
      cli::cli_alert_danger("stamp file {.file {st_file}} could {.red NOT}
                            been saved",
                             wrap =  TRUE)
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  invisible(saved)
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
#'   one previously set with stamp_set() of stamp_save().
#'
#' @inheritParams stamp_set
#' @inheritParams st_write
#' @inheritParams stamp_save
#' @inheritDotParams stamp_get
#' @param st_dir character: parent directory where the stamp file if saved.
#' @param st_name character: name of stamp in file. All stamp files are prefixed
#'   with the value in option "stamp.stamp_prefix", which by default is "_st_".
#'   You don't need to add the prefix
#' @param  using character: either "self" of "stamp" (see details).
#'
#' @return Logical value. `FALSE` if the objects do not match and  `TRUE` if
#'   they do.
#' @export
#' @family stamp functions
#'
#' @details `using` If "self" verifies that stamp has not changed by
#' recalculating it and comparing with the one previously set `x`. If no stamp
#' has been set in `x`, it yields error. If "stamp", you must provide a `st_dir`
#' and a `st_name`, which correspond to the stamp in file to compare with. If
#' only `st_dir` is provided, it is assumes to contain the name of the file as
#' well. Otherwise, error is yield.
#'
#' @examples
stamp_confirm <- function(x,
                          using   = c("self", "stamp"),
                          st_dir  = NULL,
                          st_name = NULL,
                          st_ext  = getOption("stamp.default.ext"),
                          verbose = getOption("stamp.verbose"),
                          ...) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  using <- match.arg(using)
  if (using == "self") {

    stamp <- attr(x, "stamp")
    if (is.null(stamp)) {
      msg     <- c(
        "{.field stamp} attribute not found in {.code x}",
        "i" = "create stamp attribute with {.code stamp::stamp_set(x)}",
        "i" = 'confirm attribute has been created with {.code attr(x, "stamp")}'
        )
      cli::cli_abort(msg,
                    class = "stamp_error",
                    wrap = TRUE
                    )
    }

  } else {

    st_file <- format_st_file(st_dir = st_dir,
                              st_name = st_name,
                              st_ext = st_ext)
    st_ext <- fs::path_ext(st_file)

    if (!fs::file_exists(st_file)) {
      msg     <- c(
        "File {.file {st_file}} does not exist",
        "*" = "make sure it was created with {.code stamp::stamp_save()} or
        {.code stamp::st_write()}")
      cli::cli_abort(msg,
                    class = "stamp_error",
                    wrap = TRUE
                    )
    }

    read_stamp <- get_reading_fun(st_ext)
    stamp      <- read_stamp(st_file)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  algo <- stamp$algo
  hash <- stamp_get(x, algo = algo, ...)

  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # confirm   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## names --------
  cn <- confirm_names(ss, sh)






  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(TRUE)

}



#' Add attributes and characteristics of x to be used in stamp
#'
#' In addition to the information from [stamp_set], [stamp_x_attr] generates
#' information about the attributes of the R object, including basic descriptive
#' stats.
#'
#' @inheritParams st_write
#'
#' @return list of attributes
#' @export
#' @family stamp functions
#' @examples
#' x <- data.frame(a = 1:10, b = letters[1:10])
#' stamp_x_attr(x)
stamp_x_attr <- function(x) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Get basic info from X  ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  st_x      <- attributes(x)

  if (is.data.frame(x)) {
    if (requireNamespace("skimr", quietly = TRUE)) {
      st_x$skim <- skimr::skim(x)
    } else {
      st_x$summary <- summary(x)
    }
  } else {
    st_x$length <- length(x)
  }
  st_x$type  <- typeof(x)
  st_x$class <- class(x)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(st_x)

}
