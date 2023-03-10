% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stamp.R
\name{stamp_x_attr}
\alias{stamp_x_attr}
\title{Add attributes and characteristics of x to be used in stamp}
\usage{
stamp_x_attr(x)
}
\arguments{
\item{x}{R object to write to disk as per limitations of \code{file} format.}
}
\value{
list of attributes
}
\description{
In addition to the information from \link{stamp_set}, \link{stamp_x_attr} generates
information about the attributes of the R object, including basic descriptive
stats.
}
\examples{
x <- data.frame(a = 1:10, b = letters[1:10])
stamp_x_attr(x)
}
\seealso{
Other stamp functions: 
\code{\link{stamp_confirm}()},
\code{\link{stamp_get}()},
\code{\link{stamp_read}()},
\code{\link{stamp_save}()},
\code{\link{stamp_set}()},
\code{\link{stamp_time}()}
}
\concept{stamp functions}
