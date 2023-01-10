

stamp_default_options <- list(
  stamp.verbose     = TRUE,
  stamp.default.ext = "qs",
  stamp.vintage     = TRUE,
  stamp.digest.algo = "sha1",

  # time stamp management
  stamp.timezone    = Sys.timezone(),
  stamp.timeformat  = "%Y%m%d%H%M%S",
  stamp.usetz       = FALSE
)

.onLoad <- function(libname, pkgname) {

# https://cli.r-lib.org/reference/inline-markup.html#classes
  # cli::cli_div(theme = list(
  #   span.myclass = list(color = "red"),
  #   "span.myclass" = list(before = "<<"),
  #   "span.myclass" = list(after = ">>")))

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## Options --------

  op    <- options()
  toset <- !(names(stamp_default_options) %in% names(op))
  if (any(toset)) options(stamp_default_options[toset])

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  ## defined values --------

  invisible()
}
