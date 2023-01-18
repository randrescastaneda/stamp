#' Check whether the format is in Namespace
#'
#' @description Use valus in `ext` to check the corresponding package is
#'   available. It it is not, it defaults to `Rds`
#'
#' @inheritParams st_write
#' @param  file_ext character: File extension
#'
#' @return character with extension of desired format
#' @export
#'
#' @examples
#' fmt <- check_format()
#' fmt
check_format <- function(ext = "Rds", file_ext) {
  # Computations ------------
  ext <- tolower(ext)

  if (ext != file_ext) {
    cli::cli_warn("Format provided, {.strong .{ext}}, is different from format in
                  file name, {.strong .{file_ext}}. The former will be used.",
                  wrap = TRUE)
  }

  # correctly write file name
  if (ext == "") {
    ext <- getOption("stamp.default.ext") |>
      tolower()
  }

  pkg_av <- pkg_available(ext)
  if (!pkg_av) {
    cli::cli_alert_warning("switching to {.strong .Rds} format")
    ext <- "Rds"
  }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(ext))

}




#' Check whether format is supported and package is available
#'
#' @param ext character: extension of file
#'
#' @return logical vector for availability of package
#' @keywords internal
#' @examples
#' \dontrun{
#' pkg_available("fst")
#'}
pkg_available <- function(ext) {


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Computations   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  pkg_name <- c("base", "fst", "haven", "qs", "arrow", "arrow")
  formats  <- c("rds", "fst", "dta", "qs", "feather", "parquet")

  fmt <- which(ext %in% formats)
  if (length(fmt) == 0) {
    ofs <- cli::cli_vec(
      formats,
      style = list("vec-last" = " or ")
    )
    msg     <- c(
      "format {.strong .{ext}} is not supported by {.pkg stamp}",
      "i" = "Use any of the following formats: {ofs}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )
  }

  pkg <- pkg_name[fmt]

  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_alert_warning("Package {.pkg {pkg}} is not available in namespace")
    pkg_av <- FALSE
  } else {
    pkg_av <- TRUE
  }

  names(pkg_av) <- pkg


  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    return(invisible(pkg_av))

}


#' Check that file format is supported and that package is available
#'
#' @param file character: file path to be read
#'
#' @return invisible TRUE
#' @keywords internal
check_file <- function(file) {

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Availability   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## File --------

  if (!fs::file_exists(file)) {

    msg     <- c(
      "File {.file {file}} is not available")
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )

  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Package --------

  ext    <- fs::path_ext(file)
  pkg_av <- pkg_available(ext)

  if (!pkg_av) {
    pkg <- names(pkg_av)

    msg     <- c(
      "Package {.pkg {pkg}} is not available to read {.strong {ext}} format",
      "i" = "you can install it by typing {.code install.package('{pkg}')}")
    cli::cli_abort(msg,
                   class = "stamp_error",
                   wrap = TRUE
    )
  }

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  # Return   ---------
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  return(invisible(pkg_av))

}
