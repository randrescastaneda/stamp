#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @rawNamespace import(data.table, except = fdroplevels)
## usethis namespace: end
NULL

# Suppress R CMD check NOTE for data.table join-prefix variable used inside
# st_catalog_query(): `i.path` is the standard `i.`-prefixed column reference
# produced when joining two data.tables with data.table's `X[Y, ...]` syntax.
utils::globalVariables("i.path")
