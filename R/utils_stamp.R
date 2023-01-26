

#' Format Stamp directory
#'
#' @inheritParams stamp_save
#'
#' @return formatted directory
#' @keywords internal
format_st_dir <- function(st_dir = NULL) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # format dir   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  # format directory to store stamps
  dir_stamp <- getOption("stamp.dir_stamp")
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## If it NULL --------

  if (is.null(st_dir)) {
    # create in current directory if NULL
    st_dir <-
      fs::path(dir_stamp) |> # curent directory
      fs::dir_create(recurse = TRUE)
  } else {


    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## check last dir name --------

    last_dir <- fs::path_file(st_dir)
    if (last_dir != dir_stamp) {
      st_dir <- fs::path(st_dir, dir_stamp)
    }

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    ## relative of absolute path --------

    st_dir <-
      if (fs::is_absolute_path(st_dir)) {
        fs::dir_create(st_dir, recurse = TRUE)
      } else {
        fs::path_wd(st_dir) |>
          fs::dir_create(recurse = TRUE)
      }
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(st_dir)
}


#' Format Stamp name
#'
#' @inheritParams stamp_save
#' @inheritParams rand_name
#' @param st_nm_pr character: `st_name` prefix to save in file. default is value
#'   in option "stamp.stamp_prefix".
#'
#' @return formatted directory
#' @keywords internal
format_st_name <- function(st_name = NULL,
                           st_nm_pr = getOption("stamp.stamp_prefix"),
                           seed     = NULL) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # format name   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  pattern    <- paste0("^", st_nm_pr)
  if (is.null(st_name)) {
    st_name <-  rand_name(seed = seed)
  }

  if (!grepl(pattern, st_name)) {
    st_name <- paste0(st_nm_pr, st_name)
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(st_name)
}



#' Format stamp file
#'
#' @inheritParams stamp_save
#' @inheritParams rand_name
#'
#' @return formatted directory
#' @keywords internal
format_st_file <- function(st_dir     = NULL,
                           st_name    = NULL,
                           st_ext     = getOption("stamp.default.ext"),
                           seed       = NULL) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Defensive setup   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Defenses --------
  stopifnot( exprs = {
    !is.null(st_dir) || !is.null(st_name)
  }
  )


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Early return --------

  if (!is.null(st_dir) && is.null(st_name)) {
    isfile <- fs::is_file(st_dir)
    if (isfile) {
      return(st_dir)
    } else {
      if (fs::is_dir(st_dir)) {
        msg     <- c("{.file {st_dir}} is a directory, not a file",
                     "*" = "If {.field st_name} is not provided,
                     {.blue st_dir} must be a file")
      } else {
        msg     <- c("Directory {.file {st_dir}} does not exist")
      }

      cli::cli_abort(msg,
                     class = "stamp_error",
                     wrap = TRUE
      )
    }
  }


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # get sf_file   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## dir and name --------

  st_dir  <- format_st_dir(st_dir)
  st_name <- format_st_name(st_name, seed = seed)


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## fix extension --------

  st_name_ext <- fs::path_ext(st_name)
  if (st_name_ext != "") {
    st_ext  <- st_name_ext
    st_name <- fs::path_ext_remove(st_name)
  }

  pkg_av <- pkg_available(st_ext)
  if (!pkg_av) {
    st_ext <- "rds"
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## create st_file --------

  st_file <- fs::path(st_dir,
                      st_name,
                      ext = st_ext)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(st_file)

}


#' General random name
#'
#' @param l numeric: length of name. Default 8
#' @param seed numeric: seed for random name. Default is NULL so each time the
#'   the random name generated is the same. Use only for replicability purposes
#'
#' @return random string name
#' @keywords internal
rand_name <- function(seed = NULL,
                      l = 8){
  set.seed(seed)
  # punct <- c("!",  "#", "$", "%", "&", "(", ")", "*",  "+", "-", "/", ":",
  #            ";", "<", "=", ">", "?", "@", "[", "^", "_", "{", "|", "}", "~")
  nums <- c(0:9)
  # chars <- c(letters, LETTERS, punct, nums)
  chars <- c(letters, nums)
  # p <- c(rep(0.0105, 52), rep(0.0102, 25), rep(0.02, 10))
  pword <- paste0(sample(x = chars,
                         size = l,
                         replace = TRUE),
                  collapse = "")
  return(pword)
}



#' defenses of stamp_save
#'
#' @inheritParams  stamp_save
#' @inheritDotParams stamp_get
#' @return Nothing
#' @keywords internal
stamp_save_defense <- function(x        = NULL,
                               st_dir   = NULL,
                               st_name  = NULL,
                               st_ext   = getOption("stamp.default.ext"),
                               stamp    = NULL,
                               x_attr   = TRUE,
                               verbose  = getOption("stamp.verbose"),
                               ...) {

  if (isTRUE(x_attr) && is.null(x)) {
    msg     <- c("{.field x_attr} can't be TRUE while {.field x} is NULL")
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if (is.null(stamp) && is.null(x)) {
    msg     <- c("Either {.field stamp} or {.field x} must be provided")
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }
}

#' defenses of stamp_read
#'
#' @inheritParams  stamp_read
#' @return Nothing
#' @keywords internal
stamp_read_defense <- function(st_file   = NULL,
                               st_dir    = NULL,
                               st_name   = NULL,
                               st_ext    = getOption("stamp.default.ext"),
                               stamp_set = FALSE,
                               replace   = FALSE) {
  if ((is.null(st_file) && is.null(st_dir)) ||
      (!is.null(st_file) && !is.null(st_dir))) {
    msg <- c("Eiher {.field st_file} or {.field st_dir} must be provided")
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if (is.null(st_name) && !is.null(st_dir)) {
    msg <- c("Argument {.field st_name} is required",
             "*" = "Otherwise, ese argument {.field st_file} to specify
             the whole path")
    cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
  }

  if (!is.null(st_file)) {
    if (!fs::is_file(st_file)) {
      msg <- c("Stamp file {.file {st_file}} was not found")
      cli::cli_abort(msg,class = "stamp_error",wrap = TRUE)
    }
  }
}
