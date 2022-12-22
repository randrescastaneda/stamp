#' Write R object with corresponding stamp (hash digest)
#'
#' @param x R object to write to disk as per limitations of `file` format.
#' @param file character: File or connection to write to
#' @param ext  character: format or extension of file. Default is
#'   `fs::path_ext(file)`
#' @param st_file character: Directory to store stamp files. By default it is a
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
                     ext = fs::path_ext(file),
                     st_file = "_stamp",
                     attr = list(),
                     ...) {

#   ____________________________________________________
#   on.exit                                         ####
  on.exit({

  })

#   ____________________________________________________
#   Defenses                                        ####
  stopifnot( exprs = {

    }
  )

#   ____________________________________________________
#   Early returns                                   ####
  if (FALSE) {
    return()
  }

#   ____________________________________________________
#   Computations                                     ####


#   ____________________________________________________
#   Return                                           ####
  return(TRUE)

}
