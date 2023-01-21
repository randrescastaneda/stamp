#' stamp: Create signature stamp when saving R objects
#'
#' Stamp allows to store attributes and data signatures (hashes) that allows you
#' to know whether the data in memory has changed or not. This is mainly used in
#' projects with data that is changing constantly and should not be rewritten in
#' each run.
#'
#' @section stamp functions: The stamp functions ...
#'
#' @docType package
#' @name stamp

# Make sure data.table knows we know we're using it
#' @noRd
.datatable.aware = TRUE

#' @keywords internal
#' @import rlang
"_PACKAGE"

# Prevent R CMD check from complaining about the use of pipe expressions
# standard data.table variables
if (getRversion() >= "2.15.1") {
  utils::globalVariables(
    names = c(
      ".",
      ".I",
      ".N",
      ".SD",
      ".",
      "!!",
      ":="
    ),
    package = utils::packageName()
  )
}

## usethis namespace: start
## usethis namespace: end
NULL
