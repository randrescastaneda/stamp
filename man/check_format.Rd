% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils_write.R
\name{check_format}
\alias{check_format}
\title{Check whether the format is in Namespace}
\usage{
check_format(ext = "Rds")
}
\arguments{
\item{ext}{character: format or extension of file. Default is
`fs::path_ext(file)`}
}
\value{
character with extension of desired format
}
\description{
Use valus in `ext` to check the corresponding package is
  available. It it is not, it defaults to `Rds`
}
\examples{
fmt <- check_format()
fmt
}