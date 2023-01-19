#'Saving function depending on format selected
#'
#'@inheritParams st_write
#'
#'@return saving function according to `ext` that returns logical value
#'  depending on whether the file was saved successfully
#'
#' @keywords internal
#'
#' @examples
#' # Rds default
#' save_fun <- get_saving_fun()
#' save_fun
#'
#' # fst format
#' \dontrun{
#' save_fun <- get_saving_fun(ext="fst")
#' save_fun
#'}
get_saving_fun <- function(ext = "Rds") {

  # Select function -------------
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
    } else if (ext == "parquet") {
      \(x, path, ...) arrow::write_parquet(x = x, sink = path, ...)
    } else if (ext == "rds") {
      \(x, path, ...) saveRDS(object = x, file = path, ...)
    } else {
      cli::cli_abort("format {.strong .{ext}} is not supported by {.pkg stamp}")
    }

  # make sure that data saved properly

  sv2 <- \(x, path, ...) {
    t1 <- Sys.time()
    Sys.sleep(.2)
    sv(x, path, ...)
    saved <- t1 <= file.mtime(path)
    names(saved) <- path
    return(saved)
  }

#   ____________________________________________________
#   Return                                           ####
  return(invisible(sv2))

}


#' Check whther object can be saved in tabular formats like fst
#'
#' @inheritParams st_write
#'
#' @return logical for complex data
#' @keywords internal
#'
#' @examples
#' # False
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



#' Make sure file names and directory paths are working fine
#'
#' @inheritParams st_write
#'
#' @return character vector with file path
#' @keywords internal
ensure_file_path <- function(file, recurse) {

  # Check that dir exists
  file_dir <- fs::path_dir(file)
  if (!fs::dir_exists(file_dir) && recurse == FALSE) {
    msg     <- c(
      "directory {.file {file_dir}} does not exist",
      "i" = "You could use option {.arg recurse = TRUE}"
    )
    cli::cli_abort(msg,
                   class = "stamp_error"
    )
  }
  fs::dir_create(file_dir, recurse = TRUE)


  #   ____________________________________________________
  #   Return                                           ####
  return(file_dir)

}



