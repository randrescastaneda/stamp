

stamp_default_options <- list(
  stamp.verbose          = TRUE,
  stamp.default.ext      = "qs",
  stamp.vintage          = TRUE,
  stamp.digest.algo      = "sha1",

  # time stamp management
  stamp.timezone         = Sys.timezone(),
  stamp.timeformat       = "%Y%m%d%H%M%S",
  stamp.usetz            = FALSE,
  stamp.completestamp    = TRUE,
  stamp.dir_stamp        = "_stamp",
  stamp.dir_vintage      = "_vintage",
  stamp.waldo            = TRUE,
  stamp.stamp_prefix     = "_st_"
)

.onLoad <- function(libname, pkgname) {

# https://cli.r-lib.org/reference/inline-markup.html#classes
  cli_red <- cli::cli_div(theme = list(span.red = list(color = "red")),
               .auto_close = FALSE)
  # test_cli()
  # cli::cli_end(cli_red)
  # test_cli()

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


