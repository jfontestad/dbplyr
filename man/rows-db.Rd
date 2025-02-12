% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rows.R
\name{rows_insert.tbl_lazy}
\alias{rows_insert.tbl_lazy}
\alias{rows_append.tbl_lazy}
\alias{rows_update.tbl_lazy}
\alias{rows_patch.tbl_lazy}
\alias{rows_upsert.tbl_lazy}
\alias{rows_delete.tbl_lazy}
\title{Manipulate individual rows}
\usage{
\method{rows_insert}{tbl_lazy}(
  x,
  y,
  by = NULL,
  ...,
  conflict = c("error", "ignore"),
  copy = FALSE,
  in_place = FALSE,
  returning = NULL
)

\method{rows_append}{tbl_lazy}(x, y, ..., copy = FALSE, in_place = FALSE, returning = NULL)

\method{rows_update}{tbl_lazy}(
  x,
  y,
  by = NULL,
  ...,
  unmatched = c("error", "ignore"),
  copy = FALSE,
  in_place = FALSE,
  returning = NULL
)

\method{rows_patch}{tbl_lazy}(
  x,
  y,
  by = NULL,
  ...,
  unmatched = c("error", "ignore"),
  copy = FALSE,
  in_place = FALSE,
  returning = NULL
)

\method{rows_upsert}{tbl_lazy}(
  x,
  y,
  by = NULL,
  ...,
  copy = FALSE,
  in_place = FALSE,
  returning = NULL
)

\method{rows_delete}{tbl_lazy}(
  x,
  y,
  by = NULL,
  ...,
  unmatched = c("error", "ignore"),
  copy = FALSE,
  in_place = FALSE,
  returning = NULL
)
}
\arguments{
\item{x}{A pair of data frames or data frame extensions (e.g. a tibble).
\code{y} must have the same columns of \code{x} or a subset.}

\item{y}{A pair of data frames or data frame extensions (e.g. a tibble).
\code{y} must have the same columns of \code{x} or a subset.}

\item{by}{An unnamed character vector giving the key columns. The key columns
must exist in both \code{x} and \code{y}. Keys typically uniquely identify each row,
but this is only enforced for the key values of \code{y} when \code{rows_update()},
\code{rows_patch()}, or \code{rows_upsert()} are used.

By default, we use the first column in \code{y}, since the first column is
a reasonable place to put an identifier variable.}

\item{...}{Other parameters passed onto methods.}

\item{conflict}{For \code{rows_insert()}, how should keys in \code{y} that conflict
with keys in \code{x} be handled? A conflict arises if there is a key in \code{y}
that already exists in \code{x}.

One of:
\itemize{
\item \code{"error"}, the default, is not supported for database tables. To get the
same behaviour add a unique index on the \code{by} columns and use
\code{rows_append()}.
\item \code{"ignore"} will ignore rows in \code{y} with keys that conflict with keys in
\code{x}.
}}

\item{copy}{If \code{x} and \code{y} are not from the same data source,
and \code{copy} is \code{TRUE}, then \code{y} will be copied into the
same src as \code{x}.  This allows you to join tables across srcs, but
it is a potentially expensive operation so you must opt into it.}

\item{in_place}{Should \code{x} be modified in place? This argument is only
relevant for mutable backends (e.g. databases, data.tables).

When \code{TRUE}, a modified version of \code{x} is returned invisibly;
when \code{FALSE}, a new object representing the resulting changes is returned.}

\item{returning}{Columns to return.}

\item{unmatched}{For \code{rows_update()}, \code{rows_patch()}, and \code{rows_delete()},
how should keys in \code{y} that are unmatched by the keys in \code{x} be handled?

One of:
\itemize{
\item \code{"error"}, the default, is not supported for database tables. Add a
foreign key constraint on the \code{by} columns of \code{y} to let the database
check this behaviour for you.
\item \code{"ignore"} will ignore rows in \code{y} with keys that are unmatched by the
keys in \code{x}.
}}
}
\description{
These are methods for the dplyr \code{\link[=rows_insert]{rows_insert()}}, \code{\link[=rows_append]{rows_append()}},
\code{\link[=rows_update]{rows_update()}}, \code{\link[=rows_patch]{rows_patch()}}, \code{\link[=rows_upsert]{rows_upsert()}}, and \code{\link[=rows_delete]{rows_delete()}}
generics.
}
