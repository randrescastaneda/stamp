#' Reading function depending on format selected
#'
#' @inheritParams st_write
#'
#' @return reading function according to `ext`
#' @keywords internal
#'
#' @examples
#' \dontrun{
#' # Rds default
#' read_fun <- get_reading_fun()
#' read_fun
#'
#' # fst format
#' read_fun <- get_reading_fun(ext="fst")
#' read_fun
#'}
get_reading_fun <- function(ext = "Rds") {

  # Select function -------------
  ext <- tolower(ext)

  rd <-
    if (ext == "fst") {
      \(path, ...) fst::read_fst(path = path, ...)
    } else if (ext == "dta") {
      \(path, ...) haven::read_dta(file = path, ...)
    } else if (ext == "qs") {
      \(path, ...) qs::qread(file = path, ...)
    } else if (ext == "feather") {
      \(path, ...) arrow::read_feather(file = path, ...)
    } else if (ext == "parquet") {
      \(path, ...) arrow::read_parquet(file = path, ...)
    } else if (ext == "rds") {
      \(path, ...) readRDS(file = path, ...)
    } else {
      cli::cli_abort("format {.strong .{ext}} is not supported by {.pkg stamp}")
    }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(rd))

}

