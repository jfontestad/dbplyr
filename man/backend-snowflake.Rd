% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/backend-snowflake.R
\name{backend-snowflake}
\alias{simulate_snowflake}
\title{Backend: Snowflake}
\usage{
simulate_snowflake()
}
\description{
See \code{vignette("translation-function")} and \code{vignette("translation-verb")} for
details of overall translation technology.

Use \code{simulate_snowflake()} with \code{lazy_frame()} to see simulated SQL without
converting to live access database.
}
\examples{
library(dplyr, warn.conflicts = FALSE)

lf <- lazy_frame(a = TRUE, b = 1, c = 2, d = "z", con = simulate_snowflake())
lf \%>\% transmute(x = paste0(z, " times"))
}
