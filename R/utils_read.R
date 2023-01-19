#' Reading function depending on format selected
#'
#' @inheritParams st_write
#'
#' @return reading function according to `ext`
#' @keywords internal
#'
#' @examples
#' # Rds default
#' read_fun <- get_reading_fun()
#' read_fun
#'
#' \dontrun{
#' # fst format
#' read_fun <- get_reading_fun(ext="fst")
#' read_fun
#'}
get_reading_fun <- function(ext = "Rds") {

  # Select function -------------
  ext <- tolower(ext)

  rd <-
    if (ext == "fst") {
      \(x, path, ...) fst::read_fst(x = x, path = path, ...)
    } else if (ext == "dta") {
      \(x, path, ...) haven::read_dta(data = x, path =  path, ...)
    } else if (ext == "qs") {
      \(x, path, ...) qs::qread(x = x, file = path, ...)
    } else if (ext == "feather") {
      \(x, path, ...) arrow::read_feather(x = x, sink = path, ...)
    } else if (ext == "parquet") {
      \(x, path, ...) arrow::read_parquet(x = x, sink = path, ...)
    } else if (ext == "rds") {
      \(x, path, ...) readRDS(object = x, file = path, ...)
    } else {
      cli::cli_abort("format {.strong .{ext}} is not supported by {.pkg stamp}")
    }

  #   ____________________________________________________
  #   Return                                           ####
  return(invisible(rd))

}

