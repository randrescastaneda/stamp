% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stamp.R
\name{stamp_set}
\alias{stamp_set}
\alias{stamp_call}
\alias{stamp_env}
\title{Set and call stamps from \code{.stamp} environment}
\usage{
stamp_set(
  x = NULL,
  st_name = NULL,
  stamp = NULL,
  verbose = getOption("stamp.verbose"),
  replace = FALSE,
  ...
)

stamp_call(st_name)

stamp_env(verbose = getOption("stamp.verbose"))
}
\arguments{
\item{x}{An arbitrary R object which will then be passed to the
base::serialize function}

\item{st_name}{character: Name of stamp to be set or called in .stamp env.}

\item{stamp}{previously calculated stamp with \link{stamp_get}.}

\item{verbose}{logical: whether to display additional information. This could
be changed in option \code{"stamp.verbose"}. Default is \code{TRUE}}

\item{replace}{Logical: if TRUE and \code{st_name} already exists in \code{.stamp}
environment, it will be replaced with new stamp. If \code{FALSE} it gives an
error. Default is \code{FALSE}}

\item{...}{arguments passed on to \code{\link[=stamp_get]{stamp_get()}}}
}
\value{
invisible stamp from stamp_get() but it can now be called with
stamp_call()

list with stamp values

names of stamps available in .stamp env. If no stamp is available, it
returns an invisible character vector of length 0.
}
\description{
\code{stamp_set()} makes use of \code{stamp_get()} and stores the stamp
into the \code{.stamp} environment, which can be accesses via \code{stamp_call()} or
\code{stamp_env()}. \code{stamp_call()}  retrieves one single stamp. \code{stamp_env()}
display all the stamps available in the \code{.stamp} env.
}
\examples{
stamp_env()
x <- data.frame(a = 1:10, b = letters[1:10])
stamp_set(x, st_name = "xts")
stamp_call("xts")

y <- data.frame(a = 5:10, b = letters[5:10])
stamp_set(y, st_name = "yts")
stamp_env()
}
\seealso{
Other stamp functions: 
\code{\link{stamp_confirm}()},
\code{\link{stamp_get}()},
\code{\link{stamp_read}()},
\code{\link{stamp_save}()},
\code{\link{stamp_time}()},
\code{\link{stamp_x_attr}()}
}
\concept{stamp functions}
