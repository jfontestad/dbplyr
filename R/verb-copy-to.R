#' Copy a local data frame to a remote database
#'
#' @description
#' This is an implementation of the dplyr [copy_to()] generic and it mostly
#' a wrapper around [DBI::dbWriteTable()].
#'
#' It is useful for copying small amounts of data to a database for examples,
#' experiments, and joins. By default, it creates temporary tables which are
#' only visible within the current connection to the database.
#'
#' @export
#' @param df A local data frame, a `tbl_sql` from same source, or a `tbl_sql`
#'   from another source. If from another source, all data must transition
#'   through R in one pass, so it is only suitable for transferring small
#'   amounts of data.
#' @param types a character vector giving variable types to use for the columns.
#'    See <https://www.sqlite.org/datatype3.html> for available types.
#' @param temporary if `TRUE`, will create a temporary table that is
#'   local to this connection and will be automatically deleted when the
#'   connection expires
#' @param unique_indexes a list of character vectors. Each element of the list
#'   will create a new unique index over the specified column(s). Duplicate rows
#'   will result in failure.
#' @param indexes a list of character vectors. Each element of the list
#'   will create a new index.
#' @param analyze if `TRUE` (the default), will automatically ANALYZE the
#'   new table so that the query optimiser has useful information.
#' @param in_transaction Should the table creation be wrapped in a transaction?
#'   This typically makes things faster, but you may want to suppress if the
#'   database doesn't support transactions, or you're wrapping in a transaction
#'   higher up (and your database doesn't support nested transactions.)
#' @inheritParams dplyr::copy_to
#' @inherit arrange.tbl_lazy return
#' @seealso [copy_inline()] to use small data in an SQL query without actually
#'   writing to a table.
#' @examples
#' library(dplyr, warn.conflicts = FALSE)
#'
#' df <- data.frame(x = 1:5, y = letters[5:1])
#' db <- copy_to(src_memdb(), df)
#' db
#'
#' df2 <- data.frame(y = c("a", "d"), fruit = c("apple", "date"))
#' # copy_to() is called automatically if you set copy = TRUE
#' # in the join functions
#' db %>% left_join(df2, copy = TRUE)
#' @importFrom dplyr copy_to
copy_to.src_sql <- function(dest, df, name = deparse(substitute(df)),
                            overwrite = FALSE, types = NULL, temporary = TRUE,
                            unique_indexes = NULL, indexes = NULL,
                            analyze = TRUE, ...,
                            in_transaction = TRUE
                            ) {
  assert_that(is.flag(temporary))

  if (!is.data.frame(df) && !inherits(df, "tbl_sql")) {
    abort("`df` must be a local dataframe or a remote tbl_sql")
  }

  name <- as.sql(name, con = dest$con)

  if (inherits(df, "tbl_sql") && same_src(df$src, dest)) {
    out <- compute(df,
      name = name,
      temporary = temporary,
      unique_indexes = unique_indexes,
      indexes = indexes,
      analyze = analyze,
      ...
    )
  } else {
    # avoid S4 dispatch problem in dbSendPreparedQuery
    df <- as.data.frame(collect(df))

    name <- db_copy_to(dest$con, name, df,
      overwrite = overwrite,
      types = types,
      temporary = temporary,
      unique_indexes = unique_indexes,
      indexes = indexes,
      analyze = analyze,
      in_transaction = in_transaction,
      ...
    )

    out <- tbl_src_dbi(dest, name, vars = names(df))
  }

  invisible(out)
}

#' @importFrom dplyr auto_copy
#' @export
auto_copy.tbl_sql <- function(x, y, copy = FALSE, ...) {
  copy_to(x$src, as.data.frame(y), unique_table_name(), ...)
}

#' Use a local data frame in a dbplyr query
#'
#' This is an alternative to [copy_to()] that does not need write access and
#' is faster for small data.
#'
#' It writes the data directly in the SQL query via the `VALUES` clause.
#'
#' @seealso [copy_to()] to copy the data into a new database table.
#' @export
#' @param con A database connection.
#' @param df A local data frame. The data is written directly in the SQL query
#'   so it should be small.
#' @return A `tbl_lazy`.
#'
#' @examples
#' df <- data.frame(x = 1:3, y = c("a", "b", "c"))
#' con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' copy_inline(con, df)
#'
#' copy_inline(con, df) %>% dplyr::show_query()
copy_inline <- function(con, df) {
  if (!inherits(df, "data.frame")) {
    abort("`df` needs to be a data.frame.")
  }

  if (ncol(df) == 0) {
    abort("`df` needs at least one column.")
  }

  # This workaround is needed because `tbl_sql()` applies `as.sql()` on `from`
  subclass <- class(con)[[1]] # prefix added by dplyr::make_tbl
  dplyr::make_tbl(
    c(subclass, "sql", "lazy"),
    src = src_dbi(con),
    from = df,
    lazy_query = lazy_values_query(df),
    vars = colnames(df)
  )
}

lazy_values_query <- function(df) {
  structure(list(df = df), class = c("lazy_values_query", "lazy_query"))
}

#' @export
sql_build.lazy_values_query <- function(op, con, ...) {
  op
}

#' @export
sql_render.lazy_values_query <- function(query, con = query$src$con, ..., subquery = FALSE, lvl = 0, cte = FALSE) {
  sql_values(con, query$df, lvl = lvl)
}

#' @export
flatten_query.lazy_values_query <- function(qry, query_list) {
  querylist_reuse_query(qry, query_list)
}

#' @export
op_vars.lazy_values_query <- function(op) {
  colnames(op$df)
}

#' @export
op_grps.lazy_values_query <- function(op) {
  character()
}

sql_values <- function(con, df, lvl = 0, ...) {
  check_dots_empty()
  UseMethod("sql_values")
}

#' @export
sql_values.DBIConnection <- function(con, df, lvl = 0, ...) {
  sql_values_clause(con, df, lvl = lvl)
}

#' @export
sql_values.SQLiteConnection <- function(con, df, lvl = 0, ...) {
  needs_escape <- purrr::map_lgl(df, ~ is(.x, "Date") || inherits(.x, "POSIXct"))
  purrr::modify_if(df, needs_escape, ~ escape(.x, con = con, parens = FALSE, collapse = NULL)) %>%
    sql_values_clause(con = con, lvl = lvl)
}

sql_values_clause <- function(con, df, row = FALSE, derived = FALSE, lvl = 0) {
  if (nrow(df) == 0L) {
    typed_cols <- purrr::map_chr(
      vctrs::vec_init(df),
      ~ {
        cast_expr <- call2(sql_cast_dispatch(.x), NA)
        translate_sql(!!cast_expr, con = con)
      }
    )

    query <- select_query(
      from = ident(),
      select = sql(typed_cols),
      where = sql("0 = 1")
    )

    return(sql_render(query, con = con, lvl = lvl))
  }

  # The query consists of two parts:
  # 1) An outer select which converts the values to the correct types. This needs
  # to use the translation of `as.<column type>(<column name>)` (e.g. `as.numeric(mpg)`)
  # because some backends need a special translation for some types e.g. casting
  # to logical/bool in MySQL
  #   `IF(<column name>, TRUE, FALSE)`
  # This is done with the help of `sql_cast_dispatch()` via dispatch on the
  # column type. The explicit cast is required so that joins work e.g. on date
  # columns in Postgres.
  # 2) A subquery which is the union of:
  #   a) a zero row table which is just required to name the columns. This is
  #      necessary as e.g. SQLite cannot name `VALUES`.
  #   b) `VALUES` clause
  sim_data <- rep_named(colnames(df), list(NULL))
  cols_clause <- escape(sim_data, con = con, parens = FALSE, collapse = NULL)

  null_row_query <- select_query(
    from = ident(),
    select = sql(cols_clause),
    where = sql("0 = 1")
  )

  escaped_values <- purrr::map(df, escape, con = con, collapse = NULL, parens = FALSE)
  rows <- rlang::exec(paste, !!!escaped_values, sep = ", ")
  rows_sql <- sql(paste0(if (row) "ROW", "(", rows, ")"))

  rows_clauses <- list(sql_clause("VALUES", rows_sql))

  if (derived) {
    rows_query <- sql_format_clauses(rows_clauses, lvl = lvl + 3, con = con)

    derived_sql <- sql(paste0("drvd(", escape(ident(colnames(df)), con = con), ")"))

    rows_query <- sql_query_select(
      con,
      sql("*"),
      # sql_subquery() can't use sql() or ident_q() as `name` argument
      build_sql(sql_indent_subquery(rows_query, con, lvl + 2), " ", derived_sql, con = con),
      lvl = lvl + 2
    )
  } else {
    rows_query <- sql_format_clauses(rows_clauses, lvl = lvl + 1, con = con)
  }

  union_query <- set_op_query(null_row_query, rows_query, type = "UNION", all = TRUE)
  subquery <- sql_render(union_query, con = con, lvl = lvl + 1)

  typed_cols <- purrr::map2_chr(
    df, colnames(df),
    ~ {
      cast_expr <- call2(sql_cast_dispatch(.x), ident(.y))
      translate_sql(!!cast_expr, con = con)
    }
  )
  select_clause <- sql_vector(typed_cols, parens = FALSE, collapse = NULL, con = con)

  sql_query_select(
    con,
    select = select_clause,
    from = sql_subquery(con, subquery, name = "values_table", lvl = lvl),
    lvl = lvl
  )
}

# This
sql_cast_dispatch <- function(x) {
  UseMethod("sql_cast_dispatch")
}

#' @export
sql_cast_dispatch.sql <- function(x) {
  expr(as.character)
}

#' @export
sql_cast_dispatch.logical <- function(x) {
  expr(as.logical)
}

#' @export
sql_cast_dispatch.integer <- function(x) {
  expr(as.integer)
}

#' @export
sql_cast_dispatch.numeric <- function(x) {
  expr(as.numeric)
}

#' @export
sql_cast_dispatch.character <- function(x) {
  expr(as.character)
}

#' @export
sql_cast_dispatch.factor <- function(x) {
  expr(as.character)
}

#' @export
sql_cast_dispatch.Date <- function(x) {
  expr(as.Date)
}

#' @export
sql_cast_dispatch.POSIXct <- function(x) {
  expr(as.POSIXct)
}

#' @export
sql_cast_dispatch.integer64 <- function(x) {
  expr(as.integer64)
}

globalVariables(c("as.integer64"))
