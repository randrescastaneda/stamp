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
#' @param stamp previously calculated stamp with [stamp_get].
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
stamp_set <- function(x       = NULL,
                      st_name = NULL,
                      stamp   = NULL,
                      verbose = getOption("stamp.verbose"),
                      replace = FALSE,
                      ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # defense   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if (is.null(x) && is.null(stamp) ||
      !is.null(x) && !is.null(stamp) ) {
    msg <- c("Either {.field x} or {.field stamp} must be provided")
      cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (is.null(stamp)) {
    hash <- stamp_get(x, ...)
  } else {
    hash <- stamp
  }

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



#' Clean .stamp env
#'
#' @param st_name chracter: stamp name to clean. default is NULL, which cleans
#'   all names
#' @param verbose logica: whether to display additional information.
#'
#' @return invisible TRUE is something was clened. FALSE otherwise
#' @export
#'
#' @examples
#' stamp_clean()
stamp_clean <- function(st_name  = NULL,
                        verbose  = getOption("stamp.verbose")) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # defenses   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  stopifnot({
    length(st_name) == 1 || is.null(st_name)
  })

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # cleaning   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## if it is st_name -------

  if (!is.null(st_name)) {
    if (!env_has(.stamp, st_name)) {
      msg     <- c(
        "stamp {.field {st_name}} does not exist
        make sure it was created with {.code stamp::stamp_set()}")
      cli::cli_alert_info(msg,
                     wrap = TRUE)

      return(invisible(FALSE))

    }

    env_unbind(.stamp, st_name)

    if (env_has(.stamp, st_name)) {
      msg     <- c(
        "Stamp {.field {st_name}} could not be removed")
      cli::cli_abort(msg,
                    class = "stamp_error",
                    wrap = TRUE
                    )
    } else {
      if (verbose) {
        cli::cli_alert_info("Stamp {.field {st_name}} cleaned from
                            environment {.env .stamp}",
                            wrap = TRUE)
      }
      return(invisible(TRUE))
    }


  } else {
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## If it is null --------
    stn <- env_names(.stamp)

    if (length(stn) == 0) {
      cli::cli_alert_info("There is no stamp available in the {.env .stamp}
                          environment... Nothing to clean")
      return(invisible(FALSE))
    } else {
      ff <- lapply(stn, \(.) {
        env_unbind(.stamp, .)
      })

      stn2 <- env_names(.stamp)
      if (!length(stn2) == 0) {
        msg     <- c(
          "Stamp{?s} {.field {stn}} could not be removed")
        cli::cli_abort(msg,
                       class = "stamp_error",
                       wrap = TRUE
        )
      } else {
        if (verbose) {
          cli::cli_alert_info("Environment {.env .stamp} successfully cleaned",
                              wrap = TRUE)
        }
        return(invisible(TRUE))
      }
    }

  }

}



#' Save Stamp in disk
#'
#' @description Create and save in file stamp for future use
#'
#' @param x R object to stamp
#' @param st_dir character: parent directory to store stamp file (see details).
#' @param st_name character: name of stamp in file. All stamp files are prefixed
#'   with value in option "stamp.stamp_prefix", which by default is "st_". You
#'   don't need to add the prefix.
#' @param stamp list of stamp from stamp_get() in case it was calculated before
#'   hand. Developers option. It should be used interactively.
#' @param x_attr logical: whether or not to save the attributes of `x` along
#'   with the stamp. Useful for quick comparisons. Default is FALSE
#' @param st_ext character: format of stamp file to save. Default is value in
#'   option "stamp.default.ext"
#' @param ... other arguments passed to stamp_get()
#' @param verbose logical: Fi TRUE displays information about stamping process.
#' @param stamp_set logical: whether to set stamp in .stamp env, using
#'   `st_name`.
#' @inheritParams stamp_set
#'
#' @return TRUE is saved correctly. FALSE otherwise
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
#' \dontrun{
#'
#' x <- data.frame(a = 1:5,
#' b = letters[1:5])
#'
#' st_dir <- tempdir()
#' st_name <- "xst"
#' stamp_save(x = x,
#' st_dir = st_dir,
#' st_name = st_name)
#'
#'}
stamp_save <- function(x         = NULL,
                       st_dir    = NULL,
                       st_name   = NULL,
                       st_ext    = getOption("stamp.default.ext"),
                       stamp     = NULL,
                       stamp_set = FALSE,
                       replace   = FALSE,
                       x_attr    = FALSE,
                       verbose   = getOption("stamp.verbose"),
                       ...) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # defenses   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  ss_args <- environment() |>
    as.list() |>
    c(list(...))

  do.call("stamp_save_defense", ss_args)


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

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## save stamp --------

  save_stamp <- get_saving_fun(ext = st_ext)
  saved      <- save_stamp(x = stamp_attr, path = st_file)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## set stamp --------

  if (stamp_set) {
    stamp_set(stamp = stamp_attr,
              st_name = st_name,
              replace = replace)
    if (verbose) {
      if (env_has(.stamp, st_name)) {
        cli::cli_alert("Stamp {.blue {st_name}} set in {.env .stamp}")
      }
    }
  }

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


#' Read Stamp in disk
#'
#'
#' @param st_file character: file path to be read
#' @inheritParams stamp_save
#'
#'
#' @return stamp list invisibly
#' @export
#' @family stamp functions
#'
#' @examples
#' \dontrun{
#'
#' x <- data.frame(a = 1:5,
#' b = letters[1:5])
#'
#' st_dir <- tempdir()
#' st_name <- "xst"
#' sv <- stamp_save(x = x,
#' st_dir = st_dir,
#' st_name = st_name)
#'
#' nsv <- names(sv) |>
#'  fs::path()
#'
#' stamp_read(nsv)
#'
#'}
stamp_read <- function(st_file   = NULL,
                       st_dir    = NULL,
                       st_name   = NULL,
                       st_ext    = getOption("stamp.default.ext"),
                       stamp_set = FALSE,
                       replace   = FALSE,
                       verbose   = getOption("stamp.verbose")) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # defenses ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  sr_args <- environment() |>
    as.list()
  do.call("stamp_read_defense", sr_args)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # stamp file   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (!is.null(st_dir)) {
    st_file <- format_st_file(st_dir  = st_dir,
                              st_name = st_name,
                              st_ext  = st_ext)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  st_ext <- fs::path_ext(st_file)

  read_stamp <- get_reading_fun(ext = st_ext)
  stamp      <- read_stamp(st_file)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## set stamp --------

  if (stamp_set) {

    if (is.null(st_name)) {
      st_name <- st_file |>
        fs::path_file() |>
        fs::path_ext_remove()
    }

    stamp_set(stamp = stamp,
              st_name = st_name,
              replace = replace)

    if (verbose) {
      if (env_has(.stamp, st_name)) {
        cli::cli_alert("Stamp {.blue {st_name}} set in {.env .stamp}")
      }
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  invisible(stamp)
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

#'Confirm stamp has not changed
#'
#'@description verifies that, were the stamp recalculated, it would match the
#'  one previously set with stamp_set() of stamp_save().
#'
#'@inheritParams stamp_set
#'@inheritParams st_write
#'@inheritParams stamp_save
#'@inheritDotParams stamp_get
#'@param st_file character: path of stamp file to compare with.
#'@param st_dir character: parent directory where the stamp file if saved.
#'@param st_name character: name of stamp (see details).
#'@param set_hash Logical or character. The hash is the intermediate stamp
#'  estimated to confirm that data has not changed. If FALSE, the default, hash
#'  won't be set as part of the .stamp env. If TRUE, a random name would be
#'  assigned to the hash and it will be saved in .stamp env. If character, it
#'  would be use as the stamp name in .stamp env.
#'@param replace logical: replace hash in .stamp env in case it already exists.
#'  Default is FALSE.
#'
#'@return Logical value. `FALSE` if the objects do not match and  `TRUE` if they
#'  do.
#'@export
#'@family stamp functions
#'
#'@details `st_name` is the name of the stamp and it could be used in two
#'  different ways. First, if `st_dir` is NULL, it is assumed that the user
#'  refers to `st_name` as the stamp saved in the `.stamp` env and not to a
#'  stamp saved in a particular drive. If `st_dir` is not NULL, then `st_name`
#'  is the name of file that contains the stamp. Notice that all stamps that are
#'  saved to disk are prefixed with the value in option "stamp.stamp_prefix",
#'  which by default is "st_". You don't need to add the prefix, but if you do
#'  and it happens to be the same as in "stamp.stamp_prefix", it will be
#'  ignored.
#'
#' @examples
#' \dontrun{
#'   x <- data.frame(a = 1:5, b = "hola")
#'   st_name <- "stx"
#'   stamp_set(x, st_name, replace = TRUE)
#'   # must provide st_dir or st_name
#'   stamp_confirm(x, st_name = st_name)
#'}
stamp_confirm <- function(x,
                          st_dir   = NULL,
                          st_name  = NULL,
                          st_file  = NULL,
                          stamp    = NULL,
                          st_ext   = getOption("stamp.default.ext"),
                          verbose  = getOption("stamp.verbose"),
                          set_hash = FALSE,
                          replace  = FALSE,
                          ...) {
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Defensive setup   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


  sc_args <- environment() |>
    as.list() |>
    {\(.) .[c("st_dir", "st_name", "st_file", "stamp")]}()


  case <- do.call("stamp_confirm_case", sc_args)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  if (case %in% c("st_dir_name", "st_file")) {

    if (case == "st_dir_name") {
      st_file <- format_st_file(st_dir = st_dir,
                                st_name = st_name,
                                st_ext = st_ext)
    }

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

  } else if (case == "st_name") {
    stamp <- stamp_call(st_name)
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # get stamp   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  algo <- stamp$algo
  hash <- stamp_get(x, algo = algo, ...)

  if (!isFALSE(set_hash)) {

    if (isTRUE(set_hash)) {
      hs_name <- rand_name()
    } else {
      hs_name <- set_hash
    }
    stamp_set(stamp = hash,
              st_name = hs_name,
              replace = replace,
              verbose = verbose)
  }


  ss <- stamp$stamps # Original stamps
  sh <- hash$stamps  # New stamps

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # confirm   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cn <- confirm_names(ss, sh)
  cd <- confirm_data(ss, sh)
  unchanged <- any(c(cn, cd))

  if (verbose) {
    st_time <- stamp$time$st_time
    tformat <- stamp$time$tformat
    tz <- stamp$time$tz

    last_change <- as.POSIXct(x = st_time,
                              tz = tz,
                              format = tformat)


    if (unchanged) {
      cli::cli_alert_success("data {.field unchanged} since
                             {.val {last_change}}",
                             wrap = TRUE)
    } else {
      cli::cli_alert_danger("data have {.red changed} since
                            {.val {last_change}}",
                            wrap = TRUE)
    }

  }
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(unchanged))

}



#' Ger confirmation case
#'
#' @inheritParams stamp_set
#' @inheritParams stamp_save
#'
#' @return character of length 1
#' @keywords internal
stamp_confirm_case <- function(st_dir  = NULL,
                               st_name = NULL,
                               st_file = NULL,
                               stamp   = NULL) {

  r1 <- c("i" = "If {.field st_dir} and {.field st_name} are provided,
          {.field st_file} and {.field stamp} must be `NULL`")


  r2 <- c("i" = 'If {.field stamp} is provided,
          arguments {.field  {c("st_file", "st_name", "stamp")}}
          must be `NULL`')

  r3 <- c("i" = 'If you need to confirm with stamp in {.env .stamp} env,
          you have to provide stamp name in {.field st_name} and make sure
          arguments {.field  {c("st_file", "st_dir", "stamp")}} are `NULL')

  r4 <- c("i" = 'If {.field st_file} is provided,
          arguments {.field  {c("st_dir", "st_name", "stamp")}}
          must be `NULL`')


  wl <-
    list(st_dir  = st_dir,
         st_name = st_name,
         st_file = st_file,
         stamp   = stamp) |>
    sapply(\(.) !is.null(.)) |>
    which()

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Error cases --------

  if (!any(c(1, 2, 3, 4) %in% wl)) {
    msg <- c("Syntax error. You must meet the following rules",r1, r2, r3, r4)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if (all(c(1, 2) %in% wl) && any(c(3,4) %in% wl)) {
    msg <- c("Syntax error",r1)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if ((4 %in% wl) && any(c(1, 2, 3) %in% wl)) {
    msg <- c("Syntax error",r2)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }


  if ((2 %in% wl) && any(c(3,4) %in% wl)) {
    msg <- c("Syntax error",r3)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if ((3 %in% wl) && any(c(1,2,4) %in% wl)) {
    msg <- c("Syntax error",r4)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Find work case --------

  if (all(wl == c(1, 2))) {
    case <- "st_dir_name"
  } else if (wl == 3) {
    case <- "st_file"
  } else if (wl == 2) {
    case <- "st_name"
  } else if (wl == 4) {
    case <- "stamp"
  } else {
    msg <- c("Syntax error.",
             "x" = "Argument{?s} {.field {names(wl)}}
             {?can't be provided alone/can't be provided together} ",
             "*" = "You must meet the following rules",
             r1, r2, r3, r4)
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  return(case)

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
    st_x$dim <- dim(x)
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
