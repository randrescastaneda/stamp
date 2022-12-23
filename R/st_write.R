#' Write R object with corresponding stamp (hash digest)
#'
#' @param x R object to write to disk as per limitations of `file` format.
#' @param file character: File or connection to write to
#' @param ext  character: format or extension of file. Default is
#'   `fs::path_ext(file)`
#' @param st_dir character: Directory to store stamp files. By default it is a
#'   subdirectory at the same level of `file`.
#' @param attr list of attributes to store
#' @param ... not is used right now
#'
#' @section Details: Object `x` is stored in `file` but its hash (i.e., stamp)
#'   is stored in subdirectory `st_file`.
#'
#'
#'
#'
#'
#' @return TRUE is object was saved successfully. FALSE otherwise.
#' @export
#'
#' @examples
st_write <- function(x,
                     file,
                     ext        = fs::path_ext(file),
                     st_dir     = NULL,
                     attr       = list(),
                     create_dir = FALSE,
                     ...) {

#   ____________________________________________________
#   on.exit                                         ####
  on.exit({

  })

#   ____________________________________________________
#   Defenses and set up   ####

  file     <- deal_with_file_path(file, ext, create_dir)
  file_dir <- fs::path_dir(file)

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
  if (is.null(st_dir)) {
    st_dir <-
      file_dir |>
      fs::path("_st_dir") |>
      fs::dir_create()
  } else {

    if (fs::is_absolute_path(st_dir)) {
      st_dir <- fs::dir_create(st_dir)
    } else {
      st_dir <-
        fs::path_wd(st_dir) |>
        fs::dir_create()
    }

  }



#   ____________________________________________________
#   Return                                           ####
  return(invisible(file))

}


#' Make sure file names and directory paths are working fine
#'
#' @inheritParams st_write
#'
#' @return character vector with file path
#' @keywords internal
deal_with_file_path <- function(file, ext, create_dir) {

  # correctly write file name
  if (ext == "") {
    ext <- getOption("stamp.default.ext")
  } else {
    # check that file ext and ext provided by the user are not different
    o_ext <- fs::path_ext(file)

    if (ext != o_ext) {
      cli::cli_warn("Original extension {.field {o_ext}} is different
                    from the one provided in {.field ext}: {ext}.
                    The ext {ext} provided will be used.")
    }
    file <-
      fs::path_ext_remove(file) |>
      fs::path(ext = ext)
  }

  # Check that dir exists
  file_dir <- fs::path_dir(file)
  if (!fs::dir_exists(file_dir) && create_dir == FALSE) {
    msg     <- c(
      "directory {.file {file_dir}} does not exist",
      "i" = "You could use option {.arg create_dir = TRUE}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error"
    )
  }
  fs::dir_create(file_dir)


#   ____________________________________________________
#   Return                                           ####
  return(file)

}
