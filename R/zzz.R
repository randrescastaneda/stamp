

stamp_default_options <- list(

  # interactive
  stamp.verbose          = TRUE,
  stamp.vintage          = TRUE,
  stamp.completestamp    = TRUE,
  stamp.digest.algo      = "spookyhash",
  stamp.seed             = NULL,

  # time stamp management
  stamp.timezone         = Sys.timezone(),
  stamp.timeformat       = "%Y%m%d%H%M%S",
  stamp.usetz            = FALSE,

  # file management
  stamp.dir_stamp        = "_stamp",
  stamp.dir_vintage      = "_vintage",
  stamp.stamp_prefix     = "st_",
  stamp.default.ext      = "qs",

  # Others
  stamp.waldo            = TRUE
)


#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# On Load   ---------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


.onLoad <- function(libname, pkgname) {

# https://cli.r-lib.org/reference/inline-markup.html#classes

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## cli --------

  cli_red <- cli::cli_div(theme = list(span.red = list(color = "red")),
               .auto_close = FALSE)
  cli_blue <- cli::cli_div(theme = list(span.blue = list(color = "blue")),
               .auto_close = FALSE)

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Options --------

  op    <- options()
  toset <- !(names(stamp_default_options) %in% names(op))
  if (any(toset)) options(stamp_default_options[toset])

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## defined values --------

  invisible()
}

test_cli <- function() {
  cli::cli_text("This is {.red text in red} and this is not.")
}
#
# .onUnload <- function(libpath) {
#   cli::cli_end(cli_red)
# }


