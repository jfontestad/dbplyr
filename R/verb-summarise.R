#' Summarise each group to one row
#'
#' This is a method for the dplyr [summarise()] generic. It generates the
#' `SELECT` clause of the SQL query, and generally needs to be combined with
#' `group_by()`.
#'
#' @inheritParams arrange.tbl_lazy
#' @inheritParams dplyr::summarise
#' @param .groups \Sexpr[results=rd]{lifecycle::badge("experimental")} Grouping structure of the result.
#'
#'   * "drop_last": dropping the last level of grouping. This was the
#'   only supported option before version 1.0.0.
#'   * "drop": All levels of grouping are dropped.
#'   * "keep": Same grouping structure as `.data`.
#'
#'   When `.groups` is not specified, it defaults to "drop_last".
#'
#'   In addition, a message informs you of that choice, unless the result is ungrouped,
#'   the option "dplyr.summarise.inform" is set to `FALSE`,
#'   or when `summarise()` is called from a function in a package.
#' @inherit arrange.tbl_lazy return
#' @importFrom dplyr summarise
#' @export
#' @examples
#' library(dplyr, warn.conflicts = FALSE)
#'
#' db <- memdb_frame(g = c(1, 1, 1, 2, 2), x = c(4, 3, 6, 9, 2))
#' db %>%
#'   summarise(n()) %>%
#'   show_query()
#'
#' db %>%
#'   group_by(g) %>%
#'   summarise(n()) %>%
#'   show_query()
summarise.tbl_lazy <- function(.data, ..., .groups = NULL) {
  dots <- partial_eval_dots(.data, ..., .named = TRUE)
  check_summarise_vars(dots)
  check_groups(.groups)

  .data$lazy_query <- add_summarise(
    .data, dots,
    .groups = .groups,
    env_caller = caller_env()
  )
  .data
}

# For each expression, check if it uses any newly created variables
check_summarise_vars <- function(dots) {
  for (i in seq_along(dots)) {
    used_vars <- all_names(get_expr(dots[[i]]))
    cur_vars <- names(dots)[seq_len(i - 1)]

    if (any(used_vars %in% cur_vars)) {
      first_used_var <- used_vars[used_vars %in% cur_vars][[1]]
      message <- c(
        "In `dbplyr` you cannot use a variable created in the same summarise.",
        `x` = paste0(
          "`", names(dots)[[i]],
          "` refers to `", first_used_var, "` which was created earlier in this summarise()."
        ),
        `i` = "You need an extra mutate() step to use it."
      )
      abort(message, call = caller_env())
    }
  }
}

check_groups <- function(.groups) {
  if (is_null(.groups)) {
    return()
  }

  if (.groups %in% c("drop_last", "drop", "keep")) {
    return()
  }

  message <- c(
    paste0(
      "`.groups` can't be ", as_label(.groups),
      if (.groups == "rowwise") " in dbplyr"
    ),
    i = 'Possible values are NULL (default), "drop_last", "drop", and "keep"'
  )
  abort(message, call = caller_env())
}

add_summarise <- function(.data, dots, .groups, env_caller) {
  lazy_query <- .data$lazy_query

  grps <- op_grps(lazy_query)
  message_summarise <- summarise_message(grps, .groups, env_caller)

  .groups <- .groups %||% "drop_last"
  groups_out <- switch(.groups,
    drop_last = grps[-length(grps)],
    keep = grps,
    drop = character()
  )

  vars <- c(grps, setdiff(names(dots), grps))
  select <- syms(set_names(vars))
  select[names(dots)] <- dots

  lazy_select_query(
    from = lazy_query,
    last_op = "summarise",
    select = select,
    group_by = syms(grps),
    group_vars = groups_out,
    select_operation = "summarise",
    message_summarise = message_summarise
  )
}

summarise_message <- function(grps, .groups, env_caller) {
  verbose <- summarise_verbose(.groups, env_caller)
  n <- length(grps)
  if (!verbose || n <= 1) {
    return(NULL)
  }

  new_groups <- glue::glue_collapse(paste0("'", grps[-n], "'"), sep = ", ")
  summarise_message <- paste0(
    "`summarise()` has grouped output by ", new_groups, '. You can override using the `.groups` argument.'
  )
}

summarise_verbose <- function(.groups, .env) {
  is.null(.groups) &&
    is_reference(topenv(.env), global_env()) &&
    !identical(getOption("dplyr.summarise.inform"), FALSE)
}
