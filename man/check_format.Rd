% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{check_format}
\alias{check_format}
\title{Check whether the format is in Namespace}
\usage{
check_format(file_ext, ext = NULL)
}
\arguments{
\item{file_ext}{character: File extension}

\item{ext}{character: format or extension of file. Default is
\code{fs::path_ext(file)}}
}
\value{
character with extension of desired format
}
\description{
Use valus in \code{ext} to check the corresponding package is
available. It it is not, it defaults to \code{Rds}
}
\examples{
\dontrun{
fmt <- check_format(file_ext = "fst")
fmt
}
}
\keyword{internal}
