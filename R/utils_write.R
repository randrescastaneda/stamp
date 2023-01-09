#' Saving function depending on format selected
#'
#' @inheritParams st_write
#'
#' @return saving function according to `ext`
#' @export
#'
#' @examples
#' # Rds default
#' save_fun <- get_save_fun()
#' save_fun
#'
#' # fst format
#' save_fun <- get_save_fun(ext="fst")
#' save_fun
get_save_fun <- function(ext = "Rds") {
  ext <- tolower(ext)

  sv <-
    if (ext == "fst") {
      \(x, path, ...) fst::write_fst(x = x, path = path, ...)
    } else if (ext == "dta") {
      \(x, path, ...) haven::write_dta(data = x, path =  path, ...)
    } else if (ext == "qs") {
      \(x, path, ...) qs::qsave(x = x, file = path, ...)
    } else if (ext == "feather") {
      \(x, path, ...) arrow::write_feather(x = x, sink = path, ...)
    } else if (ext == "rds") {
      \(x, path, ...) saveRDS(object = x, file = path, ...)
    } else {
      cli::cli_abort("format {.strong .{ext}} is not available")
    }
#   ____________________________________________________
#   Return                                           ####
  return(invisible(sv))

}



#' Check whether the format is in Namespace
#'
#' @description Use valus in `ext` to check the corresponding package is
#'   available. It it is not, it defaults to `Rds`
#'
#' @inheritParams st_write
#'
#' @return character with extension of desired format
#' @export
#'
#' @examples
#' fmt <- check_format()
#' fmt
check_format <- function(ext = "Rds") {
  ext <- tolower(ext)

  pkg_name <- c("base", "fst", "haven", "qs", "arrow", "arrow")
  formats  <- c("rds", "fst", "dta", "qs", "feather", "parquet")

  fmt <- which(ext %in% formats)
  if (length(fmt) == 0) {
    cli::cli_abort("format {.strong .{ext}} is not available")
  }

  pkg <- pkg_name[fmt]

  if (!requireNamespace(pkg, quietly = TRUE)) {
    cli::cli_alert_warning("Package {.pkg {pkg}} is not available in namespace,
                           switching to {.strong .Rds} format")
    ext <- "Rds"
  }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(ext))

}


#' Check whther object can be saved in tabular formats like fst
#'
#' @inheritParams st_write
#'
#' @return logical for complex data
#' @export
#'
#' @examples
#' False
#' check_complex_data(data.frame())
#'
#' # TRUE
#' check_complex_data(list())
check_complex_data <- function(x) {


#   ____________________________________________________
#   Computations                                     ####
  if (is.data.frame(x)) {

    complex_df <-
      lapply(x, class) |>  # variables class
      unique() |>
      {\(.) "list" %in% .}()

  } else {
    complex_df <- TRUE
  }

#   ____________________________________________________
#   Return                                           ####
  return(complex_df)

}



#' change file extension to new ext
#'
#' @param file character: current file path with old ext
#' @param ext character: new ext
#'
#' @return character file path
#' @keywords internal
change_file_ext <- function(file, ext) {
  ext  <- tolower(ext)
  oext <- fs::path_ext(file) |>
    tolower()

  if (ext != oext) {
    file <-  file |>
      fs::path_ext_remove() |>
      fs::path(ext = ext)
  }

#   ____________________________________________________
#   Return                                           ####
  return(file)

}
