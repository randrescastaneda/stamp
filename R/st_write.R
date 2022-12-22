#' Write R object with corresponding stamp (hash digest)
#'
#' @param x R object to write to disk as per limitations of `file` format.
#' @param file File or connection to write to
#' @param ext
#' @param st_file
#' @param attr
#' @param ...
#'
#' @section Details:
#' Object `x` is stored in `file` but its hash (i.e., stamp) is
#' stored in subdirectory `st_file`.
#'
#'
#'
#'
#'
#' @return
#' @export
#'
#' @examples
st_write <- function(x,
                     file,
                     ext = fs::path_ext(file),
                     st_file = "_stamp",
                     attr = NULL,
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
