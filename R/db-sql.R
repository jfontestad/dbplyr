#' SQL generation generics
#'
#' @description
#'
#' SQL translation:
#'
#' * `sql_expr_matches(con, x, y)` generates an alternative to `x = y` when a
#'   pair of `NULL`s should match. The default translation uses a `CASE WHEN`
#'   as described in <https://modern-sql.com/feature/is-distinct-from>.
#'
#' * `sql_translation(con)` generates a SQL translation environment.
#'
#' * `sql_random(con)` generates SQL to get a random number which can be used
#'   to select random rows in `slice_sample()`.
#'
#' * `supports_window_clause(con)` does the backend support named windows?
#'
#' Tables:
#'
#' * `sql_table_analyze(con, table)` generates SQL that "analyzes" the table,
#'   ensuring that the database has up-to-date statistics for use in the query
#'   planner. It called from [copy_to()] when `analyze = TRUE`.
#'
#' * `sql_table_index()` generates SQL for adding an index to table. The
#'
#' Query manipulation:
#'
#' * `sql_query_explain(con, sql)` generates SQL that "explains" a query,
#'   i.e. generates a query plan describing what indexes etc that the
#'   database will use.
#'
#' * `sql_query_fields()` generates SQL for a 0-row result that is used to
#'   capture field names in [tbl_sql()]
#'
#' * `sql_query_save(con, sql)` generates SQL for saving a query into a
#'   (temporary) table.
#'
#' * `sql_query_wrap(con, from)` generates SQL for wrapping a query into a
#'   subquery.
#'
#' Query indentation:
#'
#' * `sql_indent_subquery(from, con, lvl)` helps indenting a subquery.
#'
#' Query generation:
#'
#' * `sql_query_select()` generates SQL for a `SELECT` query
#' * `sql_query_join()` generates SQL for joins
#' * `sql_query_semi_join()` generates SQL for semi- and anti-joins
#' * `sql_query_set_op()` generates SQL for `UNION`, `INTERSECT`, and `EXCEPT`
#'   queries.
#'
#' Query generation for manipulation:
#'
#' * `sql_query_insert()` and `sql_query_append()` generate SQL for an `INSERT FROM` query.
#' * `sql_query_update_from()` generates SQL for an `UPDATE FROM` query.
#' * `sql_query_upsert()` generates SQL for an `UPSERT` query.
#' * `sql_query_delete()` generates SQL for an `DELETE FROM` query
#' * `sql_returning_cols()` generates SQL for a `RETURNING` clause
#'
#' @section dbplyr 2.0.0:
#'
#' Many `dplyr::db_*` generics have been replaced by `dbplyr::sql_*` generics.
#' To update your backend, you'll need to extract the SQL generation out of your
#' existing code, and place it in a new method for a dbplyr `sql_` generic.
#'
#' * `dplyr::db_analyze()` is replaced by `dbplyr::sql_table_analyze()`
#' * `dplyr::db_explain()` is replaced by `dbplyr::sql_query_explain()`
#' * `dplyr::db_create_index()` is replaced by `dbplyr::sql_table_index()`
#' * `dplyr::db_query_fields()` is replaced by `dbplyr::sql_query_fields()`
#' * `dplyr::db_query_rows()` is no longer used; you can delete it
#' * `dplyr::db_save_query()` is replaced by `dbplyr::sql_query_save()`
#'
#' The query generating functions have also changed names. Their behaviour is
#' unchanged, so you just need to rename the generic and import from dbplyr
#' instead of dplyr.
#'
#' * `dplyr::sql_select()` is replaced by `dbplyr::sql_query_select()`
#' * `dplyr::sql_join()` is replaced by `dbplyr::sql_query_join()`
#' * `dplyr::sql_semi_join()` is replaced by `dbplyr::sql_query_semi_join()`
#' * `dplyr::sql_set_op()` is replaced by `dbplyr::sql_query_set_op()`
#' * `dplyr::sql_subquery()` is replaced by `dbplyr::sql_query_wrap()`
#'
#' Learn more in `vignette("backend-2.0")`
#'
#' @keywords internal
#' @family generic
#' @name db-sql
NULL

#' @export
#' @rdname db-sql
sql_expr_matches <- function(con, x, y) {
  UseMethod("sql_expr_matches")
}
# https://modern-sql.com/feature/is-distinct-from
#' @export
sql_expr_matches.DBIConnection <- function(con, x, y) {
  build_sql(
    "CASE WHEN (", x, " = ", y, ") OR (", x, " IS NULL AND ", y, " IS NULL) ",
    "THEN 0 ",
    "ELSE 1 ",
    "END = 0",
    con = con
  )
}

#' @export
#' @rdname db-sql
sql_translation <- function(con) {
  UseMethod("sql_translation")
}
# sql_translation.DBIConnection lives in backend-.R
dbplyr_sql_translation <- function(con) {
  dbplyr_fallback(con, "sql_translate_env")
}
#' @importFrom dplyr sql_translate_env
#' @export
sql_translate_env.DBIConnection <- function(con) {
  sql_translation(con)
}

#' @export
#' @rdname db-sql
sql_random <- function(con) {
  UseMethod("sql_random")
}


# Tables ------------------------------------------------------------------

#' @rdname db-sql
#' @export
sql_table_analyze <- function(con, table, ...) {
  UseMethod("sql_table_analyze")
}
#' @export
sql_table_analyze.DBIConnection <- function(con, table, ...) {
  build_sql("ANALYZE ", as.sql(table, con = con), con = con)
}

#' @rdname db-sql
#' @export
sql_table_index <- function(con, table, columns, name = NULL, unique = FALSE, ...) {
  UseMethod("sql_table_index")
}
#' @export
sql_table_index.DBIConnection <- function(con, table, columns, name = NULL,
                                           unique = FALSE, ...) {
  assert_that(is_string(table) | is.schema(table), is.character(columns))

  name <- name %||% paste0(c(unclass(table), columns), collapse = "_")
  fields <- escape(ident(columns), parens = TRUE, con = con)
  build_sql(
    "CREATE ", if (unique) sql("UNIQUE "), "INDEX ", as.sql(name, con = con),
    " ON ", as.sql(table, con = con), " ", fields,
    con = con
  )
}

# Query manipulation ------------------------------------------------------

#' @rdname db-sql
#' @export
sql_query_explain <- function(con, sql, ...) {
  UseMethod("sql_query_explain")
}
#' @export
sql_query_explain.DBIConnection <- function(con, sql, ...) {
  build_sql("EXPLAIN ", sql, con = con)
}

#' @rdname db-sql
#' @export
sql_query_fields <- function(con, sql, ...) {
  UseMethod("sql_query_fields")
}
#' @export
sql_query_fields.DBIConnection <- function(con, sql, ...) {
  dbplyr_query_select(con, sql("*"), dbplyr_sql_subquery(con, sql), where = sql("0 = 1"))
}

#' @rdname db-sql
#' @export
sql_query_save <- function(con, sql, name, temporary = TRUE, ...) {
  UseMethod("sql_query_save")
}
#' @export
sql_query_save.DBIConnection <- function(con, sql, name, temporary = TRUE, ...) {
  build_sql(
    "CREATE ", if (temporary) sql("TEMPORARY "), "TABLE \n",
    as.sql(name, con), " AS\n", sql,
    con = con
  )
}
#' @export
#' @rdname db-sql
sql_query_wrap <- function(con, from, name = NULL, ..., lvl = 0) {
  UseMethod("sql_query_wrap")
}
#' @export
sql_query_wrap.DBIConnection <- function(con, from, name = NULL, ..., lvl = 0) {
  if (is.ident(from)) {
    setNames(from, name)
  } else if (is.schema(from)) {
    setNames(as.sql(from, con), name)
  } else {
    build_sql(sql_indent_subquery(from, con, lvl), " ", as_subquery_name(name), con = con)
  }
}

as_subquery_name <- function(x, default = ident(unique_subquery_name())) {
  if (is.ident(x)) {
    x
  } else if (is.null(x)) {
    default
  } else {
    ident(x)
  }
}

#' @export
#' @rdname db-sql
sql_indent_subquery <- function(from, con, lvl = 0) {
  multi_line <- grepl(x = from, pattern = "\\r\\n|\\r|\\n")
  if (multi_line) {
    build_sql(
      "(\n",
      from, "\n",
      indent_lvl(")", lvl),
      con = con
    )
  } else {
    # Strip indent
    from <- gsub("^ +", "", from)
    build_sql("(", from, ")", con = con)
  }
}

#' @rdname db-sql
#' @export
sql_query_rows <- function(con, sql, ...) {
  UseMethod("sql_query_rows")
}
#' @export
sql_query_rows.DBIConnection <- function(con, sql, ...) {
  from <- dbplyr_sql_subquery(con, sql, "master")
  build_sql("SELECT COUNT(*) FROM ", from, con = con)
}

#' @rdname db-sql
#' @export
supports_window_clause <- function(con) {
  UseMethod("supports_window_clause")
}

#' @export
supports_window_clause.DBIConnection <- function(con) {
  FALSE
}


# Query generation --------------------------------------------------------

#' @rdname db-sql
#' @export
sql_query_select <- function(con, select, from, where = NULL,
                             group_by = NULL, having = NULL,
                             window = NULL,
                             order_by = NULL,
                             limit = NULL,
                             distinct = FALSE,
                             ...,
                             subquery = FALSE,
                             lvl = 0) {
  UseMethod("sql_query_select")
}

#' @export
sql_query_select.DBIConnection <- function(con, select, from, where = NULL,
                               group_by = NULL, having = NULL,
                               window = NULL,
                               order_by = NULL,
                               limit = NULL,
                               distinct = FALSE,
                               ...,
                               subquery = FALSE,
                               lvl = 0) {
  sql_select_clauses(con,
    select    = sql_clause_select(con, select, distinct),
    from      = sql_clause_from(from),
    where     = sql_clause_where(where),
    group_by  = sql_clause_group_by(group_by),
    having    = sql_clause_having(having),
    window    = sql_clause_window(window),
    order_by  = sql_clause_order_by(order_by, subquery, limit),
    limit     = sql_clause_limit(con, limit),
    lvl       = lvl
  )
}
dbplyr_query_select <- function(con, ...) {
  dbplyr_fallback(con, "sql_select", ...)
}
#' @importFrom dplyr sql_select
#' @export
sql_select.DBIConnection <- function(con, select, from, where = NULL,
                                     group_by = NULL, having = NULL,
                                     window = NULL,
                                     order_by = NULL,
                                     limit = NULL,
                                     distinct = FALSE,
                                     ...,
                                     subquery = FALSE) {
  sql_query_select(
    con, select, from,
    where = where,
    group_by = group_by,
    having = having,
    window = window,
    order_by = order_by,
    limit = limit,
    distinct = distinct,
    ...,
    subquery = subquery
  )
}

#' @rdname db-sql
#' @export
sql_query_join <- function(con, x, y, vars, type = "inner", by = NULL, na_matches = FALSE, ..., lvl = 0) {
  UseMethod("sql_query_join")
}
#' @export
sql_query_join.DBIConnection <- function(con, x, y, vars, type = "inner", by = NULL, na_matches = FALSE, ..., lvl = 0) {
  JOIN <- switch(
    type,
    left = sql("LEFT JOIN"),
    inner = sql("INNER JOIN"),
    right = sql("RIGHT JOIN"),
    full = sql("FULL JOIN"),
    cross = sql("CROSS JOIN"),
    abort(paste0("Unknown join type: ", type))
  )

  x <- dbplyr_sql_subquery(con, x, name = by$x_as, lvl = lvl)
  y <- dbplyr_sql_subquery(con, y, name = by$y_as, lvl = lvl)

  select <- sql_join_vars(con, vars, x_as = by$x_as, y_as = by$y_as)
  on <- sql_join_tbls(con, by, na_matches = na_matches)

  # Wrap with SELECT since callers assume a valid query is returned
  clauses <- list(
    sql_clause_select(con, select),
    sql_clause_from(x),
    sql_clause(JOIN, y),
    sql_clause("ON", on, sep = " AND", parens = TRUE, lvl = 1)
  )
  sql_format_clauses(clauses, lvl, con)
}
dbplyr_query_join <- function(con, ..., lvl = 0) {
  dbplyr_fallback(con, "sql_join", ..., lvl = lvl)
}
#' @export
#' @importFrom dplyr sql_join
sql_join.DBIConnection <- function(con, x, y, vars, type = "inner", by = NULL, na_matches = FALSE, ..., lvl = 0) {
  sql_query_join(
    con, x, y, vars,
    type = type,
    by = by,
    na_matches = na_matches,
    ...,
    lvl = lvl
  )
}

#' @rdname db-sql
#' @export
sql_query_semi_join <- function(con, x, y, anti = FALSE, by = NULL, ..., lvl = 0) {
  UseMethod("sql_query_semi_join")
}
#' @export
sql_query_semi_join.DBIConnection <- function(con, x, y, anti = FALSE, by = NULL, ..., lvl = 0) {
  x <- dbplyr_sql_subquery(con, x, name = by$x_as)
  y <- dbplyr_sql_subquery(con, y, name = by$y_as)

  lhs <- escape(ident(by$x_as), con = con)
  rhs <- escape(ident(by$y_as), con = con)

  on <- sql_join_tbls(con, by)

  lines <- list(
    build_sql("SELECT * FROM ", x, con = con),
    build_sql("WHERE ", if (anti) sql("NOT "), "EXISTS (", con = con),
    # lvl = 1 because they are basically in a subquery
    sql_clause("SELECT 1 FROM", y, lvl = 1),
    # don't use `sql_clause_where()` to avoid wrapping each element in parens
    sql_clause("WHERE", on, sep = " AND", parens = TRUE, lvl = 1),
    sql(")")
  )
  sql_format_clauses(lines, lvl, con)
}

dbplyr_query_semi_join <- function(con, ...) {
  dbplyr_fallback(con, "sql_semi_join", ...)
}
#' @export
#' @importFrom dplyr sql_semi_join
sql_semi_join.DBIConnection <- function(con, x, y, anti = FALSE, by = NULL, ..., lvl = 0) {
  sql_query_semi_join(con, x, y, anti = anti, by = by, ..., lvl = lvl)
}

#' @rdname db-sql
#' @export
sql_query_set_op <- function(con, x, y, method, ..., all = FALSE, lvl = 0) {
  UseMethod("sql_query_set_op")
}
#' @export
sql_query_set_op.DBIConnection <- function(con, x, y, method, ..., all = FALSE, lvl = 0) {
  method <- paste0(method, if (all) " ALL")
  method <- style_kw(method)
  lines <- list(
    sql_indent_subquery(x, con = con, lvl = lvl),
    sql(method),
    sql_indent_subquery(y, con = con, lvl = lvl)
  )
  sql_format_clauses(lines, lvl, con)
}
# nocov start
dbplyr_query_set_op <- function(con, ...) {
  dbplyr_fallback(con, "sql_set_op", ...)
}
#' @importFrom dplyr sql_set_op
#' @export
sql_set_op.DBIConnection <- function(con, x, y, method) {
  # dplyr::sql_set_op() doesn't have ...
  sql_query_set_op(con, x, y, method)
}
# nocov end

#' @export
#' @rdname db-sql
sql_query_insert <- function(con, x_name, y, by, ..., conflict = c("error", "ignore"), returning_cols = NULL) {
  rlang::check_dots_used()
  UseMethod("sql_query_insert")
}

#' @export
sql_query_insert.DBIConnection <- function(con, x_name, y, by, ..., conflict = c("error", "ignore"), returning_cols = NULL) {
  # https://stackoverflow.com/questions/25969/insert-into-values-select-from
  conflict <- rows_check_conflict(conflict)

  parts <- rows_prep(con, x_name, y, by, lvl = 0)
  insert_cols <- escape(ident(colnames(y)), collapse = ", ", parens = TRUE, con = con)

  join_by <- list(x = by, y = by, x_as = x_name, y_as = ident("...y"))
  where <- sql_join_tbls(con, by = join_by, na_matches = "never")
  conflict_clauses <- sql_clause_where_exists(x_name, where, not = TRUE)

  clauses <- list2(
    sql_clause_insert(con, insert_cols, x_name),
    sql_clause_select(con, sql("*")),
    sql_clause_from(parts$from),
    !!!conflict_clauses,
    sql_returning_cols(con, returning_cols, x_name)
  )

  sql_format_clauses(clauses, lvl = 0, con)
}

#' @export
#' @rdname db-sql
sql_query_append <- function(con, x_name, y, ..., returning_cols = NULL) {
  rlang::check_dots_used()
  UseMethod("sql_query_append")
}

#' @export
sql_query_append.DBIConnection <- function(con, x_name, y, ..., returning_cols = NULL) {
  # https://stackoverflow.com/questions/25969/insert-into-values-select-from
  parts <- rows_prep(con, x_name, y, by = list(), lvl = 0)
  insert_cols <- escape(ident(colnames(y)), collapse = ", ", parens = TRUE, con = con)

  clauses <- list2(
    sql_clause_insert(con, insert_cols, x_name),
    sql_clause_select(con, sql("*")),
    sql_clause_from(parts$from),
    sql_returning_cols(con, returning_cols, x_name)
  )

  sql_format_clauses(clauses, lvl = 0, con)
}

#' @export
#' @rdname db-sql
sql_query_update_from <- function(con, x_name, y, by, update_values, ...,
                                  returning_cols = NULL) {
  rlang::check_dots_used()
  UseMethod("sql_query_update_from")
}

#' @export
sql_query_update_from.DBIConnection <- function(con, x_name, y, by,
                                                update_values, ...,
                                                returning_cols = NULL) {
  # https://stackoverflow.com/questions/2334712/how-do-i-update-from-a-select-in-sql-server
  parts <- rows_prep(con, x_name, y, by, lvl = 0)
  update_cols <- sql_escape_ident(con, names(update_values))

  # avoid CTEs for the general case as they do not work everywhere
  clauses <- list(
    sql_clause_update(x_name),
    sql_clause_set(update_cols, update_values),
    sql_clause_from(parts$from),
    sql_clause_where(parts$where),
    sql_returning_cols(con, returning_cols, x_name)
  )
  sql_format_clauses(clauses, lvl = 0, con)
}

#' @export
#' @rdname db-sql
sql_query_upsert <- function(con, x_name, y, by, update_cols, ...,
                             returning_cols = NULL) {
  # https://wiki.postgresql.org/wiki/UPSERT#SQL_MERGE_syntax
  # https://github.com/cynkra/dm/pull/616#issuecomment-920613435
  rlang::check_dots_used()
  UseMethod("sql_query_upsert")
}

#' @export
sql_query_upsert.DBIConnection <- function(con, x_name, y, by,
                                           update_cols, ...,
                                           returning_cols = NULL) {
  parts <- rows_prep(con, x_name, y, by, lvl = 0)

  update_values <- sql_table_prefix(con, update_cols, ident("...y"))
  update_cols <- sql_escape_ident(con, update_cols)

  updated_cte <- list(
    sql_clause_update(x_name),
    sql_clause_set(update_cols, update_values),
    sql_clause_from(parts$from),
    sql_clause_where(parts$where),
    sql(paste0("RETURNING ", escape(x_name, con = con), ".*"))
  )
  updated_sql <- sql_format_clauses(updated_cte, lvl = 1, con)
  update_name <- sql(escape(ident("updated"), con = con))

  join_by <- list(x = by, y = by, x_as = ident("updated"), y_as = ident("...y"))
  where <- sql_join_tbls(con, by = join_by, na_matches = "never")

  insert_cols <- escape(ident(colnames(y)), collapse = ", ", parens = TRUE, con = con)
  clauses <- list2(
    sql(paste0("WITH ", update_name, " AS (")),
    updated_sql,
    sql(")"),
    sql_clause_insert(con, insert_cols, x_name),
    sql_clause_select(con, sql("*")),
    sql_clause_from(parts$from),
    !!!sql_clause_where_exists(update_name, where, not = TRUE)
  )

  sql_format_clauses(clauses, lvl = 0, con)
}

#' @export
#' @rdname db-sql
sql_query_delete <- function(con, x_name, y, by, ..., returning_cols = NULL) {
  rlang::check_dots_used()
  UseMethod("sql_query_delete")
}

#' @export
sql_query_delete.DBIConnection <- function(con, x_name, y, by, ..., returning_cols = NULL) {
  parts <- rows_prep(con, x_name, y, by, lvl = 0)

  clauses <- list2(
    sql_clause("DELETE FROM", x_name),
    !!!sql_clause_where_exists(parts$from, parts$where, not = FALSE),
    sql_returning_cols(con, returning_cols, x_name)
  )
  sql_format_clauses(clauses, lvl = 0, con)
}

#' @export
#' @rdname db-sql
sql_returning_cols <- function(con, cols, table, ...) {
  if (is_empty(cols)) {
    return(NULL)
  }

  rlang::check_dots_empty()
  UseMethod("sql_returning_cols")
}

#' @export
sql_returning_cols.DBIConnection <- function(con, cols, table, ...) {
  returning_cols <- sql_named_cols(con, cols, table = table)

  sql_clause("RETURNING", returning_cols)
}

sql_named_cols <- function(con, cols, table = NULL) {
  nms <- names2(cols)
  nms[nms == cols] <- ""

  cols <- sql_table_prefix(con, cols, table)
  cols <- set_names(ident_q(cols), nms)
  escape(cols, collapse = NULL, con = con)
}

# dplyr fallbacks ---------------------------------------------------------

dbplyr_analyze <- function(con, ...) {
  dbplyr_fallback(con, "db_analyze", ...)
}
#' @export
#' @importFrom dplyr db_analyze
db_analyze.DBIConnection <- function(con, table, ...) {
  sql <- sql_table_analyze(con, table, ...)
  if (is.null(sql)) {
    return() # nocov
  }
  dbExecute(con, sql)
}

dbplyr_create_index <- function(con, ...) {
  dbplyr_fallback(con, "db_create_index", ...)
}
#' @export
#' @importFrom dplyr db_create_index
db_create_index.DBIConnection <- function(con, table, columns, name = NULL,
                                          unique = FALSE, ...) {
  sql <- sql_table_index(con, table, columns, name = name, unique = unique, ...)
  dbExecute(con, sql)
}

dbplyr_explain <- function(con, ...) {
  dbplyr_fallback(con, "db_explain", ...)
}
#' @export
#' @importFrom dplyr db_explain
db_explain.DBIConnection <- function(con, sql, ...) {
  sql <- sql_query_explain(con, sql, ...)
  expl <- dbGetQuery(con, sql)
  out <- utils::capture.output(print(expl))
  paste(out, collapse = "\n")
}

dbplyr_query_fields <- function(con, ...) {
  dbplyr_fallback(con, "db_query_fields", ...)
}
#' @export
#' @importFrom dplyr db_query_fields
db_query_fields.DBIConnection <- function(con, sql, ...) {
  sql <- sql_query_fields(con, sql, ...)
  names(dbGetQuery(con, sql))
}

dbplyr_save_query <- function(con, ...) {
  dbplyr_fallback(con, "db_save_query", ...)
}
#' @export
#' @importFrom dplyr db_save_query
db_save_query.DBIConnection <- function(con, sql, name, temporary = TRUE, ...) {
  sql <- sql_query_save(con, sql, name, temporary = temporary, ...)
  dbExecute(con, sql, immediate = TRUE)
  name
}

dbplyr_sql_subquery <- function(con, ...) {
  dbplyr_fallback(con, "sql_subquery", ...)
}
#' @export
#' @importFrom dplyr sql_subquery
sql_subquery.DBIConnection <- function(con, from, name = unique_subquery_name(), ..., lvl = 0) {
  sql_query_wrap(con, from = from, name = name, ..., lvl = lvl)
}
